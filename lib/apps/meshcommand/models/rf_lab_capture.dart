import 'dart:convert';

/// Lab trace imported from YOUR hardware dongle via host OS tooling (logical payload only ? no transmitter here).
class RfLabCapture {
  RfLabCapture({
    required this.id,
    required this.title,
    required this.capturedAt,
    required this.hexPayload,
    this.modulationHint = '',
    this.frequencyHint = '',
    this.notes = '',
    this.sourceTag = '',
  });

  final String id;
  final String title;
  final DateTime capturedAt;
  /// Hex digits + optional whitespace; sanitized on save via [normalizedHex].
  final String hexPayload;
  final String modulationHint;
  final String frequencyHint;
  final String notes;
  final String sourceTag;

  /// Uppercase contiguous hex pairs for clipboard / sandbox packets.
  String get normalizedHex {
    final only = hexPayload.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (only.length.isOdd && only.length > 1) {
      return only.substring(0, only.length - 1).toUpperCase();
    }
    return only.toUpperCase();
  }

  Map<String, dynamic> toExportMap() => {
        'schema': 'meshcommand.rf_lab_capture.v1',
        'id': id,
        'title': title,
        'capturedAt': capturedAt.toIso8601String(),
        'hex': normalizedHex,
        'modulationHint': modulationHint,
        'frequencyHint': frequencyHint,
        'notes': notes,
        'sourceTag': sourceTag,
      };

  String toExportJsonPretty() =>
      const JsonEncoder.withIndent('  ').convert(toExportMap());

  factory RfLabCapture.placeholder({
    required String title,
    String hexPayload = 'DE AD BE EF ',
  }) {
    return RfLabCapture(
      id: 'cap-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      capturedAt: DateTime.now(),
      hexPayload: hexPayload,
      sourceTag: 'Host import',
      notes: '',
    );
  }
}
