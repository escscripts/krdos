class UserAccount {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String passwordHash;
  final String? profileImagePath;
  final DateTime createdAt;
  final DateTime lastLogin;
  final UserAccountType accountType;
  final Map<String, dynamic> preferences;
  final List<RegisteredDevice> devices;
  final bool biometricEnabled;
  final String? pin;
  final String passwordType;
  /// When true, blank credentials on lock screen authenticate for this account (explicit opt?in).
  final bool allowPasswordlessLogin;

  UserAccount({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    this.profileImagePath,
    required this.createdAt,
    required this.lastLogin,
    this.accountType = UserAccountType.standard,
    Map<String, dynamic>? preferences,
    List<RegisteredDevice>? devices,
    this.biometricEnabled = false,
    this.pin,
    this.passwordType = 'custom',
    this.allowPasswordlessLogin = false,
  })  : preferences = preferences ?? {},
        devices = devices ?? [];

  UserAccount copyWith({
    String? username,
    String? fullName,
    String? email,
    String? passwordHash,
    String? profileImagePath,
    DateTime? lastLogin,
    UserAccountType? accountType,
    Map<String, dynamic>? preferences,
    List<RegisteredDevice>? devices,
    bool? biometricEnabled,
    String? pin,
    String? passwordType,
    bool? allowPasswordlessLogin,
  }) {
    return UserAccount(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      accountType: accountType ?? this.accountType,
      preferences: preferences ?? this.preferences,
      devices: devices ?? this.devices,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pin: pin ?? this.pin,
      passwordType: passwordType ?? this.passwordType,
      allowPasswordlessLogin: allowPasswordlessLogin ?? this.allowPasswordlessLogin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'passwordHash': passwordHash,
        'profileImagePath': profileImagePath,
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin.toIso8601String(),
        'accountType': accountType.name,
        'preferences': preferences,
        'devices': devices.map((d) => d.toJson()).toList(),
        'biometricEnabled': biometricEnabled,
        'pin': pin,
        'passwordType': passwordType,
        'allowPasswordlessLogin': allowPasswordlessLogin,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: json['id'],
        username: json['username'],
        fullName: json['fullName'],
        email: json['email'],
        passwordHash: json['passwordHash'],
        profileImagePath: json['profileImagePath'],
        createdAt: DateTime.parse(json['createdAt']),
        lastLogin: DateTime.parse(json['lastLogin']),
        accountType: UserAccountType.values.firstWhere(
          (e) => e.name == json['accountType'],
          orElse: () => UserAccountType.standard,
        ),
        preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
        devices: (json['devices'] as List?)
                ?.map((d) => RegisteredDevice.fromJson(d))
                .toList() ??
            [],
        biometricEnabled: json['biometricEnabled'] ?? false,
        pin: json['pin'],
        passwordType: json['passwordType'] ?? 'custom',
        allowPasswordlessLogin: json['allowPasswordlessLogin'] == true,
      );
}

enum UserAccountType {
  administrator,
  standard,
  guest,
}

class RegisteredDevice {
  final String id;
  final String deviceName;
  final DeviceType deviceType;
  final String osVersion;
  final DateTime registeredAt;
  final DateTime lastSeen;
  final bool isTrusted;
  final String? deviceFingerprint;

  RegisteredDevice({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.osVersion,
    required this.registeredAt,
    required this.lastSeen,
    this.isTrusted = false,
    this.deviceFingerprint,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceName': deviceName,
        'deviceType': deviceType.name,
        'osVersion': osVersion,
        'registeredAt': registeredAt.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'isTrusted': isTrusted,
        'deviceFingerprint': deviceFingerprint,
      };

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) =>
      RegisteredDevice(
        id: json['id'],
        deviceName: json['deviceName'],
        deviceType: DeviceType.values.firstWhere(
          (e) => e.name == json['deviceType'],
          orElse: () => DeviceType.desktop,
        ),
        osVersion: json['osVersion'],
        registeredAt: DateTime.parse(json['registeredAt']),
        lastSeen: DateTime.parse(json['lastSeen']),
        isTrusted: json['isTrusted'] ?? false,
        deviceFingerprint: json['deviceFingerprint'],
      );
}

enum DeviceType {
  desktop,
  laptop,
  mobile,
  tablet,
}
