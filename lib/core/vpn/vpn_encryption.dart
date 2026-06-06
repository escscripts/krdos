import 'dart:convert';
import 'dart:typed_data';
import 'vpn_hop.dart';

/// Encryption utilities for multi-hop VPN
/// Simulates AES-256-GCM (Galois/Counter Mode) encryption
class VpnEncryption {
  // Mock implementation - in production, use actual crypto libraries
  static const String _encryptionVersion = '1.0';

  /// Generate a random 256-bit encryption key (32 bytes)
  static String generateEncryptionKey() {
    final random = List<int>.generate(32, (_) => DateTime.now().millisecond % 256);
    return base64Encode(random);
  }

  /// Generate a random 128-bit IV (16 bytes)
  static String generateIV() {
    final random = List<int>.generate(16, (_) => DateTime.now().millisecond % 256);
    return base64Encode(random);
  }

  /// Encrypt data for a single hop
  /// In production: actual AES-256-GCM encryption
  static String encryptHop(String plaintext, String encryptionKey) {
    try {
      final iv = generateIV();
  // Mock encryption: base64 encode with metadata
      final encrypted = base64Encode(utf8.encode(plaintext));
      final payload = '$_encryptionVersion|$iv|$encrypted';
      return base64Encode(utf8.encode(payload));
    } catch (e) {
      throw Exception('Hop encryption failed: $e');
    }
  }

  /// Decrypt data from a single hop
  static String decryptHop(String encrypted, String encryptionKey) {
    try {
      final payload = utf8.decode(base64Decode(encrypted));
      final parts = payload.split('|');
      if (parts.length != 3) throw Exception('Invalid encrypted payload');

      final version = parts[0];
      final iv = parts[1];
      final encryptedData = parts[2];

      if (version != _encryptionVersion) {
        throw Exception('Unsupported encryption version: $version');
      }

  // Mock decryption
      final plaintext = utf8.decode(base64Decode(encryptedData));
      return plaintext;
    } catch (e) {
      throw Exception('Hop decryption failed: $e');
    }
  }

  /// Encrypt data through entire VPN chain (multiple hops)
  /// Each hop adds a layer of encryption
  static String encryptChain(String plaintext, List<VpnHop> hops) {
    if (hops.isEmpty) return plaintext;

    try {
      var data = plaintext;
  // Encrypt from exit hop back to entry hop
  // This ensures entry hop can't see final destination
      for (int i = hops.length - 1; i >= 0; i--) {
        data = encryptHop(data, hops[i].encryptionKey);
      }
      return data;
    } catch (e) {
      throw Exception('Chain encryption failed: $e');
    }
  }

  /// Decrypt data from entire VPN chain (multiple hops)
  /// Each hop removes a layer of encryption
  static String decryptChain(String encrypted, List<VpnHop> hops) {
    if (hops.isEmpty) return encrypted;

    try {
      var data = encrypted;
  // Decrypt from entry hop to exit hop
      for (int i = 0; i < hops.length; i++) {
        data = decryptHop(data, hops[i].encryptionKey);
      }
      return data;
    } catch (e) {
      throw Exception('Chain decryption failed: $e');
    }
  }

  /// Create a packet wrapper with metadata for routing
  static Map<String, dynamic> createPacketWrapper(
    String encryptedData,
    VpnChain chain,
    int hopIndex,
  ) {
    return {
      'version': '1.0',
      'chain_id': chain.id,
      'hop_index': hopIndex,
      'total_hops': chain.hops.length,
      'encrypted_data': encryptedData,
      'timestamp': DateTime.now().toIso8601String(),
      'checksum': _calculateChecksum(encryptedData),
    };
  }

  /// Verify packet integrity
  static bool verifyPacketChecksum(Map<String, dynamic> packet) {
    try {
      final expectedChecksum = _calculateChecksum(packet['encrypted_data']);
      return packet['checksum'] == expectedChecksum;
    } catch (e) {
      return false;
    }
  }

  /// Simple checksum calculation
  static String _calculateChecksum(String data) {
    int checksum = 0;
    for (int i = 0; i < data.length; i++) {
      checksum += data.codeUnitAt(i);
      checksum = (checksum << 1) ^ (checksum >> 31);
    }
    return checksum.toRadixString(16);
  }
}

/// Extension on VpnChain for encryption convenience
extension VpnChainEncryption on VpnChain {
  String encryptData(String plaintext) =>
      VpnEncryption.encryptChain(plaintext, hops);

  String decryptData(String encrypted) =>
      VpnEncryption.decryptChain(encrypted, hops);

  Map<String, dynamic> wrapPacket(String encrypted, int hopIndex) =>
      VpnEncryption.createPacketWrapper(encrypted, this, hopIndex);

  bool verifyPacket(Map<String, dynamic> packet) =>
      VpnEncryption.verifyPacketChecksum(packet);
}