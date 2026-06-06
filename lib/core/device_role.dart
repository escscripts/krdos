import 'package:flutter/widgets.dart';
import 'os_state.dart';

export 'os_state.dart' show DeviceType, UserRole;

class DeviceRole {
  static DeviceType getDeviceType(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return DeviceType.mobile;
    if (w < 900) return DeviceType.tablet;
    return DeviceType.laptop;
  }
}
