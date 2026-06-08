#include "system_channel.h"

#include <flutter_linux/flutter_linux.h>
#include <cctype>
#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// WebKit2GTK — embedded via XReparentWindow into Flutter's X11 window
#include <webkit2/webkit2.h>
#include <gdk/gdkx.h>
#include <X11/Xlib.h>

static const char* kChannelName = "krdos/system";

// ---------------------------------------------------------------------------
// Embedded WebKit2GTK browser — XReparentWindow approach
//
// WHY NOT GtkOverlay:
//   Flutter's EGL/OpenGL draw overwrites GTK's compositor output every frame.
//
// WHY NOT separate top-level GtkWindow:
//   Z-order fights: without a WM, Flutter's top-level window can end up on
//   top of the WebKit window with no reliable way to keep WebKit above it.
//
// THIS APPROACH (XReparentWindow):
//   We realize the WebKitWebView GtkWindow WITHOUT showing it (so GTK never
//   maps it as a top-level window), then use raw Xlib to:
//     1. Reparent WebKit's X11 window into Flutter's X11 window.
//     2. Position it at the content-area coordinates (Flutter-window-local).
//     3. Map it via XMapWindow.
//   Because it is an X11 CHILD of Flutter's window, it is always composited
//   on top of the parent's pixel content — no Z-order fight, no timer needed.
//   Flutter's tab strip / URL bar live above y=content_y so they are never
//   obscured.
// ---------------------------------------------------------------------------

static FlPluginRegistrar* g_reg     = nullptr;
static GtkWidget*         g_webwin  = nullptr;  // Unrealized-until-first-use GtkWindow
static WebKitWebView*     g_webview = nullptr;
static bool               g_reparented = false; // Did we already XReparentWindow?
static int g_web_x = 0, g_web_y = 0, g_web_w = 800, g_web_h = 600;

static GtkWindow* main_gtk_window() {
  if (!g_reg) return nullptr;
  GtkWidget* view = GTK_WIDGET(fl_plugin_registrar_get_view(g_reg));
  if (!view) return nullptr;
  GtkWidget* top = gtk_widget_get_toplevel(view);
  return GTK_IS_WINDOW(top) ? GTK_WINDOW(top) : nullptr;
}

// Return the raw Xlib Display* from the default GDK display.
static Display* x_display() {
  return gdk_x11_display_get_xdisplay(gdk_display_get_default());
}

// Return the X11 window ID of the Flutter GtkWindow.
static Window flutter_xwindow() {
  GtkWindow* w = main_gtk_window();
  if (!w) return None;
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(w));
  if (!gdk_win) return None;
  return gdk_x11_window_get_xid(gdk_win);
}

// Return the X11 window ID of our WebKit GtkWindow (after realization).
static Window webkit_xwindow() {
  if (!g_webwin) return None;
  GdkWindow* gdk_win = gtk_widget_get_window(g_webwin);
  if (!gdk_win) return None;
  return gdk_x11_window_get_xid(gdk_win);
}

// Signal handler: return TRUE to suppress WebKit's own fullscreen attempts.
static gboolean webview_block_fullscreen(WebKitWebView* /*wv*/, gpointer /*ud*/) {
  return TRUE;
}

// Create the WebKitWebView inside a GtkWindow (lazy, once).
// We realize but do NOT map the window — XMapWindow handles that.
static void webwin_ensure_created() {
  if (g_webwin) return;

  fprintf(stderr, "[browser] webwin_ensure_created: start\n");

  // Undecorated, borderless container for WebKit.
  g_webwin = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_decorated(GTK_WINDOW(g_webwin), FALSE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(g_webwin), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(g_webwin), TRUE);
  gtk_window_set_default_size(GTK_WINDOW(g_webwin), 800, 600);

  // Build WebKit settings — software rendering, JS enabled.
  WebKitSettings* ws = webkit_settings_new();
  webkit_settings_set_enable_javascript(ws, TRUE);
  webkit_settings_set_enable_webgl(ws, FALSE);
  webkit_settings_set_enable_media(ws, TRUE);
  webkit_settings_set_allow_file_access_from_file_urls(ws, FALSE);
  webkit_settings_set_user_agent(ws,
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 KrdOS/1.0");
  webkit_settings_set_hardware_acceleration_policy(
    ws, WEBKIT_HARDWARE_ACCELERATION_POLICY_NEVER);

  // Disable WebKit's process sandbox — Kali Linux's hardened kernel blocks
  // the seccomp/setuid-sandbox that WebKit's web process requires by default.
  // Must be called before any web process is spawned (i.e. before first load).
  WebKitWebContext* ctx = webkit_web_context_get_default();
  webkit_web_context_set_sandbox_enabled(ctx, FALSE);
  fprintf(stderr, "[browser] sandbox disabled on default context\n");

  g_webview = WEBKIT_WEB_VIEW(webkit_web_view_new_with_settings(ws));
  g_object_unref(ws);

  // Opaque white background so the view is always visible even before load.
  GdkRGBA white = {1.0, 1.0, 1.0, 1.0};
  webkit_web_view_set_background_color(g_webview, &white);

  // Block WebKit's own fullscreen requests — we manage geometry ourselves.
  g_signal_connect(g_webview, "enter-fullscreen",
    G_CALLBACK(webview_block_fullscreen), nullptr);

  gtk_container_add(GTK_CONTAINER(g_webwin), GTK_WIDGET(g_webview));
  gtk_widget_show(GTK_WIDGET(g_webview));

  // Realize (creates the X11 window hierarchy) but do NOT map (do NOT call
  // gtk_widget_show on g_webwin — we use XMapWindow so it maps as a child of
  // Flutter's X11 window). NOTE: realize does NOT map child widgets; we must
  // call XMapSubwindows separately after XMapWindow to map WebKit's drawing
  // area windows, which are created but left unmapped during realize-only.
  gtk_widget_realize(g_webwin);

  Window wk_xw = webkit_xwindow();
  fprintf(stderr, "[browser] realized: g_webwin xid=0x%lx g_webview=%p\n",
          (unsigned long)wk_xw, (void*)g_webview);
}

// Show/navigate: embed WebKit into Flutter's X11 window and map it.
static void webwin_show(int x, int y, int w, int h) {
  if (w < 10) w = 800;
  if (h < 10) h = 600;
  fprintf(stderr, "[browser] webwin_show x=%d y=%d w=%d h=%d\n", x, y, w, h);
  webwin_ensure_created();
  if (!g_webwin) {
    fprintf(stderr, "[browser] webwin_show: g_webwin is null, aborting\n");
    return;
  }

  g_web_x = x; g_web_y = y; g_web_w = w; g_web_h = h;

  Display* dpy   = x_display();
  Window   fl_xw = flutter_xwindow();
  Window   wk_xw = webkit_xwindow();
  fprintf(stderr, "[browser] xids: dpy=%p fl_xw=0x%lx wk_xw=0x%lx\n",
          (void*)dpy, (unsigned long)fl_xw, (unsigned long)wk_xw);

  if (!dpy || !fl_xw || !wk_xw) {
    fprintf(stderr, "[browser] webwin_show: null xid(s), aborting\n");
    return;
  }

  if (!g_reparented) {
    // First show: reparent into Flutter's window at content-area position.
    // Coordinates are Flutter-window-local (same as localToGlobal in Dart).
    fprintf(stderr, "[browser] XReparentWindow: 0x%lx -> 0x%lx at (%d,%d)\n",
            (unsigned long)wk_xw, (unsigned long)fl_xw, x, y);
    XReparentWindow(dpy, wk_xw, fl_xw, x, y);
    g_reparented = true;
  } else {
    // Subsequent shows: just move back to the correct position.
    XMoveWindow(dpy, wk_xw, x, y);
  }

  XResizeWindow(dpy, wk_xw, (unsigned)w, (unsigned)h);
  XMapWindow(dpy, wk_xw);         // Map the container window
  // CRITICAL: gtk_widget_realize only creates X11 windows, it does NOT map
  // them. WebKit's internal GdkWindow (drawing area) is created but unmapped.
  // XMapSubwindows recursively maps every child X11 window of wk_xw so the
  // WebKit drawing surface becomes visible.
  XMapSubwindows(dpy, wk_xw);
  XRaiseWindow(dpy, wk_xw);
  XFlush(dpy);
  fprintf(stderr, "[browser] webwin_show: mapped+raised OK\n");

  gtk_widget_grab_focus(GTK_WIDGET(g_webview));
}

// Reposition/resize the already-visible embedded WebKit child window.
static void webwin_reposition(int x, int y, int w, int h) {
  fprintf(stderr, "[browser] webwin_reposition x=%d y=%d w=%d h=%d\n", x, y, w, h);
  if (!g_webwin || !g_reparented) return;
  if (w < 10) w = 800;
  if (h < 10) h = 600;
  g_web_x = x; g_web_y = y; g_web_w = w; g_web_h = h;

  Display* dpy   = x_display();
  Window   wk_xw = webkit_xwindow();
  if (!dpy || !wk_xw) return;

  XMoveResizeWindow(dpy, wk_xw, x, y, (unsigned)w, (unsigned)h);
  XFlush(dpy);
}

// Unmap (hide) the embedded WebKit child window.
static void webwin_hide() {
  fprintf(stderr, "[browser] webwin_hide\n");
  if (!g_webwin || !g_reparented) return;

  Display* dpy   = x_display();
  Window   wk_xw = webkit_xwindow();
  if (dpy && wk_xw) {
    XUnmapWindow(dpy, wk_xw);
    XFlush(dpy);
  }
}

// Navigate — apply https:// prefix or Google search as needed.
static void webwin_navigate(const char* raw) {
  fprintf(stderr, "[browser] webwin_navigate: raw='%s' g_webview=%p\n",
          raw ? raw : "(null)", (void*)g_webview);
  if (!g_webview || !raw || raw[0] == '\0') return;

  if (strncmp(raw, "http://",  7) == 0 ||
      strncmp(raw, "https://", 8) == 0 ||
      strncmp(raw, "about:",   6) == 0) {
    webkit_web_view_load_uri(g_webview, raw);
    return;
  }
  // Bare domain? (has a dot, no spaces)
  if (strchr(raw, '.') && !strchr(raw, ' ')) {
    char buf[2048];
    snprintf(buf, sizeof(buf), "https://%s", raw);
    webkit_web_view_load_uri(g_webview, buf);
    return;
  }
  // Everything else → Google search
  char encoded[2048] = {};
  size_t si = 0, di = 0;
  while (raw[si] && di < sizeof(encoded) - 4) {
    unsigned char c = (unsigned char)raw[si++];
    if (c == ' ')                      { encoded[di++] = '+'; }
    else if ((c >= 'A' && c <= 'Z') ||
             (c >= 'a' && c <= 'z') ||
             (c >= '0' && c <= '9') ||
             c == '-' || c == '_' || c == '.' || c == '~') {
      encoded[di++] = (char)c;
    } else {
      snprintf(encoded + di, 4, "%%%02X", c);
      di += 3;
    }
  }
  char url[2200];
  snprintf(url, sizeof(url), "https://www.google.com/search?q=%s", encoded);
  webkit_web_view_load_uri(g_webview, url);
}

// ---------------------------------------------------------------------------
// Shell helpers
// ---------------------------------------------------------------------------

// Run cmd (appending 2>&1) and return heap-allocated stdout+stderr string.
// Caller must free().
static char* shell_capture(const char* cmd) {
  char full[8192];
  snprintf(full, sizeof(full), "%s 2>&1", cmd);

  FILE* fp = popen(full, "r");
  if (!fp) return strdup("[error: popen failed]");

  char* out = nullptr;
  size_t total = 0;
  char buf[512];
  while (fgets(buf, sizeof(buf), fp)) {
    size_t n = strlen(buf);
    out = (char*)realloc(out, total + n + 1);
    memcpy(out + total, buf, n);
    total += n;
    out[total] = '\0';
  }
  pclose(fp);
  return out ? out : strdup("");
}

// Run cmd silently; return true if exit code == 0.
static bool shell_ok(const char* cmd) {
  char full[8192];
  snprintf(full, sizeof(full), "%s >/dev/null 2>&1", cmd);
  return system(full) == 0;
}

// Read entire file into heap string.  Caller must free().
static char* file_slurp(const char* path) {
  FILE* fp = fopen(path, "r");
  if (!fp) return strdup("");
  char* out = nullptr;
  size_t total = 0;
  char buf[512];
  while (fgets(buf, sizeof(buf), fp)) {
    size_t n = strlen(buf);
    out = (char*)realloc(out, total + n + 1);
    memcpy(out + total, buf, n);
    total += n;
    out[total] = '\0';
  }
  fclose(fp);
  return out ? out : strdup("");
}

// Strip trailing newline in-place.
static void rstrip(char* s) {
  size_t n = strlen(s);
  while (n > 0 && (s[n-1] == '\n' || s[n-1] == '\r')) s[--n] = '\0';
}

// ---------------------------------------------------------------------------
// Method call handler
// ---------------------------------------------------------------------------
// Helper: extract value from lsblk --pairs key="value" output.
// Returns heap-allocated string (caller must free).
static char* lsblk_kv(const char* line, const char* key) {
  char search[64];
  snprintf(search, sizeof(search), "%s=\"", key);
  const char* s = strstr(line, search);
  if (!s) return strdup("");
  s += strlen(search);
  const char* e = strchr(s, '"');
  if (!e) return strdup("");
  int len = (int)(e - s);
  char* r = (char*)malloc(len + 1);
  strncpy(r, s, len);
  r[len] = '\0';
  return r;
}

// ---------------------------------------------------------------------------

static void on_method_call(FlMethodChannel* /*channel*/,
                            FlMethodCall*   call,
                            gpointer        /*user_data*/) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue*     args   = fl_method_call_get_args(call);

  g_autoptr(FlMethodResponse) resp = nullptr;

  // ── WiFi ──────────────────────────────────────────────────────────────────
  if (strcmp(method, "wifi.enable") == 0) {
    bool ok = shell_ok("sudo nmcli radio wifi on");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "wifi.disable") == 0) {
    bool ok = shell_ok("sudo nmcli radio wifi off");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "wifi.status") == 0) {
    char* out = shell_capture("nmcli radio wifi");
    rstrip(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(out)));
    free(out);

  // ── Bluetooth ─────────────────────────────────────────────────────────────
  } else if (strcmp(method, "bluetooth.enable") == 0) {
    // Ensure the bluetooth service is running (needed if it wasn't started at boot)
    shell_ok("systemctl start bluetooth 2>/dev/null");
    // rfkill unblock — running as root so no sudo needed
    shell_ok("rfkill unblock bluetooth 2>/dev/null");
    shell_ok("rfkill unblock all 2>/dev/null");
    bool ok = shell_ok("bluetoothctl power on 2>/dev/null");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "bluetooth.disable") == 0) {
    shell_ok("bluetoothctl power off 2>/dev/null");
    bool ok = shell_ok("rfkill block bluetooth 2>/dev/null");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Microphone ────────────────────────────────────────────────────────────
  } else if (strcmp(method, "mic.mute") == 0) {
    bool ok = shell_ok("sudo amixer set Capture nocap") ||
              shell_ok("pactl set-source-mute @DEFAULT_SOURCE@ 1");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "mic.unmute") == 0) {
    bool ok = shell_ok("sudo amixer set Capture cap") ||
              shell_ok("pactl set-source-mute @DEFAULT_SOURCE@ 0");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Camera ────────────────────────────────────────────────────────────────
  } else if (strcmp(method, "camera.disable") == 0) {
    // Unload the USB video class driver to kill all camera access
    bool ok = shell_ok("sudo modprobe -r uvcvideo");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "camera.enable") == 0) {
    bool ok = shell_ok("sudo modprobe uvcvideo");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Network stats (/proc/net/dev) ─────────────────────────────────────────
  } else if (strcmp(method, "network.stats") == 0) {
    char* raw = file_slurp("/proc/net/dev");
    long rx_b=0, rx_p=0, tx_b=0, tx_p=0;
    char iface[32] = "eth0";
    char* line = strtok(raw, "\n");
    while (line) {
      char tmp_iface[32];
      long rb, rp, tb, tp;
      if (sscanf(line, " %31[^:]: %ld %ld %*d %*d %*d %*d %*d %*d %ld %ld",
                 tmp_iface, &rb, &rp, &tb, &tp) == 5) {
        if (strcmp(tmp_iface, "lo") != 0) {
          strncpy(iface, tmp_iface, sizeof(iface) - 1);
          rx_b = rb; rx_p = rp; tx_b = tb; tx_p = tp;
          break;
        }
      }
      line = strtok(nullptr, "\n");
    }
    free(raw);
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "rx_bytes",   fl_value_new_int(rx_b));
    fl_value_set_string_take(map, "tx_bytes",   fl_value_new_int(tx_b));
    fl_value_set_string_take(map, "rx_packets", fl_value_new_int(rx_p));
    fl_value_set_string_take(map, "tx_packets", fl_value_new_int(tx_p));
    fl_value_set_string_take(map, "interface",  fl_value_new_string(iface));
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Public IP ─────────────────────────────────────────────────────────────
  } else if (strcmp(method, "network.publicip") == 0) {
    char* ip = shell_capture("curl -s --max-time 5 ifconfig.me");
    rstrip(ip);
    if (strlen(ip) == 0) { free(ip); ip = strdup("unavailable"); }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(ip)));
    free(ip);

  // ── IP rotation (MAC spoof + reconnect) ───────────────────────────────────
  } else if (strcmp(method, "ip.rotate") == 0) {
    const char* iface = "wlan0";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "interface");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING)
        iface = fl_value_get_string(v);
    }
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
      "sudo ip link set %s down && "
      "sudo macchanger -r %s && "
      "sudo ip link set %s up",
      iface, iface, iface);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── VPN connect ───────────────────────────────────────────────────────────
  } else if (strcmp(method, "vpn.connect") == 0) {
    const char* config   = "";
    const char* protocol = "wireguard";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* c = fl_value_lookup_string(args, "config");
      FlValue* p = fl_value_lookup_string(args, "protocol");
      if (c && fl_value_get_type(c) == FL_VALUE_TYPE_STRING) config   = fl_value_get_string(c);
      if (p && fl_value_get_type(p) == FL_VALUE_TYPE_STRING) protocol = fl_value_get_string(p);
    }
    bool ok = false;
    char cmd[2048];
    if (strcmp(protocol, "wireguard") == 0) {
      snprintf(cmd, sizeof(cmd), "sudo wg-quick up %s", config);
      ok = shell_ok(cmd);
    } else if (strcmp(protocol, "openvpn") == 0) {
      snprintf(cmd, sizeof(cmd), "sudo openvpn --config %s --daemon", config);
      ok = shell_ok(cmd);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "vpn.disconnect") == 0) {
    bool ok = shell_ok("sudo wg-quick down wg0") || shell_ok("sudo pkill openvpn");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "vpn.status") == 0) {
    char* out = shell_capture("wg show 2>/dev/null");
    if (strlen(out) == 0) { free(out); out = strdup("disconnected"); }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(out)));
    free(out);

  // ── System stats ──────────────────────────────────────────────────────────
  } else if (strcmp(method, "system.stats") == 0) {
    // CPU: sample /proc/stat twice, 100 ms apart
    char* s1 = file_slurp("/proc/stat");
    g_usleep(100000);
    char* s2 = file_slurp("/proc/stat");
    long u1=0,n1=0,sy1=0,id1=0, u2=0,n2=0,sy2=0,id2=0;
    sscanf(s1, "cpu %ld %ld %ld %ld", &u1, &n1, &sy1, &id1);
    sscanf(s2, "cpu %ld %ld %ld %ld", &u2, &n2, &sy2, &id2);
    free(s1); free(s2);
    long tot1 = u1+n1+sy1+id1, tot2 = u2+n2+sy2+id2;
    double cpu_pct = 0.0;
    if (tot2 != tot1)
      cpu_pct = 100.0 * (1.0 - (double)(id2-id1) / (double)(tot2-tot1));

    // Memory
    char* mi = file_slurp("/proc/meminfo");
    long mt=0, mf=0, mb=0, mc=0;
    char* p;
    if ((p = strstr(mi, "MemTotal:")))  sscanf(p, "MemTotal: %ld",  &mt);
    if ((p = strstr(mi, "MemFree:")))   sscanf(p, "MemFree: %ld",   &mf);
    if ((p = strstr(mi, "Buffers:")))   sscanf(p, "Buffers: %ld",   &mb);
    if ((p = strstr(mi, "Cached:")))    sscanf(p, "Cached: %ld",    &mc);
    free(mi);
    long mu = mt - mf - mb - mc;

    // Uptime
    char* up = file_slurp("/proc/uptime");
    double uptime_s = 0.0;
    sscanf(up, "%lf", &uptime_s);
    free(up);

    // Load average
    char* la = file_slurp("/proc/loadavg");
    double l1=0, l5=0, l15=0;
    sscanf(la, "%lf %lf %lf", &l1, &l5, &l15);
    free(la);

    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "cpu_percent",    fl_value_new_float(cpu_pct));
    fl_value_set_string_take(map, "mem_total_kb",   fl_value_new_int(mt));
    fl_value_set_string_take(map, "mem_used_kb",    fl_value_new_int(mu));
    fl_value_set_string_take(map, "uptime_seconds", fl_value_new_float(uptime_s));
    fl_value_set_string_take(map, "load_avg_1",     fl_value_new_float(l1));
    fl_value_set_string_take(map, "load_avg_5",     fl_value_new_float(l5));
    fl_value_set_string_take(map, "load_avg_15",    fl_value_new_float(l15));
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Process list ──────────────────────────────────────────────────────────
  } else if (strcmp(method, "process.list") == 0) {
    char* out = shell_capture(
      "ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu --no-headers | head -30");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      int pid=0, ppid=0;
      char user[32]="", comm[256]="";
      float cpu=0, mem=0;
      if (sscanf(line, "%d %d %31s %f %f %255s",
                 &pid, &ppid, user, &cpu, &mem, comm) == 6) {
        g_autoptr(FlValue) ent = fl_value_new_map();
        fl_value_set_string_take(ent, "pid",  fl_value_new_int(pid));
        fl_value_set_string_take(ent, "ppid", fl_value_new_int(ppid));
        fl_value_set_string_take(ent, "user", fl_value_new_string(user));
        fl_value_set_string_take(ent, "cpu",  fl_value_new_float(cpu));
        fl_value_set_string_take(ent, "mem",  fl_value_new_float(mem));
        fl_value_set_string_take(ent, "name", fl_value_new_string(comm));
        fl_value_append_take(list, g_steal_pointer(&ent));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Terminal passthrough ──────────────────────────────────────────────────
  } else if (strcmp(method, "terminal.execute") == 0) {
    const char* command = "";
    const char* cwd     = "/home/admin";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* c = fl_value_lookup_string(args, "command");
      FlValue* d = fl_value_lookup_string(args, "cwd");
      if (c && fl_value_get_type(c) == FL_VALUE_TYPE_STRING) command = fl_value_get_string(c);
      if (d && fl_value_get_type(d) == FL_VALUE_TYPE_STRING) cwd     = fl_value_get_string(d);
    }
    // Wrap command with a 300-second hard timeout (-k 5 sends SIGKILL 5s after SIGTERM)
    // to prevent long-running processes (apt-get, pip, etc.) from freezing the UI thread.
    char full[16384 + 64];
    snprintf(full, sizeof(full),
      "cd %s 2>/dev/null || cd /home/admin; timeout -k 5 300 %s", cwd, command);
    char* out = shell_capture(full);
    // Cap output at 512 KB to prevent OOM from verbose commands (e.g. make, pip install)
    const size_t MAX_TERM_OUTPUT = 512UL * 1024UL;
    size_t out_len = out ? strlen(out) : 0;
    if (out && out_len > MAX_TERM_OUTPUT) {
      const char* trunc_msg = "\n\n... [output truncated — exceeded 512 KB] ...\n";
      size_t msg_len = strlen(trunc_msg);
      char* newbuf = (char*)realloc(out, MAX_TERM_OUTPUT + msg_len + 1);
      if (newbuf) {
        out = newbuf;
        memcpy(out + MAX_TERM_OUTPUT, trunc_msg, msg_len + 1);
      } else {
        out[MAX_TERM_OUTPUT] = '\0';
      }
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(out ? out : "")));
    free(out);

  // ── Power management ──────────────────────────────────────────────────────
  } else if (strcmp(method, "power.shutdown") == 0) {
    shell_ok("sudo systemctl poweroff");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));

  } else if (strcmp(method, "power.reboot") == 0) {
    shell_ok("sudo systemctl reboot");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));

  } else if (strcmp(method, "power.sleep") == 0) {
    shell_ok("sudo systemctl suspend");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));

  // ── Audio — pactl primary, amixer fallback (handles PulseAudio + PipeWire) ──
  } else if (strcmp(method, "audio.get_volume") == 0) {
    // Try pactl first (PulseAudio / PipeWire)
    char* out = shell_capture(
      "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | "
      "grep -oP '[0-9]+(?=%)' | head -1");
    rstrip(out);
    int vol = -1;
    if (strlen(out) > 0) vol = atoi(out);
    free(out);
    if (vol < 0) {
      // Fallback: amixer Master (ALSA)
      char* a = shell_capture(
        "amixer get Master 2>/dev/null | grep -oP '[0-9]+(?=%)' | head -1");
      rstrip(a);
      vol = strlen(a) > 0 ? atoi(a) : 70;
      free(a);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(vol)));

  } else if (strcmp(method, "audio.set_volume") == 0) {
    int pct = 70;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "percent");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) pct = (int)fl_value_get_int(v);
    }
    if (pct < 0) pct = 0;
    if (pct > 150) pct = 150;
    char cmd[256];
    // Try pactl; if it fails, fall back to amixer
    snprintf(cmd, sizeof(cmd), "pactl set-sink-volume @DEFAULT_SINK@ %d%%", pct);
    bool ok = shell_ok(cmd);
    if (!ok) {
      snprintf(cmd, sizeof(cmd), "amixer set Master %d%% 2>/dev/null", pct);
      ok = shell_ok(cmd);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "audio.get_mic_volume") == 0) {
    char* out = shell_capture(
      "pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | "
      "grep -oP '[0-9]+(?=%)' | head -1");
    rstrip(out);
    int vol = -1;
    if (strlen(out) > 0) vol = atoi(out);
    free(out);
    if (vol < 0) {
      char* a = shell_capture(
        "amixer get Capture 2>/dev/null | grep -oP '[0-9]+(?=%)' | head -1");
      rstrip(a);
      vol = strlen(a) > 0 ? atoi(a) : 80;
      free(a);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(vol)));

  } else if (strcmp(method, "audio.set_mic_volume") == 0) {
    int pct = 80;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "percent");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) pct = (int)fl_value_get_int(v);
    }
    if (pct < 0) pct = 0;
    if (pct > 150) pct = 150;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "pactl set-source-volume @DEFAULT_SOURCE@ %d%%", pct);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Screenshot ────────────────────────────────────────────────────────────
  } else if (strcmp(method, "screenshot.take") == 0) {
    const char* path = "/home/admin/Pictures/screenshot.png";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) path = fl_value_get_string(v);
    }
    // Create parent directory
    char mkdirCmd[1024];
    snprintf(mkdirCmd, sizeof(mkdirCmd), "mkdir -p '%s'",
             g_path_get_dirname(path));
    shell_ok(mkdirCmd);
    // Try scrot first, fall back to import (ImageMagick)
    char cmd[2048];
    snprintf(cmd, sizeof(cmd),
      "scrot '%s' 2>/dev/null || import -window root '%s' 2>/dev/null", path, path);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_string(ok ? path : "")));

  // ── Display / multi-monitor ───────────────────────────────────────────────
  } else if (strcmp(method, "display.detect_monitors") == 0) {
    // xrandr may not exist on Wayland-only setups; handle gracefully.
    char* xrandr = shell_capture("xrandr --query 2>/dev/null || echo '__xrandr_unavailable__'");
    g_autoptr(FlValue) list = fl_value_new_list();
    if (strstr(xrandr, "__xrandr_unavailable__") == nullptr && strlen(xrandr) > 10) {
      bool first_connected = true;
      char* saveptr = nullptr;
      char* line = strtok_r(xrandr, "\n", &saveptr);
      while (line) {
        char name[64]="";
        char conn[16]="";
        if (sscanf(line, "%63s %15s", name, conn) >= 2) {
          bool connected = (strcmp(conn, "connected") == 0);
          if (connected) {
            bool primary = (strstr(line, "primary") != nullptr);
            // Parse resolution and position from e.g. "1920x1080+0+0"
            char res[32]=""; int x=0, y=0; int rr=60;
            char* plus1 = strchr(line, '+');
            if (plus1) {
              char* resstart = plus1 - 1;
              // Walk back to find the start of WxH
              while (resstart > line && (isdigit(*resstart) || *resstart == 'x')) resstart--;
              resstart++;
              sscanf(resstart, "%31[0-9x]+%d+%d", res, &x, &y);
            }
            // Grab available resolutions from subsequent lines (indented)
            g_autoptr(FlValue) avail = fl_value_new_list();
            char* sub = strtok_r(nullptr, "\n", &saveptr);
            while (sub && (sub[0] == ' ' || sub[0] == '\t')) {
              char subres[32]="";
              if (sscanf(sub, " %31s", subres) == 1 && strchr(subres, 'x')) {
                // Check for current/preferred refresh rate marker
                if (strstr(sub, "*")) {
                  char* star_pos = strstr(sub, "*");
                  // Walk backwards from '*' to find the number
                  char* p = star_pos - 1;
                  while (p > sub && (*p == '.' || isdigit(*p))) p--;
                  float rf = 0;
                  if (sscanf(p+1, "%f", &rf) == 1) rr = (int)rf;
                }
                fl_value_append_take(avail, fl_value_new_string(subres));
              }
              sub = strtok_r(nullptr, "\n", &saveptr);
            }
            // sub now points to the next non-indented line; reprocess it
            line = sub;
            // Build monitor entry
            g_autoptr(FlValue) ent = fl_value_new_map();
            fl_value_set_string_take(ent, "output",      fl_value_new_string(name));
            fl_value_set_string_take(ent, "connected",   fl_value_new_bool(true));
            fl_value_set_string_take(ent, "enabled",     fl_value_new_bool(strlen(res) > 0));
            fl_value_set_string_take(ent, "primary",     fl_value_new_bool(primary || first_connected));
            fl_value_set_string_take(ent, "resolution",  fl_value_new_string(strlen(res) > 0 ? res : "1920x1080"));
            fl_value_set_string_take(ent, "x",           fl_value_new_int(x));
            fl_value_set_string_take(ent, "y",           fl_value_new_int(y));
            fl_value_set_string_take(ent, "refresh_rate",fl_value_new_int(rr));
            fl_value_set_string_take(ent, "available_resolutions", g_steal_pointer(&avail));
            fl_value_append_take(list, g_steal_pointer(&ent));
            first_connected = false;
            continue; // line already advanced inside loop
          }
        }
        line = strtok_r(nullptr, "\n", &saveptr);
      }
    }
    // If list is still empty (no xrandr or no connected monitors), add a
    // synthetic entry describing the current display so the UI isn't blank.
    if (fl_value_get_length(list) == 0) {
      g_autoptr(FlValue) ent = fl_value_new_map();
      fl_value_set_string_take(ent, "output",      fl_value_new_string("Primary"));
      fl_value_set_string_take(ent, "connected",   fl_value_new_bool(true));
      fl_value_set_string_take(ent, "enabled",     fl_value_new_bool(true));
      fl_value_set_string_take(ent, "primary",     fl_value_new_bool(true));
      fl_value_set_string_take(ent, "resolution",  fl_value_new_string("1920x1080"));
      fl_value_set_string_take(ent, "x",           fl_value_new_int(0));
      fl_value_set_string_take(ent, "y",           fl_value_new_int(0));
      fl_value_set_string_take(ent, "refresh_rate",fl_value_new_int(60));
      g_autoptr(FlValue) avail = fl_value_new_list();
      fl_value_append_take(avail, fl_value_new_string("1920x1080"));
      fl_value_append_take(avail, fl_value_new_string("1280x720"));
      fl_value_set_string_take(ent, "available_resolutions", g_steal_pointer(&avail));
      fl_value_append_take(list, g_steal_pointer(&ent));
    }
    free(xrandr);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  } else if (strcmp(method, "display.set_resolution") == 0) {
    const char* output = "HDMI-1";
    const char* resolution = "1920x1080";
    int refresh = 60;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v;
      v = fl_value_lookup_string(args, "output");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) output = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "resolution");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) resolution = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "refresh");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) refresh = (int)fl_value_get_int(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xrandr --output %s --mode %s --rate %d", output, resolution, refresh);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "display.set_enabled") == 0) {
    const char* output = "HDMI-1";
    bool enabled = true;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v;
      v = fl_value_lookup_string(args, "output");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) output = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "enabled");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) enabled = fl_value_get_bool(v);
    }
    char cmd[256];
    if (enabled) {
      snprintf(cmd, sizeof(cmd), "xrandr --output %s --auto", output);
    } else {
      snprintf(cmd, sizeof(cmd), "xrandr --output %s --off", output);
    }
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "display.set_brightness") == 0) {
    int pct = 100;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "percent");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) pct = (int)fl_value_get_int(v);
    }
    double f = pct / 100.0;
    if (f < 0.1) f = 0.1;
    if (f > 1.0) f = 1.0;
    char cmd[512];
    // Try xrandr gamma method
    snprintf(cmd, sizeof(cmd),
      "xrandr --listactivemonitors 2>/dev/null | grep -oP '(?<=  )\\S+' | head -1 | xargs -I{} xrandr --output {} --brightness %.2f",
      f);
    bool ok = shell_ok(cmd);
    // Also try brightnessctl
    if (!ok) {
      snprintf(cmd, sizeof(cmd), "brightnessctl set %d%% 2>/dev/null", pct);
      ok = shell_ok(cmd);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── CPU per-core + temperature ────────────────────────────────────────────
  } else if (strcmp(method, "cpu.detail") == 0) {
    // Read per-core stats from /proc/stat
    char* stat1 = file_slurp("/proc/stat");
    g_usleep(200000); // 200ms sample window for accurate per-core %
    char* stat2 = file_slurp("/proc/stat");

    g_autoptr(FlValue) cores = fl_value_new_list();
    char* s1p = stat1, *s2p = stat2;
    char* l1 = strtok(s1p, "\n");
    char* l2 = strtok(s2p, "\n");
    while (l1 && l2) {
      if (strncmp(l1, "cpu", 3) == 0 && (l1[3] >= '0' && l1[3] <= '9')) {
        long u1=0,n1=0,sy1=0,id1=0, u2=0,n2=0,sy2=0,id2=0;
        sscanf(l1, "%*s %ld %ld %ld %ld", &u1, &n1, &sy1, &id1);
        sscanf(l2, "%*s %ld %ld %ld %ld", &u2, &n2, &sy2, &id2);
        long t1=u1+n1+sy1+id1, t2=u2+n2+sy2+id2;
        double pct = (t2>t1) ? 100.0*(1.0-(double)(id2-id1)/(double)(t2-t1)) : 0.0;
        fl_value_append_take(cores, fl_value_new_float(pct < 0 ? 0 : pct));
      }
      l1 = strtok(nullptr, "\n");
      l2 = strtok(nullptr, "\n");
    }
    free(stat1); free(stat2);

    // CPU temperature: try hwmon/thermal zones
    char* temp_str = shell_capture(
      "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || "
      "sensors -u 2>/dev/null | grep -oP 'temp1_input: \\K[0-9.]+' | head -1");
    rstrip(temp_str);
    double temp_c = 0.0;
    if (strlen(temp_str) > 0) {
      double raw = atof(temp_str);
      temp_c = raw > 1000 ? raw / 1000.0 : raw;
    }
    free(temp_str);

    // CPU model
    char* model = shell_capture(
      "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs");
    rstrip(model);

    // CPU frequency (MHz)
    char* freq_str = shell_capture(
      "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null");
    rstrip(freq_str);
    long freq_mhz = strlen(freq_str) > 0 ? atol(freq_str) / 1000 : 0;
    free(freq_str);

    // Current governor
    char* gov = shell_capture(
      "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null");
    rstrip(gov);

    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "cores",        g_steal_pointer(&cores));
    fl_value_set_string_take(map, "temperature_c",fl_value_new_float(temp_c));
    fl_value_set_string_take(map, "model",        fl_value_new_string(model));
    fl_value_set_string_take(map, "freq_mhz",     fl_value_new_int(freq_mhz));
    fl_value_set_string_take(map, "governor",     fl_value_new_string(gov));
    free(model); free(gov);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── CPU governor ──────────────────────────────────────────────────────────
  } else if (strcmp(method, "cpu.set_governor") == 0) {
    const char* gov = "performance";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "governor");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) gov = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
      "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do "
      "echo %s | sudo tee $cpu >/dev/null 2>&1; done", gov);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Disk I/O stats (/proc/diskstats) ─────────────────────────────────────
  } else if (strcmp(method, "disk.io_stats") == 0) {
    char* d1 = file_slurp("/proc/diskstats");
    g_usleep(500000);
    char* d2 = file_slurp("/proc/diskstats");
    long rb1=0,wb1=0, rb2=0,wb2=0;
    char* line = strtok(d1, "\n");
    while (line) {
      char dev[32]="";
      long r=0,w=0;
      if (sscanf(line, "%*d %*d %31s %*d %*d %ld %*d %*d %*d %ld", dev, &r, &w) == 3) {
        if (strncmp(dev,"sd",2)==0||strncmp(dev,"nvme",4)==0||strncmp(dev,"vd",2)==0) {
          rb1+=r; wb1+=w;
        }
      }
      line = strtok(nullptr, "\n");
    }
    line = strtok(d2, "\n");
    while (line) {
      char dev[32]="";
      long r=0,w=0;
      if (sscanf(line, "%*d %*d %31s %*d %*d %ld %*d %*d %*d %ld", dev, &r, &w) == 3) {
        if (strncmp(dev,"sd",2)==0||strncmp(dev,"nvme",4)==0||strncmp(dev,"vd",2)==0) {
          rb2+=r; wb2+=w;
        }
      }
      line = strtok(nullptr, "\n");
    }
    free(d1); free(d2);
    // sectors are 512 bytes; 0.5s sample window → multiply by 2 for per-second rate
    long read_bytes_s  = (rb2-rb1) * 512 * 2;
    long write_bytes_s = (wb2-wb1) * 512 * 2;
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "read_bytes_s",  fl_value_new_int(read_bytes_s  < 0 ? 0 : read_bytes_s));
    fl_value_set_string_take(map, "write_bytes_s", fl_value_new_int(write_bytes_s < 0 ? 0 : write_bytes_s));
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── GPU stats ─────────────────────────────────────────────────────────────
  } else if (strcmp(method, "gpu.stats") == 0) {
    double gpu_pct = 0, gpu_temp = 0;
    long vram_used = 0, vram_total = 0;
    char gpu_name[256] = "Unknown GPU";
    // Try NVIDIA first
    char* nv = shell_capture(
      "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name "
      "--format=csv,noheader,nounits 2>/dev/null | head -1");
    if (strlen(nv) > 4) {
      long gu=0,gt=0,mu=0,mt=0;
      char nm[256]="";
      if (sscanf(nv, "%ld, %ld, %ld, %ld, %255[^\n]", &gu, &gt, &mu, &mt, nm) >= 4) {
        gpu_pct=gu; gpu_temp=gt; vram_used=mu*1024*1024; vram_total=mt*1024*1024;
        if (strlen(nm) > 0) strncpy(gpu_name, nm, 255);
      }
    }
    free(nv);
    // Try AMD/Intel via sysfs if NVIDIA failed
    if (gpu_pct == 0) {
      char* amd = shell_capture(
        "cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null");
      rstrip(amd);
      if (strlen(amd) > 0) gpu_pct = atof(amd);
      free(amd);
      char* amd_t = shell_capture(
        "cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1");
      rstrip(amd_t);
      if (strlen(amd_t) > 0) gpu_temp = atof(amd_t) / 1000.0;
      free(amd_t);
      char* gpu_n = shell_capture(
        "cat /sys/class/drm/card0/device/product_name 2>/dev/null");
      rstrip(gpu_n);
      if (strlen(gpu_n) > 0) strncpy(gpu_name, gpu_n, 255);
      free(gpu_n);
    }
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "gpu_percent",  fl_value_new_float(gpu_pct));
    fl_value_set_string_take(map, "temperature_c",fl_value_new_float(gpu_temp));
    fl_value_set_string_take(map, "vram_used",    fl_value_new_int(vram_used));
    fl_value_set_string_take(map, "vram_total",   fl_value_new_int(vram_total));
    fl_value_set_string_take(map, "name",         fl_value_new_string(gpu_name));
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Full process list ─────────────────────────────────────────────────────
  } else if (strcmp(method, "process.list_full") == 0) {
    char* out = shell_capture(
      "ps -eo pid,ppid,user,%cpu,%mem,rss,comm --sort=-%cpu --no-headers 2>/dev/null | head -60");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      int pid=0,ppid=0; float cpu=0,mem=0; long rss=0;
      char user[32]="", comm[256]="";
      if (sscanf(line, "%d %d %31s %f %f %ld %255s",
                 &pid, &ppid, user, &cpu, &mem, &rss, comm) == 7) {
        g_autoptr(FlValue) ent = fl_value_new_map();
        fl_value_set_string_take(ent, "pid",      fl_value_new_int(pid));
        fl_value_set_string_take(ent, "ppid",     fl_value_new_int(ppid));
        fl_value_set_string_take(ent, "user",     fl_value_new_string(user));
        fl_value_set_string_take(ent, "cpu",      fl_value_new_float(cpu));
        fl_value_set_string_take(ent, "mem",      fl_value_new_float(mem));
        fl_value_set_string_take(ent, "rss_kb",   fl_value_new_int(rss));
        fl_value_set_string_take(ent, "name",     fl_value_new_string(comm));
        fl_value_append_take(list, g_steal_pointer(&ent));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Kill process ──────────────────────────────────────────────────────────
  } else if (strcmp(method, "process.kill") == 0) {
    int pid = 0; int sig = 9;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "pid");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) pid = (int)fl_value_get_int(v);
      FlValue* s = fl_value_lookup_string(args, "signal");
      if (s && fl_value_get_type(s) == FL_VALUE_TYPE_INT) sig = (int)fl_value_get_int(s);
    }
    char cmd[64];
    snprintf(cmd, sizeof(cmd), "kill -%d %d 2>/dev/null", sig, pid);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Drop caches (RAM cleaner) ─────────────────────────────────────────────
  } else if (strcmp(method, "memory.drop_caches") == 0) {
    bool ok = shell_ok("sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── App installation ──────────────────────────────────────────────────────
  } else if (strcmp(method, "app.install") == 0) {
    const char* path = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) path = fl_value_get_string(v);
    }
    char cmd[4096]; char* result = nullptr;
    // Detect type by extension
    const char* ext = strrchr(path, '.');
    if (!ext) ext = "";
    if (strcasecmp(ext, ".deb") == 0) {
      snprintf(cmd, sizeof(cmd), "sudo dpkg -i '%s' 2>&1; sudo apt-get install -f -y 2>&1", path);
      result = shell_capture(cmd);
    } else if (strcasecmp(ext, ".exe") == 0 || strcasecmp(ext, ".msi") == 0) {
      snprintf(cmd, sizeof(cmd), "wine '%s' 2>&1", path);
      result = shell_capture(cmd);
    } else if (strcasecmp(ext, ".appimage") == 0) {
      snprintf(cmd, sizeof(cmd), "chmod +x '%s' && '%s' 2>&1", path, path);
      result = shell_capture(cmd);
    } else if (strcasecmp(ext, ".flatpak") == 0) {
      snprintf(cmd, sizeof(cmd), "flatpak install --user -y '%s' 2>&1", path);
      result = shell_capture(cmd);
    } else if (strcasecmp(ext, ".snap") == 0) {
      snprintf(cmd, sizeof(cmd), "sudo snap install '%s' --dangerous 2>&1", path);
      result = shell_capture(cmd);
    } else {
      result = strdup("Unknown file type");
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(result)));
    free(result);

  // ── Flatpak ───────────────────────────────────────────────────────────────
  } else if (strcmp(method, "flatpak.search") == 0) {
    const char* query = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "query");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) query = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "flatpak search '%s' --columns=application,name,description 2>/dev/null | head -40", query);
    char* out = shell_capture(cmd);
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      char id[256]="", name[256]="", desc[512]="";
      if (sscanf(line, "%255s\t%255[^\t]\t%511[^\n]", id, name, desc) >= 2) {
        g_autoptr(FlValue) ent = fl_value_new_map();
        fl_value_set_string_take(ent, "id",   fl_value_new_string(id));
        fl_value_set_string_take(ent, "name", fl_value_new_string(name));
        fl_value_set_string_take(ent, "desc", fl_value_new_string(desc));
        fl_value_append_take(list, g_steal_pointer(&ent));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  } else if (strcmp(method, "flatpak.install") == 0) {
    const char* app_id = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "app_id");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) app_id = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "flatpak install --user -y flathub '%s' 2>&1", app_id);
    char* result = shell_capture(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(result)));
    free(result);

  } else if (strcmp(method, "flatpak.list") == 0) {
    char* out = shell_capture("flatpak list --user --columns=application,name 2>/dev/null");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    bool skip = true;
    while (line) {
      if (skip) { skip = false; line = strtok(nullptr, "\n"); continue; }
      char id[256]="", name[256]="";
      if (sscanf(line, "%255s\t%255[^\n]", id, name) >= 1) {
        g_autoptr(FlValue) ent = fl_value_new_map();
        fl_value_set_string_take(ent, "id",   fl_value_new_string(id));
        fl_value_set_string_take(ent, "name", fl_value_new_string(strlen(name)>0?name:id));
        fl_value_append_take(list, g_steal_pointer(&ent));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Maintenance ───────────────────────────────────────────────────────────
  } else if (strcmp(method, "maintenance.run") == 0) {
    bool ok = shell_ok("bash /usr/local/bin/maintenance.sh >/var/log/krdos/maintenance.log 2>&1 &");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else if (strcmp(method, "maintenance.status") == 0) {
    char* last = shell_capture("cat /var/log/krdos/last_maintenance 2>/dev/null || echo 'Never'");
    rstrip(last);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(last)));
    free(last);

  // ── Startup manager ───────────────────────────────────────────────────────
  } else if (strcmp(method, "startup.list") == 0) {
    char* out = shell_capture(
      "systemctl list-unit-files --type=service --no-legend 2>/dev/null | "
      "grep -E '(enabled|disabled)' | head -40");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      char name[256]="", state[32]="";
      if (sscanf(line, "%255s %31s", name, state) == 2) {
        g_autoptr(FlValue) ent = fl_value_new_map();
        fl_value_set_string_take(ent, "name",    fl_value_new_string(name));
        fl_value_set_string_take(ent, "enabled", fl_value_new_bool(strcmp(state,"enabled")==0));
        fl_value_append_take(list, g_steal_pointer(&ent));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  } else if (strcmp(method, "startup.toggle") == 0) {
    const char* svc = ""; bool enable = true;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "service");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) svc = fl_value_get_string(v);
      FlValue* e = fl_value_lookup_string(args, "enable");
      if (e && fl_value_get_type(e) == FL_VALUE_TYPE_BOOL) enable = fl_value_get_bool(e);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "sudo systemctl %s %s", enable ? "enable" : "disable", svc);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── System optimization (one-shot) ────────────────────────────────────────
  } else if (strcmp(method, "system.optimize") == 0) {
    bool ok = shell_ok("bash /usr/local/bin/optimize.sh >/dev/null 2>&1 &");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Storage analyzer ──────────────────────────────────────────────────────
  } else if (strcmp(method, "storage.analyze") == 0) {
    const char* path = "/";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) path = fl_value_get_string(v);
    }
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
      "du -sb '%s'/* 2>/dev/null | sort -rn | head -20", path);
    char* out = shell_capture(cmd);
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      long sz=0; char p[1024]="";
      if (sscanf(line, "%ld %1023[^\n]", &sz, p) == 2) {
        g_autoptr(FlValue) ent = fl_value_new_map();
        fl_value_set_string_take(ent, "path",  fl_value_new_string(p));
        fl_value_set_string_take(ent, "bytes", fl_value_new_int(sz));
        fl_value_append_take(list, g_steal_pointer(&ent));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  } else if (strcmp(method, "disk.health") == 0) {
    const char* dev = "/dev/sda";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "device");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) dev = fl_value_get_string(v);
    }
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "sudo smartctl -H '%s' 2>/dev/null | grep -E 'result:|health'", dev);
    char* out = shell_capture(cmd);
    rstrip(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_string(strlen(out) > 0 ? out : "unavailable")));
    free(out);

  } else if (strcmp(method, "disk.clean") == 0) {
    const char* path = "/tmp";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) path = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "rm -rf '%s'/* 2>/dev/null; sync", path);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Benchmarks ────────────────────────────────────────────────────────────
  } else if (strcmp(method, "benchmark.run") == 0) {
    // CPU benchmark: time a simple computation via openssl
    char* cpu_res = shell_capture(
      "timeout 3 openssl speed -elapsed sha256 2>/dev/null | grep sha256 | "
      "grep -oP '[0-9]+\\.[0-9]+k' | tail -1");
    rstrip(cpu_res);

    // Disk read (MB/s)
    char* disk_r = shell_capture(
      "dd if=/dev/zero of=/tmp/bench_tmp bs=1M count=128 conv=fdatasync 2>&1 | "
      "grep -oP '[0-9]+\\.[0-9]+ MB/s' | tail -1");
    rstrip(disk_r);

    // Disk write
    char* disk_w = shell_capture(
      "dd if=/tmp/bench_tmp of=/dev/null bs=1M 2>&1 | "
      "grep -oP '[0-9]+\\.[0-9]+ MB/s' | tail -1");
    rstrip(disk_w);
    shell_ok("rm -f /tmp/bench_tmp 2>/dev/null");

    // RAM speed (rough: write 512MB to tmpfs)
    char* ram_s = shell_capture(
      "dd if=/dev/zero of=/dev/shm/bench bs=1M count=512 2>&1 | "
      "grep -oP '[0-9]+\\.[0-9]+ MB/s' | tail -1");
    rstrip(ram_s);
    shell_ok("rm -f /dev/shm/bench 2>/dev/null");

    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "cpu",       fl_value_new_string(cpu_res));
    fl_value_set_string_take(map, "disk_read", fl_value_new_string(disk_r));
    fl_value_set_string_take(map, "disk_write",fl_value_new_string(disk_w));
    fl_value_set_string_take(map, "ram_speed", fl_value_new_string(ram_s));
    free(cpu_res); free(disk_r); free(disk_w); free(ram_s);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Disk usage ────────────────────────────────────────────────────────────
  } else if (strcmp(method, "system.disk_usage") == 0) {
    char* out = shell_capture("df -P -B1 --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | tail -n +2");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      char fs[256]="", mp[256]="";
      long long total=0, used=0, avail=0;
      if (sscanf(line, "%255s %lld %lld %lld %*s %255s", fs, &total, &used, &avail, mp) == 5) {
        g_autoptr(FlValue) ent = fl_value_new_map();
        fl_value_set_string_take(ent, "filesystem", fl_value_new_string(fs));
        fl_value_set_string_take(ent, "mountpoint", fl_value_new_string(mp));
        fl_value_set_string_take(ent, "total",      fl_value_new_int(total));
        fl_value_set_string_take(ent, "used",       fl_value_new_int(used));
        fl_value_set_string_take(ent, "available",  fl_value_new_int(avail));
        fl_value_append_take(list, g_steal_pointer(&ent));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── WiFi scan ────────────────────────────────────────────────────────────
  } else if (strcmp(method, "wifi.scan") == 0) {
    // Trigger a fresh scan then list results in terse parseable format
    shell_ok("nmcli device wifi rescan 2>/dev/null");
    char* out = shell_capture(
      "nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list 2>/dev/null");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      // nmcli -t separates fields with ':'; SSID may contain colons so we
      // split from the RIGHT (signal, security, in-use are last 3 fields).
      // Format: SSID:SIGNAL:SECURITY:IN-USE
      char copy[1024];
      strncpy(copy, line, sizeof(copy)-1);
      copy[sizeof(copy)-1] = '\0';
      // Find last three ':' separators
      int colons = 0;
      for (char* q = copy; *q; q++) if (*q == ':') colons++;
      if (colons < 3) { line = strtok(nullptr, "\n"); continue; }
      // Walk forward to find the 3rd-from-last colon.
      // needed = number of colons inside the SSID itself.
      int needed = colons - 3;
      char* ssid = copy;
      char* split;
      if (needed == 0) {
        // Common case: SSID has no colons — split at first ':'.
        char* first_colon = strchr(copy, ':');
        if (!first_colon) { line = strtok(nullptr, "\n"); continue; }
        *first_colon = '\0';
        split = first_colon + 1;
      } else {
        // SSID contains 'needed' colons: skip them from the left.
        split = copy;
        for (int c = 0; c < needed && *split; split++)
          if (*split == ':') c++;
        // split now points just past the ssid separator colon
        char* ssid_end = split - 1;
        if (ssid_end > copy) *ssid_end = '\0';
      }
      char signal_s[16]="0", security[64]="", inuse[4]="";
      sscanf(split, "%15[^:]:%63[^:]:%3s", signal_s, security, inuse);
      // Skip empty SSIDs (hidden networks)
      if (strlen(ssid) == 0) { line = strtok(nullptr, "\n"); continue; }
      g_autoptr(FlValue) net = fl_value_new_map();
      fl_value_set_string_take(net, "ssid",      fl_value_new_string(ssid));
      fl_value_set_string_take(net, "signal",    fl_value_new_int(atoi(signal_s)));
      fl_value_set_string_take(net, "secured",   fl_value_new_bool(strlen(security) > 0 && strcmp(security,"--") != 0));
      fl_value_set_string_take(net, "connected", fl_value_new_bool(inuse[0] == '*'));
      fl_value_set_string_take(net, "security",  fl_value_new_string(security));
      fl_value_append_take(list, g_steal_pointer(&net));
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── WiFi connect ─────────────────────────────────────────────────────────
  } else if (strcmp(method, "wifi.connect") == 0) {
    const char* ssid = "";
    const char* pwd  = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "ssid");
      if (v) ssid = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "password");
      if (v) pwd = fl_value_get_string(v);
    }
    char cmd[2048];
    if (strlen(pwd) > 0) {
      snprintf(cmd, sizeof(cmd),
        "nmcli device wifi connect \"%s\" password \"%s\"", ssid, pwd);
    } else {
      snprintf(cmd, sizeof(cmd),
        "nmcli device wifi connect \"%s\"", ssid);
    }
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── WiFi disconnect ───────────────────────────────────────────────────────
  } else if (strcmp(method, "wifi.disconnect") == 0) {
    bool ok = shell_ok("nmcli device disconnect $(nmcli -t -f DEVICE,TYPE device | awk -F: '$2==\"wifi\"{print $1;exit}')");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── WiFi saved networks ───────────────────────────────────────────────────
  } else if (strcmp(method, "wifi.saved") == 0) {
    char* out = shell_capture(
      "nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless' | cut -d: -f1");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      if (strlen(line) > 0)
        fl_value_append_take(list, fl_value_new_string(line));
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── WiFi current connection info ──────────────────────────────────────────
  } else if (strcmp(method, "wifi.current") == 0) {
    char* ssid   = shell_capture("nmcli -t -f active,ssid dev wifi | awk -F: '/^yes:/{print $2}'");
    char* signal = shell_capture("nmcli -t -f active,signal dev wifi | awk -F: '/^yes:/{print $2}'");
    char* ip     = shell_capture("nmcli -t -f IP4.ADDRESS dev show $(nmcli -t -f DEVICE,TYPE device | awk -F: '$2==\"wifi\"{print $1;exit}') 2>/dev/null | head -1 | cut -d: -f2");
    rstrip(ssid); rstrip(signal); rstrip(ip);
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "ssid",   fl_value_new_string(ssid));
    fl_value_set_string_take(map, "signal", fl_value_new_int(atoi(signal)));
    fl_value_set_string_take(map, "ip",     fl_value_new_string(ip));
    free(ssid); free(signal); free(ip);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Bluetooth: list known + connected devices ─────────────────────────────
  } else if (strcmp(method, "bluetooth.list") == 0) {
    char* devices = shell_capture("bluetoothctl devices 2>/dev/null");
    char* paired  = shell_capture("bluetoothctl paired-devices 2>/dev/null");
    char* connected_out = shell_capture(
      "bluetoothctl info $(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}') 2>/dev/null | grep 'Device' | awk '{print $2}'");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(devices, "\n");
    while (line) {
      // Format: "Device AA:BB:CC:DD:EE:FF Name"
      char mac[32]="", name[256]="";
      if (sscanf(line, "Device %31s %255[^\n]", mac, name) == 2) {
        bool is_paired    = strstr(paired,  mac) != nullptr;
        bool is_connected = strstr(connected_out, mac) != nullptr;
        // Get device class/type via bluetoothctl info
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "bluetoothctl info %s 2>/dev/null | grep -i 'Class\\|Icon' | head -2", mac);
        char* info = shell_capture(cmd);
        const char* dtype = "device";
        if (strstr(info,"audio") || strstr(info,"headset") || strstr(info,"speaker")) dtype="audio";
        else if (strstr(info,"input") || strstr(info,"keyboard") || strstr(info,"mouse")) dtype="input";
        else if (strstr(info,"phone")) dtype="phone";
        free(info);
        g_autoptr(FlValue) dev = fl_value_new_map();
        fl_value_set_string_take(dev, "name",      fl_value_new_string(name));
        fl_value_set_string_take(dev, "mac",       fl_value_new_string(mac));
        fl_value_set_string_take(dev, "type",      fl_value_new_string(dtype));
        fl_value_set_string_take(dev, "paired",    fl_value_new_bool(is_paired));
        fl_value_set_string_take(dev, "connected", fl_value_new_bool(is_connected));
        fl_value_append_take(list, g_steal_pointer(&dev));
      }
      line = strtok(nullptr, "\n");
    }
    free(devices); free(paired); free(connected_out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Bluetooth: scan for new devices (10 s) ────────────────────────────────
  } else if (strcmp(method, "bluetooth.scan") == 0) {
    // Power on, scan 8 s, list what was discovered
    shell_ok("bluetoothctl power on");
    shell_ok("timeout 8 bluetoothctl scan on");
    // Re-use bluetooth.list logic via a helper command
    char* out = shell_capture("bluetoothctl devices 2>/dev/null");
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      char mac[32]="", name[256]="";
      if (sscanf(line, "Device %31s %255[^\n]", mac, name) == 2) {
        g_autoptr(FlValue) dev = fl_value_new_map();
        fl_value_set_string_take(dev, "name", fl_value_new_string(name));
        fl_value_set_string_take(dev, "mac",  fl_value_new_string(mac));
        fl_value_append_take(list, g_steal_pointer(&dev));
      }
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Bluetooth: pair ───────────────────────────────────────────────────────
  } else if (strcmp(method, "bluetooth.pair") == 0) {
    const char* mac = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "mac");
      if (v) mac = fl_value_get_string(v);
    }
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "bluetoothctl pair %s", mac);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Bluetooth: connect device ─────────────────────────────────────────────
  } else if (strcmp(method, "bluetooth.connect_device") == 0) {
    const char* mac = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "mac");
      if (v) mac = fl_value_get_string(v);
    }
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "bluetoothctl connect %s", mac);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Bluetooth: disconnect device ──────────────────────────────────────────
  } else if (strcmp(method, "bluetooth.disconnect_device") == 0) {
    const char* mac = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "mac");
      if (v) mac = fl_value_get_string(v);
    }
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "bluetoothctl disconnect %s", mac);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Filesystem: list directory ────────────────────────────────────────────
  } else if (strcmp(method, "fs.list") == 0) {
    const char* path = "/";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v) path = fl_value_get_string(v);
    }
    char cmd[2048];
    // stat each entry: type, size, mtime, name
    snprintf(cmd, sizeof(cmd),
      "ls -la --time-style=+%%s \"%s\" 2>/dev/null | tail -n +2", path);
    char* out = shell_capture(cmd);
    g_autoptr(FlValue) list = fl_value_new_list();
    char* line = strtok(out, "\n");
    while (line) {
      if (line[0] == 't') { line = strtok(nullptr, "\n"); continue; } // total line
      char perms[16]="", owner[64]="", group[64]="", ts[32]="", name[1024]="";
      long long size = 0;
      // Parse: perms links owner group size ts name
      int n = sscanf(line, "%15s %*d %63s %63s %lld %31s %1023[^\n]",
                     perms, owner, group, &size, ts, name);
      if (n < 6) { line = strtok(nullptr, "\n"); continue; }
      // Handle symlink "name -> target"
      char* arrow = strstr(name, " -> ");
      if (arrow) *arrow = '\0';
      // Skip . and ..
      if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
        line = strtok(nullptr, "\n"); continue;
      }
      bool is_dir  = (perms[0] == 'd');
      bool is_link = (perms[0] == 'l');
      g_autoptr(FlValue) ent = fl_value_new_map();
      fl_value_set_string_take(ent, "name",     fl_value_new_string(name));
      fl_value_set_string_take(ent, "is_dir",   fl_value_new_bool(is_dir));
      fl_value_set_string_take(ent, "is_link",  fl_value_new_bool(is_link));
      fl_value_set_string_take(ent, "size",     fl_value_new_int(size));
      fl_value_set_string_take(ent, "modified", fl_value_new_string(ts));
      fl_value_set_string_take(ent, "owner",    fl_value_new_string(owner));
      fl_value_set_string_take(ent, "perms",    fl_value_new_string(perms));
      fl_value_append_take(list, g_steal_pointer(&ent));
      line = strtok(nullptr, "\n");
    }
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Filesystem: read text file ────────────────────────────────────────────
  } else if (strcmp(method, "fs.read_text") == 0) {
    const char* path = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v) path = fl_value_get_string(v);
    }
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "head -c 65536 \"%s\" 2>/dev/null", path);
    char* content = shell_capture(cmd);
    g_autoptr(FlValue) val = fl_value_new_string(content ? content : "");
    free(content);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(val));

  // ── Filesystem: delete ────────────────────────────────────────────────────
  } else if (strcmp(method, "fs.delete") == 0) {
    const char* path = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v) path = fl_value_get_string(v);
    }
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "rm -rf \"%s\"", path);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Filesystem: rename / move ─────────────────────────────────────────────
  } else if (strcmp(method, "fs.rename") == 0) {
    const char* from = ""; const char* to = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "from"); if (v) from = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "to");            if (v) to   = fl_value_get_string(v);
    }
    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "mv \"%s\" \"%s\"", from, to);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Filesystem: mkdir ─────────────────────────────────────────────────────
  } else if (strcmp(method, "fs.mkdir") == 0) {
    const char* path = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");
      if (v) path = fl_value_get_string(v);
    }
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", path);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Filesystem: write text file ───────────────────────────────────────────
  } else if (strcmp(method, "fs.write_text") == 0) {
    const char* path = ""; const char* content = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "path");    if (v) path    = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "content"); if (v) content = fl_value_get_string(v);
    }
    FILE* fp = fopen(path, "w");
    bool ok = false;
    if (fp) { fputs(content, fp); fclose(fp); ok = true; }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── USB / removable drives ────────────────────────────────────────────────
  } else if (strcmp(method, "usb.list") == 0) {
    char* out = shell_capture(
      "lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL,RM,VENDOR,MODEL 2>/dev/null");
    // Parse lsblk JSON to find removable (RM=1) and all mounted partitions
    // We pass the raw JSON back and parse on Dart side
    g_autoptr(FlValue) val = fl_value_new_string(out ? out : "{}");
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(val));

  // ── USB: mount a partition ────────────────────────────────────────────────
  } else if (strcmp(method, "usb.mount") == 0) {
    const char* dev = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "device");
      if (v) dev = fl_value_get_string(v);
    }
    char cmd[512];
    // Try udisksctl first (no root needed), fall back to mount
    snprintf(cmd, sizeof(cmd), "udisksctl mount -b \"%s\" 2>/dev/null || mount \"%s\" 2>/dev/null", dev, dev);
    char* out = shell_capture(cmd);
    rstrip(out);
    g_autoptr(FlValue) val = fl_value_new_string(out ? out : "");
    free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(val));

  // ── USB: unmount a partition ──────────────────────────────────────────────
  } else if (strcmp(method, "usb.unmount") == 0) {
    const char* dev = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "device");
      if (v) dev = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "udisksctl unmount -b \"%s\" 2>/dev/null || umount \"%s\" 2>/dev/null", dev, dev);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Battery status ────────────────────────────────────────────────────────
  } else if (strcmp(method, "battery.status") == 0) {
    // Try BAT0, BAT1
    char level_s[32]=""; char status_s[32]="";
    for (int bat = 0; bat <= 1; bat++) {
      char path[128];
      snprintf(path, sizeof(path), "/sys/class/power_supply/BAT%d/capacity", bat);
      FILE* fp = fopen(path, "r");
      if (fp) {
        fgets(level_s, sizeof(level_s), fp); fclose(fp); rstrip(level_s);
        snprintf(path, sizeof(path), "/sys/class/power_supply/BAT%d/status", bat);
        fp = fopen(path, "r");
        if (fp) { fgets(status_s, sizeof(status_s), fp); fclose(fp); rstrip(status_s); }
        break;
      }
    }
    // If no battery found, check AC only
    bool has_battery = strlen(level_s) > 0;
    bool charging = has_battery && strcmp(status_s, "Charging") == 0;
    bool plugged = !has_battery;
    if (!has_battery) {
      // AC adapter present?
      FILE* fp = fopen("/sys/class/power_supply/AC/online", "r");
      if (fp) { char ac[4]=""; fgets(ac, sizeof(ac), fp); fclose(fp); plugged = ac[0]=='1'; }
    }
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "level",       fl_value_new_int(has_battery ? atoi(level_s) : -1));
    fl_value_set_string_take(map, "status",      fl_value_new_string(has_battery ? status_s : "AC"));
    fl_value_set_string_take(map, "charging",    fl_value_new_bool(charging));
    fl_value_set_string_take(map, "plugged",     fl_value_new_bool(plugged));
    fl_value_set_string_take(map, "has_battery", fl_value_new_bool(has_battery));
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Display: set arrangement (multi-monitor layout) ───────────────────────
  } else if (strcmp(method, "display.set_arrangement") == 0) {
    // args: { primary: "eDP-1", outputs: { "eDP-1": {x,y,mode,rate,enabled}, "HDMI-1": {...} } }
    // Build a single xrandr command covering all outputs
    if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
    } else {
      const char* primary = "";
      FlValue* pv = fl_value_lookup_string(args, "primary");
      if (pv) primary = fl_value_get_string(pv);
      FlValue* outputs = fl_value_lookup_string(args, "outputs");
      char cmd[8192] = "xrandr";
      if (outputs && fl_value_get_type(outputs) == FL_VALUE_TYPE_MAP) {
        for (int i = 0; i < fl_value_get_length(outputs); i++) {
          FlValue* key = fl_value_get_map_key(outputs, i);
          FlValue* val2 = fl_value_get_map_value(outputs, i);
          if (!key || !val2) continue;
          const char* outn = fl_value_get_string(key);
          FlValue* enabled_v = fl_value_lookup_string(val2, "enabled");
          bool enabled = !enabled_v || fl_value_get_bool(enabled_v);
          if (!enabled) {
            char part[256];
            snprintf(part, sizeof(part), " --output %s --off", outn);
            strncat(cmd, part, sizeof(cmd)-strlen(cmd)-1);
            continue;
          }
          FlValue* mode_v  = fl_value_lookup_string(val2, "mode");
          FlValue* rate_v  = fl_value_lookup_string(val2, "rate");
          FlValue* x_v     = fl_value_lookup_string(val2, "x");
          FlValue* y_v     = fl_value_lookup_string(val2, "y");
          FlValue* mirror_v= fl_value_lookup_string(val2, "mirror_of");
          const char* mode = mode_v  ? fl_value_get_string(mode_v) : "auto";
          double rate      = rate_v  ? fl_value_get_float(rate_v)  : 0;
          int x            = x_v    ? (int)fl_value_get_int(x_v)   : 0;
          int y            = y_v    ? (int)fl_value_get_int(y_v)   : 0;
          char part[512];
          if (strcmp(mode, "auto") == 0) {
            snprintf(part, sizeof(part), " --output %s --auto --pos %dx%d", outn, x, y);
          } else if (rate > 0) {
            snprintf(part, sizeof(part), " --output %s --mode %s --rate %.2f --pos %dx%d", outn, mode, rate, x, y);
          } else {
            snprintf(part, sizeof(part), " --output %s --mode %s --pos %dx%d", outn, mode, x, y);
          }
          strncat(cmd, part, sizeof(cmd)-strlen(cmd)-1);
          if (strcmp(outn, primary) == 0) {
            strncat(cmd, " --primary", sizeof(cmd)-strlen(cmd)-1);
          }
          if (mirror_v) {
            char mirror_part[128];
            snprintf(mirror_part, sizeof(mirror_part), " --same-as %s", fl_value_get_string(mirror_v));
            strncat(cmd, mirror_part, sizeof(cmd)-strlen(cmd)-1);
          }
        }
      }
      bool ok = shell_ok(cmd);
      resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));
    }

  // ── Browser: launch best available browser ───────────────────────────────
  } else if (strcmp(method, "browser.open") == 0) {
    const char* url = "about:blank";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "url");
      if (v) url = fl_value_get_string(v);
    }
    // Build a shell snippet that:
    //  1. Preserves DISPLAY (falls back to :0 if unset — common in kiosk envs)
    //  2. Tries every common browser binary name in priority order
    //  3. Falls through to xdg-open as a last resort
    //  4. Runs detached so Flutter is not blocked
    // --no-sandbox / --disable-setuid-sandbox are required when KrdOS runs as
    // root (the default kiosk user).  Chromium refuses to start as root without
    // these flags.  Firefox and xdg-open don't need them.
    char cmd[4096];
    snprintf(cmd, sizeof(cmd),
      "DISPLAY=\"${DISPLAY:-:0}\" XAUTHORITY=\"${XAUTHORITY:-/root/.Xauthority}\" "
      "(chromium --no-sandbox --disable-setuid-sandbox \"%s\" 2>/dev/null"
      " || chromium-browser --no-sandbox --disable-setuid-sandbox \"%s\" 2>/dev/null"
      " || google-chrome --no-sandbox --disable-setuid-sandbox \"%s\" 2>/dev/null"
      " || google-chrome-stable --no-sandbox --disable-setuid-sandbox \"%s\" 2>/dev/null"
      " || firefox \"%s\" 2>/dev/null"
      " || firefox-esr \"%s\" 2>/dev/null"
      " || xdg-open \"%s\" 2>/dev/null"
      ") >/dev/null 2>&1 &",
      url, url, url, url, url, url, url);
    shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));

  // ── Ethernet interfaces ───────────────────────────────────────────────────
  } else if (strcmp(method, "ethernet.list") == 0) {
    // Read all Ethernet interfaces from /sys/class/net/.
    // type==1 means ARPHRD_ETHER (ethernet). We skip loopback (lo) and
    // virtual/wifi adapters (wl*, ww*).
    // Returns list of: {iface, connected, ip, speed, mac}
    FlValue* eth_list = fl_value_new_list();
    char* ifaces_raw = shell_capture(
      "for d in /sys/class/net/*/; do"
      "  name=$(basename \"$d\");"
      "  [ \"$name\" = lo ] && continue;"
      "  type=$(cat \"$d/type\" 2>/dev/null) || continue;"
      "  [ \"$type\" = 1 ] || continue;"
      // skip wireless (they start with wl) and mobile (ww)
      "  case \"$name\" in wl*|ww*) continue;; esac;"
      "  state=$(cat \"$d/operstate\" 2>/dev/null);"
      "  ip=$(ip -4 addr show \"$name\" 2>/dev/null"
      "       | awk '/inet /{gsub(/\\/[0-9]+/,\"\",$2); print $2; exit}');"
      "  spd=$(cat \"$d/speed\" 2>/dev/null 2>&1 || echo 0);"
      "  mac=$(cat \"$d/address\" 2>/dev/null);"
      "  printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$state\" \"$ip\" \"$spd\" \"$mac\";"
      "done"
    );
    if (ifaces_raw && strlen(ifaces_raw) > 0) {
      char* line = strtok(ifaces_raw, "\n");
      while (line) {
        // Parse tab-separated: name \t state \t ip \t speed \t mac
        char iface_name[64]={}, state[32]={}, ip[64]={}, spd_str[32]={}, mac[32]={};
        sscanf(line, "%63[^\t]\t%31[^\t]\t%63[^\t]\t%31[^\t]\t%31[^\n]",
               iface_name, state, ip, spd_str, mac);
        if (strlen(iface_name) == 0) { line = strtok(nullptr, "\n"); continue; }
        bool connected = (strcmp(state, "up") == 0);
        int speed_mbps = atoi(spd_str);
        // speed=-1 means unknown (cable present but link not negotiated)
        if (speed_mbps < 0) speed_mbps = 0;

        FlValue* ent = fl_value_new_map();
        fl_value_set_string_take(ent, "iface",     fl_value_new_string(iface_name));
        fl_value_set_string_take(ent, "connected", fl_value_new_bool(connected));
        fl_value_set_string_take(ent, "ip",        fl_value_new_string(ip[0] ? ip : ""));
        fl_value_set_string_take(ent, "speed",     fl_value_new_int(speed_mbps));
        fl_value_set_string_take(ent, "mac",       fl_value_new_string(mac[0] ? mac : ""));
        fl_value_append_take(eth_list, ent);
        line = strtok(nullptr, "\n");
      }
    }
    free(ifaces_raw);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(eth_list));

  // ── System info (CPU model, hostname, kernel, etc.) ───────────────────────
  } else if (strcmp(method, "system.info") == 0) {
    char* hostname = shell_capture("hostname 2>/dev/null");
    char* kernel   = shell_capture("uname -r 2>/dev/null");
    char* cpu      = shell_capture("grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//'");
    char* cores    = shell_capture("nproc 2>/dev/null");
    char* ram      = shell_capture("awk '/MemTotal/{printf \"%.1f GB\", $2/1024/1024}' /proc/meminfo 2>/dev/null");
    char* disk     = shell_capture("df -h / 2>/dev/null | tail -1 | awk '{print $2}'");
    char* arch     = shell_capture("uname -m 2>/dev/null");
    rstrip(hostname); rstrip(kernel); rstrip(cpu); rstrip(cores); rstrip(ram); rstrip(disk); rstrip(arch);
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "hostname",   fl_value_new_string(hostname));
    fl_value_set_string_take(map, "kernel",     fl_value_new_string(kernel));
    fl_value_set_string_take(map, "cpu_model",  fl_value_new_string(cpu));
    fl_value_set_string_take(map, "cpu_cores",  fl_value_new_string(cores));
    fl_value_set_string_take(map, "ram",        fl_value_new_string(ram));
    fl_value_set_string_take(map, "disk_root",  fl_value_new_string(disk));
    fl_value_set_string_take(map, "arch",       fl_value_new_string(arch));
    free(hostname); free(kernel); free(cpu); free(cores); free(ram); free(disk); free(arch);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Update: read local version ─────────────────────────────────────────────
  } else if (strcmp(method, "update.get_version") == 0) {
    char* ver = file_slurp("/opt/krdos/version");
    if (!ver || strlen(ver) == 0) {
      free(ver);
      ver = strdup("unknown");
    }
    rstrip(ver);
    g_autoptr(FlValue) s = fl_value_new_string(ver);
    free(ver);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(s));

  // ── Update: read config (repo + whether a token exists) ──────────────────
  // Token value is NEVER sent to Dart — only a boolean "has_token" is exposed.
  } else if (strcmp(method, "update.get_config") == 0) {
    char* conf_repo = shell_capture(
      "grep -m1 '^GITHUB_REPO=' /etc/krdos/update.conf 2>/dev/null "
      "| cut -d= -f2- | tr -d '[:space:]'");
    char* conf_tok = shell_capture(
      "grep -m1 '^GITHUB_TOKEN=' /etc/krdos/update.conf 2>/dev/null "
      "| cut -d= -f2- | tr -d '[:space:]'");
    if (!conf_repo) conf_repo = strdup("");
    if (!conf_tok)  conf_tok  = strdup("");
    bool has_token = strlen(conf_tok) > 0;
    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "repo",      fl_value_new_string(conf_repo));
    fl_value_set_string_take(map, "has_token", fl_value_new_bool(has_token));
    free(conf_repo); free(conf_tok);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  // ── Update: hit GitHub API and return raw JSON ─────────────────────────────
  // Reads token from /etc/krdos/update.conf; token never leaves C++.
  } else if (strcmp(method, "update.check") == 0) {
    const char* repo = "";
    char conf_repo_buf[256] = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* r = fl_value_lookup_string(args, "repo");
      if (r && fl_value_get_type(r) == FL_VALUE_TYPE_STRING)
        repo = fl_value_get_string(r);
    }
    // Fall back to conf file if caller did not supply repo
    if (strlen(repo) == 0) {
      char* cr = shell_capture(
        "grep -m1 '^GITHUB_REPO=' /etc/krdos/update.conf 2>/dev/null "
        "| cut -d= -f2- | tr -d '[:space:]'");
      if (cr && strlen(cr) > 0) {
        strncpy(conf_repo_buf, cr, sizeof(conf_repo_buf) - 1);
        repo = conf_repo_buf;
      }
      free(cr);
    }
    // Read token — only used here to build the curl header, never returned.
    char* token = shell_capture(
      "grep -m1 '^GITHUB_TOKEN=' /etc/krdos/update.conf 2>/dev/null "
      "| cut -d= -f2- | tr -d '[:space:]'");
    if (!token) token = strdup("");
    char cmd[2048];
    if (strlen(token) > 0) {
      // GitHub PATs are [A-Za-z0-9_-] only — safe to embed directly.
      snprintf(cmd, sizeof(cmd),
        "curl -fsSL --max-time 10 "
        "-H 'Accept: application/vnd.github+json' "
        "-H 'X-GitHub-Api-Version: 2022-11-28' "
        "-H 'Authorization: Bearer %s' "
        "https://api.github.com/repos/%s/releases/latest 2>/dev/null",
        token, repo);
    } else {
      snprintf(cmd, sizeof(cmd),
        "curl -fsSL --max-time 10 "
        "-H 'Accept: application/vnd.github+json' "
        "-H 'X-GitHub-Api-Version: 2022-11-28' "
        "https://api.github.com/repos/%s/releases/latest 2>/dev/null",
        repo);
    }
    free(token);
    char* json = shell_capture(cmd);
    if (!json) json = strdup("{}");
    g_autoptr(FlValue) s = fl_value_new_string(json);
    free(json);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(s));

  // ── Update: launch krdos-update script in background ──────────────────────
  } else if (strcmp(method, "update.apply") == 0) {
    // Runs the update script detached. It will stop krdos-ui, swap binary,
    // restart krdos-ui — Flutter will be killed and relaunched with new build.
    // Brief delay gives Flutter time to show "Updating…" screen before death.
    shell_ok("(sleep 2 && /usr/local/bin/krdos-update 2>&1 "
             " | tee /tmp/krdos-update.log) &");
    g_autoptr(FlValue) b = fl_value_new_bool(TRUE);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(b));

  // ── Update: read live log of running update ────────────────────────────────
  } else if (strcmp(method, "update.read_log") == 0) {
    char* log = file_slurp("/tmp/krdos-update.log");
    if (!log) log = strdup("");
    g_autoptr(FlValue) s = fl_value_new_string(log);
    free(log);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(s));

  // ── Embedded WebKit2GTK browser (GtkOverlay) ────────────────────────────
  // All browser.webview_* methods operate on the WebKitWebView overlay widget
  // embedded directly inside the Flutter GtkWindow via GtkOverlay.
  // No separate window, no X11 hacks — the overlay child is placed at the
  // exact content-area rect supplied by Flutter's RenderBox.localToGlobal.

  } else if (strcmp(method, "browser.webview_show") == 0) {
    // Dart passes the exact content-area rect measured via RenderBox.localToGlobal
    int x = 0, y = 94, w = 1920, h = 986;
    const char* url = "about:blank";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* vx = fl_value_lookup_string(args, "x");
      FlValue* vy = fl_value_lookup_string(args, "y");
      FlValue* vw = fl_value_lookup_string(args, "w");
      FlValue* vh = fl_value_lookup_string(args, "h");
      if (vx && fl_value_get_type(vx) == FL_VALUE_TYPE_INT) x = (int)fl_value_get_int(vx);
      if (vy && fl_value_get_type(vy) == FL_VALUE_TYPE_INT) y = (int)fl_value_get_int(vy);
      if (vw && fl_value_get_type(vw) == FL_VALUE_TYPE_INT) w = (int)fl_value_get_int(vw);
      if (vh && fl_value_get_type(vh) == FL_VALUE_TYPE_INT) h = (int)fl_value_get_int(vh);
      FlValue* u = fl_value_lookup_string(args, "url");
      if (u && fl_value_get_type(u) == FL_VALUE_TYPE_STRING)
        url = fl_value_get_string(u);
    }
    webwin_show(x, y, w, h);
    webwin_navigate(url);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_reposition") == 0) {
    // Reposition the visible WebKit window when the browser app window moves.
    int x = 0, y = 94, w = 1920, h = 986;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* vx = fl_value_lookup_string(args, "x");
      FlValue* vy = fl_value_lookup_string(args, "y");
      FlValue* vw = fl_value_lookup_string(args, "w");
      FlValue* vh = fl_value_lookup_string(args, "h");
      if (vx && fl_value_get_type(vx) == FL_VALUE_TYPE_INT) x = (int)fl_value_get_int(vx);
      if (vy && fl_value_get_type(vy) == FL_VALUE_TYPE_INT) y = (int)fl_value_get_int(vy);
      if (vw && fl_value_get_type(vw) == FL_VALUE_TYPE_INT) w = (int)fl_value_get_int(vw);
      if (vh && fl_value_get_type(vh) == FL_VALUE_TYPE_INT) h = (int)fl_value_get_int(vh);
    }
    webwin_reposition(x, y, w, h);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_hide") == 0) {
    webwin_hide();
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_navigate") == 0) {
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_STRING)
      webwin_navigate(fl_value_get_string(args));
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_back") == 0) {
    if (g_webview && webkit_web_view_can_go_back(g_webview))
      webkit_web_view_go_back(g_webview);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_forward") == 0) {
    if (g_webview && webkit_web_view_can_go_forward(g_webview))
      webkit_web_view_go_forward(g_webview);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_reload") == 0) {
    if (g_webview) webkit_web_view_reload(g_webview);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_stop") == 0) {
    if (g_webview) webkit_web_view_stop_loading(g_webview);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.webview_get_info") == 0) {
    FlValue* map = fl_value_new_map();
    if (g_webview) {
      const char* uri    = webkit_web_view_get_uri(g_webview);
      const char* title  = webkit_web_view_get_title(g_webview);
      gboolean can_back  = webkit_web_view_can_go_back(g_webview);
      gboolean can_fwd   = webkit_web_view_can_go_forward(g_webview);
      gboolean loading   = webkit_web_view_is_loading(g_webview);
      double   progress  = webkit_web_view_get_estimated_load_progress(g_webview);
      fl_value_set_string_take(map, "url",
        fl_value_new_string(uri   ? uri   : ""));
      fl_value_set_string_take(map, "title",
        fl_value_new_string((title && title[0]) ? title : (uri ? uri : "")));
      fl_value_set_string_take(map, "canGoBack",    fl_value_new_bool(can_back));
      fl_value_set_string_take(map, "canGoForward", fl_value_new_bool(can_fwd));
      fl_value_set_string_take(map, "isLoading",    fl_value_new_bool(loading));
      fl_value_set_string_take(map, "progress",     fl_value_new_float(progress));
    } else {
      fl_value_set_string_take(map, "url",          fl_value_new_string(""));
      fl_value_set_string_take(map, "title",        fl_value_new_string(""));
      fl_value_set_string_take(map, "canGoBack",    fl_value_new_bool(FALSE));
      fl_value_set_string_take(map, "canGoForward", fl_value_new_bool(FALSE));
      fl_value_set_string_take(map, "isLoading",    fl_value_new_bool(FALSE));
      fl_value_set_string_take(map, "progress",     fl_value_new_float(0.0));
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(map));

  } else if (strcmp(method, "browser.cookies_clear") == 0) {
    // Clear all cookies via WebsiteDataManager (WebKit2GTK 4.1 API).
    if (g_webview) {
      WebKitWebContext*       ctx = webkit_web_view_get_context(g_webview);
      WebKitWebsiteDataManager* dm = webkit_web_context_get_website_data_manager(ctx);
      webkit_website_data_manager_clear(dm, WEBKIT_WEBSITE_DATA_COOKIES,
                                        0, nullptr, nullptr, nullptr);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  } else if (strcmp(method, "browser.js_run") == 0) {
    // Run arbitrary JavaScript in the current page (fire-and-forget).
    // args is a map {"script": "..."} or a plain string.
    if (g_webview) {
      const char* script = nullptr;
      if (args) {
        if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
          script = fl_value_get_string(args);
        } else if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
          FlValue* sv = fl_value_lookup_string(args, "script");
          if (sv && fl_value_get_type(sv) == FL_VALUE_TYPE_STRING)
            script = fl_value_get_string(sv);
        }
      }
      if (script && script[0]) {
        // webkit_web_view_evaluate_javascript is the 4.1 replacement for
        // webkit_web_view_run_javascript. Pass -1 for null-terminated length.
        webkit_web_view_evaluate_javascript(g_webview, script, -1,
                                            nullptr, nullptr,
                                            nullptr, nullptr, nullptr);
      }
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));

  // ── Drives: structured list of all block devices ──────────────────────────
  // Returns list of: {name, device, label, size, type, mountpoint, removable, vendor, model}
  // type is "disk" or "part". Only includes disk and part (skips loop, rom, etc.)
  } else if (strcmp(method, "drives.list") == 0) {
    char* raw = shell_capture(
      "lsblk -rn -P -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL,RM,VENDOR,MODEL 2>/dev/null");
    FlValue* list = fl_value_new_list();
    if (raw && strlen(raw) > 0) {
      char* line = strtok(raw, "\n");
      while (line) {
        char* type = lsblk_kv(line, "TYPE");
        if (strcmp(type, "disk") == 0 || strcmp(type, "part") == 0) {
          char* name   = lsblk_kv(line, "NAME");
          char* size   = lsblk_kv(line, "SIZE");
          char* mp     = lsblk_kv(line, "MOUNTPOINT");
          char* label  = lsblk_kv(line, "LABEL");
          char* rm     = lsblk_kv(line, "RM");
          char* vendor = lsblk_kv(line, "VENDOR");
          char* model  = lsblk_kv(line, "MODEL");
          g_autoptr(FlValue) entry = fl_value_new_map();
          char dev[64];
          snprintf(dev, sizeof(dev), "/dev/%s", name);
          // Display label if present, otherwise use name
          const char* disp = (strlen(label) > 0) ? label : name;
          fl_value_set_string_take(entry, "name",       fl_value_new_string(name));
          fl_value_set_string_take(entry, "device",     fl_value_new_string(dev));
          fl_value_set_string_take(entry, "label",      fl_value_new_string(disp));
          fl_value_set_string_take(entry, "size",       fl_value_new_string(size));
          fl_value_set_string_take(entry, "type",       fl_value_new_string(type));
          fl_value_set_string_take(entry, "mountpoint", fl_value_new_string(mp));
          fl_value_set_string_take(entry, "removable",  fl_value_new_bool(strcmp(rm, "1") == 0));
          fl_value_set_string_take(entry, "vendor",     fl_value_new_string(vendor));
          fl_value_set_string_take(entry, "model",      fl_value_new_string(model));
          fl_value_append_take(list, g_steal_pointer(&entry));
          free(name); free(size); free(mp); free(label); free(rm);
          free(vendor); free(model);
        }
        free(type);
        line = strtok(nullptr, "\n");
      }
    }
    if (raw) free(raw);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Apps: list installed GUI apps via .desktop files ──────────────────────
  // Scans /usr/share/applications/*.desktop — only actual GUI apps (not 500+
  // Kali meta-packages from apt-mark showmanual).
  // Returns: {id, name, version, size_kb, desc, categories, icon, source:"deb"}
  } else if (strcmp(method, "apps.list_dpkg") == 0) {
    char* raw = shell_capture(
      "for f in /usr/share/applications/*.desktop"
      " /usr/local/share/applications/*.desktop; do"
      "  [ -f \"$f\" ] || continue;"
      "  nd=$(grep -m1 '^NoDisplay=' \"$f\" 2>/dev/null | cut -d= -f2-);"
      "  [ \"$nd\" = 'true' ] || [ \"$nd\" = 'True' ] && continue;"
      "  nm=$(grep -m1 '^Name=' \"$f\" 2>/dev/null | cut -d= -f2-);"
      "  [ -z \"$nm\" ] && continue;"
      "  dc=$(grep -m1 '^Comment=' \"$f\" 2>/dev/null | cut -d= -f2-);"
      "  ct=$(grep -m1 '^Categories=' \"$f\" 2>/dev/null | cut -d= -f2-);"
      "  ic=$(grep -m1 '^Icon=' \"$f\" 2>/dev/null | cut -d= -f2-);"
      "  printf '%s\\t%s\\t%s\\t%s\\n' \"$nm\" \"$dc\" \"$ct\" \"$ic\";"
      " done 2>/dev/null | sort -u");
    FlValue* list = fl_value_new_list();
    if (raw && strlen(raw) > 0) {
      char* line = strtok(raw, "\n");
      while (line) {
        char name[256]="", desc[512]="", cats[256]="", icon[128]="";
        sscanf(line, "%255[^\t]\t%511[^\t]\t%255[^\t]\t%127[^\n]",
               name, desc, cats, icon);
        if (strlen(name) > 0) {
          // Build slug id: lowercase, spaces/slashes → dashes
          char id[256] = "";
          strncpy(id, name, sizeof(id) - 1);
          for (int ci = 0; id[ci]; ci++) {
            id[ci] = (id[ci] == ' ' || id[ci] == '/') ? '-'
                   : (id[ci] >= 'A' && id[ci] <= 'Z') ? (char)(id[ci] + 32)
                   : id[ci];
          }
          g_autoptr(FlValue) entry = fl_value_new_map();
          fl_value_set_string_take(entry, "id",         fl_value_new_string(id));
          fl_value_set_string_take(entry, "name",       fl_value_new_string(name));
          fl_value_set_string_take(entry, "version",    fl_value_new_string(""));
          fl_value_set_string_take(entry, "size_kb",    fl_value_new_int(0));
          fl_value_set_string_take(entry, "desc",       fl_value_new_string(desc));
          fl_value_set_string_take(entry, "categories", fl_value_new_string(cats));
          fl_value_set_string_take(entry, "icon",       fl_value_new_string(icon));
          fl_value_set_string_take(entry, "source",     fl_value_new_string("deb"));
          fl_value_append_take(list, g_steal_pointer(&entry));
        }
        line = strtok(nullptr, "\n");
      }
    }
    if (raw) free(raw);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Apps: uninstall a deb package (apt-get remove --purge) ───────────────
  } else if (strcmp(method, "apps.uninstall_deb") == 0) {
    const char* pkg = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "package");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) pkg = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
      "DEBIAN_FRONTEND=noninteractive sudo apt-get remove --purge -y '%s' 2>&1 | tail -8", pkg);
    char* out = shell_capture(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_string(out ? out : "error")));
    if (out) free(out);

  // ── Apps: uninstall a Flatpak app ─────────────────────────────────────────
  } else if (strcmp(method, "apps.uninstall_flatpak") == 0) {
    const char* app_id = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "app_id");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) app_id = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
      "flatpak uninstall --user -y '%s' 2>&1 | tail -5", app_id);
    char* out = shell_capture(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_string(out ? out : "error")));
    if (out) free(out);

  // ── Apps: get detailed dpkg-query -s output for a deb package ────────────
  } else if (strcmp(method, "apps.get_info_deb") == 0) {
    const char* pkg = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "package");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) pkg = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "dpkg-query -s '%s' 2>/dev/null", pkg);
    char* out = shell_capture(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_string(out ? out : "")));
    if (out) free(out);

  // ── Apps: get Flatpak app permissions (flatpak info --show-permissions) ───
  } else if (strcmp(method, "apps.get_permissions_flatpak") == 0) {
    const char* app_id = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "app_id");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) app_id = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "flatpak info --show-permissions '%s' 2>/dev/null", app_id);
    char* out = shell_capture(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_string(out ? out : "")));
    if (out) free(out);

  // ── Apps: toggle Flatpak network permission (flatpak override) ────────────
  // This is the one Flatpak permission that meaningfully maps to a network kill.
  // allowed=true  → flatpak override --user --share=network  <app_id>
  // allowed=false → flatpak override --user --unshare=network <app_id>
  } else if (strcmp(method, "apps.set_network_flatpak") == 0) {
    const char* app_id = "";
    bool allowed = true;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* ai = fl_value_lookup_string(args, "app_id");
      FlValue* al = fl_value_lookup_string(args, "allowed");
      if (ai && fl_value_get_type(ai) == FL_VALUE_TYPE_STRING)
        app_id = fl_value_get_string(ai);
      if (al && fl_value_get_type(al) == FL_VALUE_TYPE_BOOL)
        allowed = fl_value_get_bool(al);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
      allowed ? "flatpak override --user --share=network '%s' 2>/dev/null"
              : "flatpak override --user --unshare=network '%s' 2>/dev/null",
      app_id);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Firewall: UFW status ──────────────────────────────────────────────────
  } else if (strcmp(method, "firewall.status") == 0) {
    char* out = shell_capture("ufw status verbose 2>/dev/null");
    bool enabled = out && strstr(out, "Status: active") != nullptr;
    FlValue* m = fl_value_new_map();
    fl_value_set_string_take(m, "enabled", fl_value_new_bool(enabled));
    fl_value_set_string_take(m, "raw",     fl_value_new_string(out ? out : ""));
    if (out) free(out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(m));

  // ── Firewall: enable ─────────────────────────────────────────────────────
  } else if (strcmp(method, "firewall.enable") == 0) {
    bool ok = shell_ok("ufw --force enable 2>/dev/null");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Firewall: disable ────────────────────────────────────────────────────
  } else if (strcmp(method, "firewall.disable") == 0) {
    bool ok = shell_ok("ufw disable 2>/dev/null");
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Firewall: list rules (numbered) ──────────────────────────────────────
  } else if (strcmp(method, "firewall.list_rules") == 0) {
    char* out = shell_capture("ufw status numbered 2>/dev/null");
    FlValue* list = fl_value_new_list();
    if (out) {
      char* line = strtok(out, "\n");
      while (line) {
        int num = 0; char rest[256] = {};
        if (sscanf(line, " [ %d]%255[^\n]", &num, rest) == 2) {
          int i = 0; while (rest[i] == ' ') i++;
          FlValue* entry = fl_value_new_map();
          fl_value_set_string_take(entry, "num",  fl_value_new_int(num));
          fl_value_set_string_take(entry, "rule", fl_value_new_string(rest + i));
          fl_value_append_take(list, entry);
        }
        line = strtok(nullptr, "\n");
      }
      free(out);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Firewall: add rule ────────────────────────────────────────────────────
  } else if (strcmp(method, "firewall.add_rule") == 0) {
    const char* port = ""; const char* proto = "tcp";
    const char* action = "allow"; const char* direction = "in";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v;
      v = fl_value_lookup_string(args, "port");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) port = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "proto");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) proto = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "action");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) action = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "direction");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) direction = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "ufw %s %s %s/%s 2>/dev/null", action, direction, port, proto);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Firewall: delete rule by number ──────────────────────────────────────
  } else if (strcmp(method, "firewall.delete_rule") == 0) {
    int num = 0;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "num");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) num = (int)fl_value_get_int(v);
    }
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "echo y | ufw delete %d 2>/dev/null", num);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── SSH Keys: list ~/.ssh/*.pub ───────────────────────────────────────────
  } else if (strcmp(method, "keys.list") == 0) {
    char* out = shell_capture("ls -1 ~/.ssh/*.pub 2>/dev/null");
    FlValue* list = fl_value_new_list();
    if (out) {
      char* line = strtok(out, "\n");
      while (line) {
        rstrip(line);
        if (strlen(line) == 0) { line = strtok(nullptr, "\n"); continue; }
        char fp_cmd[512];
        snprintf(fp_cmd, sizeof(fp_cmd), "ssh-keygen -l -f '%s' 2>/dev/null", line);
        char* fp = shell_capture(fp_cmd);
        const char* base = strrchr(line, '/');
        char name[128] = {};
        if (base) {
          strncpy(name, base + 1, 127);
          char* dot = strstr(name, ".pub");
          if (dot) *dot = '\0';
        }
        FlValue* m = fl_value_new_map();
        fl_value_set_string_take(m, "pub_path",    fl_value_new_string(line));
        fl_value_set_string_take(m, "name",         fl_value_new_string(name));
        fl_value_set_string_take(m, "fingerprint",  fl_value_new_string(fp ? fp : ""));
        if (fp) free(fp);
        fl_value_append_take(list, m);
        line = strtok(nullptr, "\n");
      }
      free(out);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── SSH Keys: generate new key pair ─────────────────────────────────────
  } else if (strcmp(method, "keys.generate") == 0) {
    const char* type = "ed25519"; const char* comment = "krdos"; const char* passphrase = "";
    char filename[256]; snprintf(filename, sizeof(filename), "/root/.ssh/id_ed25519_krdos");
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v;
      v = fl_value_lookup_string(args, "type");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) type = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "comment");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) comment = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "passphrase");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) passphrase = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "filename");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING)
        snprintf(filename, sizeof(filename), "%s", fl_value_get_string(v));
      else
        snprintf(filename, sizeof(filename), "/root/.ssh/id_%s_krdos", type);
    }
    shell_ok("mkdir -p /root/.ssh && chmod 700 /root/.ssh");
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
      "ssh-keygen -t '%s' -C '%s' -f '%s' -N '%s' 2>&1", type, comment, filename, passphrase);
    char* gen_out = shell_capture(cmd);
    bool ok = gen_out && strstr(gen_out, "Your identification has been saved") != nullptr;
    FlValue* m = fl_value_new_map();
    fl_value_set_string_take(m, "ok",       fl_value_new_bool(ok));
    fl_value_set_string_take(m, "output",   fl_value_new_string(gen_out ? gen_out : ""));
    fl_value_set_string_take(m, "pub_path", fl_value_new_string(filename));
    if (gen_out) free(gen_out);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(m));

  // ── SSH Keys: read public key content ────────────────────────────────────
  } else if (strcmp(method, "keys.get_public") == 0) {
    const char* pub_path = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "pub_path");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) pub_path = fl_value_get_string(v);
    }
    char cmd[512]; snprintf(cmd, sizeof(cmd), "cat '%s' 2>/dev/null", pub_path);
    char* pub_out = shell_capture(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_string(pub_out ? pub_out : "")));
    if (pub_out) free(pub_out);

  // ── SSH Keys: delete key pair (private + public) ──────────────────────────
  } else if (strcmp(method, "keys.delete") == 0) {
    const char* pub_path = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "pub_path");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) pub_path = fl_value_get_string(v);
    }
    char priv[512]; strncpy(priv, pub_path, 511); priv[511] = '\0';
    char* dot = strrchr(priv, '.'); if (dot && strcmp(dot, ".pub") == 0) *dot = '\0';
    char cmd[1024]; snprintf(cmd, sizeof(cmd), "rm -f '%s' '%s.pub' 2>/dev/null", priv, priv);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Vault: check status (exists + file count) ─────────────────────────────
  } else if (strcmp(method, "vault.status") == 0) {
    bool has_marker = shell_ok("test -f /root/.krdos_vault/.vault_id");
    char* cnt = shell_capture("ls -1 /root/.krdos_vault/*.vlt 2>/dev/null | wc -l");
    FlValue* m = fl_value_new_map();
    fl_value_set_string_take(m, "exists",     fl_value_new_bool(has_marker));
    fl_value_set_string_take(m, "file_count", fl_value_new_int(cnt ? atoi(cnt) : 0));
    if (cnt) free(cnt);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(m));

  // ── Vault: create (initialise with passphrase) ───────────────────────────
  } else if (strcmp(method, "vault.create") == 0) {
    const char* passphrase = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "passphrase");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) passphrase = fl_value_get_string(v);
    }
    shell_ok("mkdir -p /root/.krdos_vault && chmod 700 /root/.krdos_vault");
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
      "echo 'KrdOS-Vault-v1' | openssl enc -aes-256-cbc -salt -pbkdf2 "
      "-out /root/.krdos_vault/.vault_id -pass pass:'%s' 2>/dev/null", passphrase);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Vault: verify passphrase ─────────────────────────────────────────────
  } else if (strcmp(method, "vault.verify") == 0) {
    const char* passphrase = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "passphrase");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) passphrase = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
      "openssl enc -d -aes-256-cbc -salt -pbkdf2 "
      "-in /root/.krdos_vault/.vault_id -pass pass:'%s' 2>/dev/null | grep -q 'KrdOS-Vault-v1'",
      passphrase);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Vault: list encrypted files ──────────────────────────────────────────
  } else if (strcmp(method, "vault.list_files") == 0) {
    char* out = shell_capture("ls -1 /root/.krdos_vault/*.vlt 2>/dev/null");
    FlValue* list = fl_value_new_list();
    if (out) {
      char* line = strtok(out, "\n");
      while (line) {
        rstrip(line);
        if (strlen(line) < 2) { line = strtok(nullptr, "\n"); continue; }
        const char* base = strrchr(line, '/');
        char name[256] = {};
        if (base) {
          strncpy(name, base + 1, 255);
          char* dot = strstr(name, ".vlt"); if (dot) *dot = '\0';
        }
        char szc[512]; snprintf(szc, sizeof(szc), "stat -c %%s '%s' 2>/dev/null", line);
        char* sz = shell_capture(szc);
        FlValue* m = fl_value_new_map();
        fl_value_set_string_take(m, "name", fl_value_new_string(name));
        fl_value_set_string_take(m, "path", fl_value_new_string(line));
        fl_value_set_string_take(m, "size", fl_value_new_string(sz ? sz : "0"));
        if (sz) free(sz);
        fl_value_append_take(list, m);
        line = strtok(nullptr, "\n");
      }
      free(out);
    }
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(list));

  // ── Vault: encrypt and store a file ──────────────────────────────────────
  } else if (strcmp(method, "vault.add_file") == 0) {
    const char* src_path = ""; const char* passphrase = ""; const char* name = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v;
      v = fl_value_lookup_string(args, "src_path");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) src_path = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "passphrase");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) passphrase = fl_value_get_string(v);
      v = fl_value_lookup_string(args, "name");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) name = fl_value_get_string(v);
    }
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
      "openssl enc -aes-256-cbc -salt -pbkdf2 -in '%s' "
      "-out '/root/.krdos_vault/%s.vlt' -pass pass:'%s' 2>/dev/null",
      src_path, name, passphrase);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  // ── Vault: remove encrypted file ─────────────────────────────────────────
  } else if (strcmp(method, "vault.remove_file") == 0) {
    const char* name = "";
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "name");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) name = fl_value_get_string(v);
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "rm -f '/root/.krdos_vault/%s.vlt' 2>/dev/null", name);
    bool ok = shell_ok(cmd);
    resp = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));

  } else {
    resp = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(call, resp, nullptr);
}

// ---------------------------------------------------------------------------
// Public init
// ---------------------------------------------------------------------------

void system_channel_init(FlPluginRegistry* registry) {
  FlPluginRegistrar* registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SystemChannel");
  // Store globally so the WebKit helpers can reach the main GtkWindow.
  g_reg = FL_PLUGIN_REGISTRAR(g_object_ref(G_OBJECT(registrar)));
  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  // Keep the channel alive for the lifetime of the process
  FlMethodChannel* channel =
      fl_method_channel_new(messenger, kChannelName, FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(channel, on_method_call,
                                            nullptr, nullptr);
  // g_object_ref keeps it from being freed immediately
  g_object_ref(channel);
}
