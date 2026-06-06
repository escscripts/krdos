import 'package:flutter/material.dart';

/// Browsing backends. Embedded Tor routes WebView2 through a local SOCKS proxy
/// (Tor Expert Bundle/Tor daemon); pick host/port under Browser Settings.
enum BrowserShellBackend {
  chromiumEmbedded,
  microsoftEdgeWebView2,
  torEmbeddedSocks,
}

extension BrowserShellBackendX on BrowserShellBackend {
  String get displayLabel {
    switch (this) {
      case BrowserShellBackend.chromiumEmbedded:
        return 'Chromium (embedded)';
      case BrowserShellBackend.microsoftEdgeWebView2:
        return 'Microsoft Edge (WebView2)';
      case BrowserShellBackend.torEmbeddedSocks:
        return 'Tor (embedded SOCKS)';
    }
  }

  bool get prefersEdgeWebView2OnWindows =>
      this == BrowserShellBackend.microsoftEdgeWebView2;
}

/// User-editable new-tab shortcuts ? intentionally empty until the user adds sites.
class StarterShortcut {
  final String id;
  String title;
  String url;
  int iconCodePoint;

  StarterShortcut({
    required this.id,
    required this.title,
    required this.url,
    int? iconCodePoint,
  }) : iconCodePoint = iconCodePoint ?? Icons.public.codePoint;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'icon': iconCodePoint,
      };

  factory StarterShortcut.fromJson(Map<String, dynamic> json) {
    final fallback = Icons.public.codePoint;
    return StarterShortcut(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      iconCodePoint: (json['icon'] as num?)?.toInt() ?? fallback,
    );
  }
}
