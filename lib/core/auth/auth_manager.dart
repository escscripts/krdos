import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'user_account.dart';

class AuthManager extends ChangeNotifier {
  List<UserAccount> _accounts = [];
  UserAccount? _currentUser;
  RegisteredDevice? _currentDevice;

  List<UserAccount> get accounts => _accounts;
  UserAccount? get currentUser => _currentUser;
  RegisteredDevice? get currentDevice => _currentDevice;
  bool get isLoggedIn => _currentUser != null;

  AuthManager() {
    _init();
  }

  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> _init() async {
    await _loadAccounts();
    await _initializeDevice();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getStringList('user_accounts') ?? [];
      _accounts = accountsJson.map((json) => UserAccount.fromJson(jsonDecode(json))).toList();
      
      final currentUserId = prefs.getString('current_user_id');
      if (currentUserId != null && _accounts.isNotEmpty) {
        try {
          _currentUser = _accounts.firstWhere((a) => a.id == currentUserId);
        } catch (e) {
          _currentUser = null;
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading accounts: $e');
    }
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = _accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList('user_accounts', accountsJson);
  }

  Future<void> _initializeDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceJson = prefs.getString('current_device');
    
    if (deviceJson != null) {
      _currentDevice = RegisteredDevice.fromJson(jsonDecode(deviceJson));
    } else {
      _currentDevice = RegisteredDevice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        deviceName: 'My Computer',
        deviceType: DeviceType.desktop,
        osVersion: 'KrdOS 1.0',
        registeredAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isTrusted: true,
      );
      await prefs.setString('current_device', jsonEncode(_currentDevice!.toJson()));
    }
    notifyListeners();
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<bool> createAccount({
    required String username,
    required String fullName,
    required String email,
    required String password,
    String? profileImagePath,
    UserAccountType accountType = UserAccountType.standard,
    String passwordType = 'custom',
  }) async {
    if (_accounts.any((a) => a.username == username || a.email == email)) {
      return false;
    }

    final account = UserAccount(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      fullName: fullName,
      email: email,
      passwordHash: _hashPassword(password),
      profileImagePath: profileImagePath,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      accountType: accountType,
      devices: _currentDevice != null ? [_currentDevice!] : [],
      passwordType: passwordType,
    );

    _accounts.add(account);
    await _saveAccounts();
    notifyListeners();
    return true;
  }

  Future<bool> login(String username, String password) async {
    final account = _accounts.firstWhere(
      (a) => a.username == username,
      orElse: () => throw Exception('Invalid credentials'),
    );

    final pw = password.trim();
    if (pw.isEmpty && account.allowPasswordlessLogin) {
      return await _finalizeLogin(account);
    }

    if (account.passwordHash != _hashPassword(password)) {
      throw Exception('Invalid credentials');
    }

    return await _finalizeLogin(account);
  }

  Future<bool> _finalizeLogin(UserAccount account) async {
    _currentUser = account.copyWith(lastLogin: DateTime.now());

    if (_currentDevice != null && !_currentUser!.devices.any((d) => d.id == _currentDevice!.id)) {
      final updatedDevices = [..._currentUser!.devices, _currentDevice!];
      _currentUser = _currentUser!.copyWith(devices: updatedDevices);
    }

    final index = _accounts.indexWhere((a) => a.id == account.id);
    _accounts[index] = _currentUser!;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', _currentUser!.id);
    await _saveAccounts();
    notifyListeners();
    return true;
  }

  Future<bool> loginWithPin(String username, String pin) async {
    final account = _accounts.firstWhere(
      (a) => a.username == username && a.pin == pin,
      orElse: () => throw Exception('Invalid PIN'),
    );
    return await _finalizeLogin(account);
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    notifyListeners();
  }

  Future<void> updateAccount(UserAccount updatedAccount) async {
    final index = _accounts.indexWhere((a) => a.id == updatedAccount.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      if (_currentUser?.id == updatedAccount.id) {
        _currentUser = updatedAccount;
      }
      await _saveAccounts();
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String accountId) async {
    _accounts.removeWhere((a) => a.id == accountId);
    if (_currentUser?.id == accountId) {
      _currentUser = null;
    }
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(pin: pin);
      await updateAccount(_currentUser!);
    }
  }

  Future<void> enableBiometric(bool enabled) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(biometricEnabled: enabled);
      await updateAccount(_currentUser!);
    }
  }

  /// Returns `null` on success, or a short error message for the UI.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return updateSignInSecret(
      currentPassword: currentPassword,
      nextSecret: newPassword,
      nextPasswordType: 'custom',
    );
  }

  /// Validates [nextSecret] for [nextPasswordType] (`custom`, `pin4`, `pin6`).
  Future<String?> updateSignInSecret({
    required String currentPassword,
    required String nextSecret,
    required String nextPasswordType,
  }) async {
    final user = _currentUser;
    if (user == null) return 'You must be signed in to change credentials.';

    if (user.passwordHash != _hashPassword(currentPassword)) {
      return 'Current password is incorrect.';
    }

    final t = nextPasswordType.trim();
    final s = nextSecret.trim();

    switch (t) {
      case 'pin4':
        if (s.length != 4 || !_allDigits(s)) {
          return 'PIN must be exactly 4 digits.';
        }
        break;
      case 'pin6':
        if (s.length != 6 || !_allDigits(s)) {
          return 'PIN must be exactly 6 digits.';
        }
        break;
      case 'custom':
        if (s.length < 8) {
          return 'Passphrase must be at least 8 characters.';
        }
        if (!RegExp(r'[A-Z]').hasMatch(s)) {
          return 'Passphrase needs at least one uppercase letter.';
        }
        if (!RegExp(r'[a-z]').hasMatch(s)) {
          return 'Passphrase needs at least one lowercase letter.';
        }
        if (!RegExp(r'[0-9]').hasMatch(s)) {
          return 'Passphrase needs at least one number.';
        }
        break;
      default:
        return 'Unsupported sign?in method.';
    }

    if (_hashPassword(s) == user.passwordHash && user.passwordType == t) {
      return 'Nothing to change.';
    }

    final updated =
        user.copyWith(passwordHash: _hashPassword(s), passwordType: t);
    await updateAccount(updated);
    return null;
  }

  bool _allDigits(String s) => RegExp(r'^\d+$').hasMatch(s);

  /// Persist opt?in for empty password unlock; requires confirming [currentPassword] when enabling.
  Future<String?> setAllowPasswordlessLogin({
    required bool allow,
    required String currentPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return 'You must be signed in.';

    if (allow && user.passwordHash != _hashPassword(currentPassword)) {
      return 'Current password is incorrect.';
    }

    await updateAccount(user.copyWith(allowPasswordlessLogin: allow));
    return null;
  }

  Future<void> registerDevice(RegisteredDevice device) async {
    if (_currentUser != null) {
      final devices = [..._currentUser!.devices, device];
      _currentUser = _currentUser!.copyWith(devices: devices);
      await updateAccount(_currentUser!);
    }
  }

  Future<void> removeDevice(String deviceId) async {
    if (_currentUser != null) {
      final devices = _currentUser!.devices.where((d) => d.id != deviceId).toList();
      _currentUser = _currentUser!.copyWith(devices: devices);
      await updateAccount(_currentUser!);
    }
  }

  Future<void> clearAllAccounts() async {
    _accounts.clear();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_accounts');
    await prefs.remove('current_user_id');
    notifyListeners();
  }

  /// Clears all [SharedPreferences], re-seeds a fresh [RegisteredDevice], and
  /// clears in-memory accounts (same outcome as a clean install of app data).
  Future<void> factoryResetOs() async {
    _accounts.clear();
    _currentUser = null;
    _currentDevice = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _initializeDevice();
    notifyListeners();
  }
}
