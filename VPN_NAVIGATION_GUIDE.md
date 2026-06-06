# Multi-Hop VPN - Navigation Guide

## 🗺️ Where to Find VPN Settings

### Method 1: Through Settings App

```
Desktop/Home Screen
    │
    ├─ Click "Settings" app icon
    │
    └─ Settings Screen Opens
        │
        ├─ Sidebar: Click "Network" (WiFi icon)
        │   OR
        ├─ Overview: Click "Network" tile
        │
        └─ Network Settings Screen
            │
            ├─ Top Tabs: [Wi-Fi] [VPN] [Firewall] [DNS] [Proxy]
            │
            └─ Click "VPN" tab
                │
                └─ Multi-Hop VPN Screen ✨
                    │
                    ├─ Connection Status Dashboard
                    │   ├─ Protected/Disconnected indicator
                    │   ├─ Latency, Hops, Data stats
                    │   └─ Connect/Disconnect button
                    │
                    ├─ Hop Chain Section
                    │   ├─ Drag-and-drop reordering
                    │   ├─ Remove individual hops
                    │   └─ Clear all button
                    │
                    ├─ Available Servers Section
                    │   ├─ 15 global servers
                    │   ├─ Ping & Load metrics
                    │   └─ Add/Remove buttons
                    │
                    └─ Advanced Settings Section
                        ├─ Kill Switch toggle
                        ├─ DNS Leak Protection toggle
                        ├─ Auto-Reconnect toggle
                        └─ IPv6 Leak Protection toggle
```

### Method 2: Through Control Center (Quick Access)

```
Desktop/Home Screen
    │
    ├─ Click Control Center icon (top-right)
    │   OR
    ├─ Swipe down from top (mobile/tablet)
    │
    └─ Control Center Opens
        │
        ├─ Quick Settings Grid
        │   │
        │   ├─ [VPN] tile (shows "3H VPN" when connected)
        │   │   │
        │   │   ├─ Tap to Connect/Disconnect
        │   │   └─ Shows danger indicator when off
        │   │
        │   ├─ [Firewall] tile
        │   ├─ [IP Mask] tile
        │   └─ [Dark Mode] tile
        │
        └─ For full settings, go to Settings → Network → VPN
```

---

## 📱 Screen Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                     SETTINGS SCREEN                         │
│  ┌───────────────┬──────────────────────────────────────┐  │
│  │   SIDEBAR     │         DETAIL PANE                  │  │
│  │               │                                       │  │
│  │ System        │  ┌─────────────────────────────────┐ │  │
│  │ ├─ Display    │  │    NETWORK SETTINGS SCREEN      │ │  │
│  │ ├─ Network ✓  │  │                                 │ │  │
│  │ ├─ Security   │  │  [Wi-Fi] [VPN✓] [Firewall]...  │ │  │
│  │ └─ About      │  │                                 │ │  │
│  │               │  │  ┌───────────────────────────┐  │ │  │
│  │ Personal...   │  │  │  MULTI-HOP VPN SCREEN    │  │ │  │
│  │ ├─ Personal.. │  │  │                          │  │ │  │
│  │ └─ Taskbar    │  │  │  🛡️ Connection Status   │  │ │  │
│  │               │  │  │  ├─ Protected/Disc.      │  │ │  │
│  │ Apps          │  │  │  ├─ Stats (Latency...)   │  │ │  │
│  │ └─ Apps       │  │  │  └─ [Connect] button    │  │ │  │
│  │               │  │  │                          │  │ │  │
│  │ Accounts      │  │  │  🔗 Hop Chain            │  │ │  │
│  │ ├─ Sign-in    │  │  │  ├─ 1. 🇺🇸 New York     │  │ │  │
│  │ └─ Users      │  │  │  ├─ 2. 🇬🇧 London       │  │ │  │
│  │               │  │  │  └─ 3. 🇩🇪 Berlin       │  │ │  │
│  └───────────────┘  │  │                          │  │ │  │
│                     │  │  🌍 Available Servers    │  │ │  │
│                     │  │  ├─ 🇯🇵 Tokyo [Add]      │  │ │  │
│                     │  │  ├─ 🇸🇬 Singapore [Add]  │  │ │  │
│                     │  │  └─ ...                  │  │ │  │
│                     │  │                          │  │ │  │
│                     │  │  ⚙️ Advanced Settings    │  │ │  │
│                     │  │  ├─ Kill Switch [ON]    │  │ │  │
│                     │  │  ├─ DNS Leak Prot. [ON] │  │ │  │
│                     │  │  └─ ...                  │  │ │  │
│                     │  └───────────────────────────┘  │ │  │
│                     └─────────────────────────────────┘ │  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Quick Actions

### To Connect to VPN:
1. **Settings** → **Network** → **VPN** tab
2. Add 2-3 servers to hop chain
3. Click **Connect** button
4. ✅ Status shows "Protected"

### To Disconnect:
1. Click **Disconnect** button in VPN screen
   OR
2. Toggle VPN in Control Center

### To Reorder Hops:
1. In Hop Chain section
2. Drag server cards up/down
3. Order changes automatically

### To Remove a Hop:
1. Click ❌ icon on hop card
   OR
2. Click **Remove** on server in Available Servers list

---

## 🔍 Visual Indicators

### Connection Status:
- 🟢 **Green border** = Connected & Protected
- ⚪ **Gray border** = Disconnected
- 🛡️ **Shield icon** = Protection active

### Server Metrics:
- 🟢 **Green badge** = Good (ping <100ms, load <50%)
- 🟡 **Yellow badge** = Warning (ping ≥100ms, load ≥50%)

### Control Center VPN Tile:
- **"VPN"** = Disconnected (red danger indicator)
- **"3H VPN"** = Connected with 3 hops (green active)

---

## 📋 Step-by-Step Setup Guide

### First Time Setup:

1. **Open Settings**
   - Click Settings icon on desktop/taskbar

2. **Navigate to Network**
   - Click "Network" in sidebar
   - OR click "Network" tile in overview

3. **Open VPN Tab**
   - Click "VPN" in the top tab bar

4. **Add First Server**
   - Scroll to "Available Servers"
   - Find a server (e.g., 🇺🇸 New York)
   - Click **Add** button
   - Server appears in "Hop Chain"

5. **Add More Servers** (Optional)
   - Add 1-2 more servers for multi-hop
   - Each server adds to the chain

6. **Configure Security** (Optional)
   - Scroll to "Advanced Settings"
   - Enable Kill Switch (recommended)
   - Enable DNS Leak Protection (recommended)

7. **Connect**
   - Click the big **Connect** button
   - Status changes to "Protected"
   - Stats start updating

8. **Verify Connection**
   - Check Control Center VPN tile
   - Should show "3H VPN" (or your hop count)

---

## 🎨 UI Elements Explained

### Connection Status Card:
```
┌─────────────────────────────────────────┐
│ 🛡️  Protected                           │
│     Traffic encrypted through 3 hops    │
│                                         │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│ │ 215ms   │ │ 3 Hops  │ │ 2.4 MB  │   │
│ │ Latency │ │         │ │ Data    │   │
│ └─────────┘ └─────────┘ └─────────┘   │
│                                         │
│         [Disconnect]                    │
└─────────────────────────────────────────┘
```

### Hop Chain Card:
```
┌─────────────────────────────────────────┐
│ Hop Chain                    [Clear]    │
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 1  🇺🇸  New York #1          ❌  ☰ ││
│ │     United States • 45ms           ││
│ └─────────────────────────────────────┘│
│ ┌─────────────────────────────────────┐│
│ │ 2  🇬🇧  London #1            ❌  ☰ ││
│ │     United Kingdom • 78ms          ││
│ └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### Server Card:
```
┌─────────────────────────────────────────┐
│ 🇯🇵  Tokyo #1                           │
│     Japan, Tokyo                        │
│                                         │
│     [156ms]  [51%]         [Add]       │
└─────────────────────────────────────────┘
```

---

## 🚀 Pro Tips

1. **Optimal Hop Count**: 2-3 hops for best balance of security and speed
2. **Server Selection**: Choose servers with low ping (<100ms) and low load (<50%)
3. **Geographic Diversity**: Select servers from different countries for maximum privacy
4. **Kill Switch**: Always enable to prevent IP leaks on disconnect
5. **Quick Toggle**: Use Control Center for fast connect/disconnect

---

## 🔧 Troubleshooting

### Can't Connect?
- Ensure at least 1 server is in hop chain
- Check if servers have good metrics (green badges)

### Slow Connection?
- Reduce hop count (fewer servers)
- Choose servers with lower ping
- Select servers with lower load percentage

### VPN Not Showing in Control Center?
- VPN tile is in first page of Quick Settings
- Swipe/scroll if on second page

---

This navigation guide should help you find and use the Multi-Hop VPN system easily! 🎉
