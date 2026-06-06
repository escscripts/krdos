import 'dart:convert';
import 'package:crypto/crypto.dart';

class MeshEncryption {
  // Generate encryption key (32 bytes = 256-bit)
  static String generateEncryptionKey() {
    final random = DateTime.now().microsecondsSinceEpoch;
    final key = base64Encode(List<int>.generate(32, (i) => (random + i) % 256));
    return key;
  }

  // Simulate Noise Protocol-like encryption
  // In production, use actual Noise or modern cryptography libraries
  static String encryptPacket(String payload, String encryptionKey) {
    try {
      final payloadBytes = utf8.encode(payload);
      final keyBytes = base64Decode(encryptionKey);

  // Simple XOR cipher with key expansion (for simulation)
      final encrypted = <int>[];
      for (int i = 0; i < payloadBytes.length; i++) {
        final keyByte = keyBytes[i % keyBytes.length];
        encrypted.add(payloadBytes[i] ^ keyByte);
      }

  // Add checksum
      final checksum = sha256.convert(encrypted).toString().substring(0, 8);
      final combined = encrypted + utf8.encode(checksum);

      return base64Encode(combined);
    } catch (e) {
      return payload; // Fallback: return unencrypted
    }
  }

  // Decrypt packet
  static String decryptPacket(String encryptedPayload, String encryptionKey) {
    try {
      final combined = base64Decode(encryptedPayload);
      final encrypted = combined.sublist(0, combined.length - 8);
      final storedChecksum = utf8.decode(
        combined.sublist(combined.length - 8),
        allowMalformed: true,
      );

  // Verify checksum
      final calculatedChecksum = sha256
          .convert(encrypted)
          .toString()
          .substring(0, 8);
      if (storedChecksum != calculatedChecksum) {
        throw Exception('Checksum mismatch: packet integrity failed');
      }

      final keyBytes = base64Decode(encryptionKey);
      final decrypted = <int>[];
      for (int i = 0; i < encrypted.length; i++) {
        final keyByte = keyBytes[i % keyBytes.length];
        decrypted.add(encrypted[i] ^ keyByte);
      }

      return utf8.decode(decrypted);
    } catch (e) {
      return encryptedPayload; // Fallback
    }
  }

  // Generate device pairing key (for trusted relationships)
  static String generatePairingKey(String deviceId1, String deviceId2) {
    final combined = '$deviceId1:$deviceId2';
    return sha256.convert(utf8.encode(combined)).toString().substring(0, 32);
  }

  // Derive session key from master key
  static String deriveSessionKey(String masterKey, String sessionId) {
    final input = '$masterKey:$sessionId:${DateTime.now().day}';
    return base64Encode(
      List<int>.generate(
        32,
        (i) =>
            (sha256.convert(utf8.encode(input)).toString().codeUnitAt(i)) % 256,
      ),
    );
  }

  // Sign packet with device key
  static String signPacket(String packetData, String deviceKey) {
    final combined = '$packetData:$deviceKey';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  // Verify packet signature
  static bool verifyPacketSignature(
    String packetData,
    String deviceKey,
    String signature,
  ) {
    final expected = signPacket(packetData, deviceKey);
    return expected == signature;
  }
}