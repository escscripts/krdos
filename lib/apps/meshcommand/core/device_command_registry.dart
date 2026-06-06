import '../models/device_model.dart';

class DeviceCommandRegistry {
  static final Map<DeviceType, List<DeviceCommand>> commandsByType = {
    DeviceType.drone: [
      DeviceCommand(
        id: 'takeoff',
        name: 'Take Off',
        description: 'Launch the drone and reach cruise altitude',
        category: 'Flight',
        parameters: ['altitude'],
        expectedResponse: 'Takeoff initiated',
        requiresConfirmation: true,
      ),
      DeviceCommand(
        id: 'land',
        name: 'Land',
        description: 'Return to launch point and land safely',
        category: 'Flight',
        parameters: [],
        expectedResponse: 'Landing sequence started',
        requiresConfirmation: true,
      ),
      DeviceCommand(
        id: 'hover',
        name: 'Hover',
        description: 'Hold current position in the air',
        category: 'Flight',
        parameters: ['duration'],
        expectedResponse: 'Hovering',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'record',
        name: 'Record Video',
        description: 'Start/stop video recording',
        category: 'Camera',
        parameters: ['action'],
        expectedResponse: 'Recording status updated',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'photo',
        name: 'Take Photo',
        description: 'Capture a still image',
        category: 'Camera',
        parameters: [],
        expectedResponse: 'Photo captured',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'battery_status',
        name: 'Battery Status',
        description: 'Get current battery percentage and estimate',
        category: 'System',
        parameters: [],
        expectedResponse: 'Battery: XX%',
        requiresConfirmation: false,
      ),
    ],
    DeviceType.camera: [
      DeviceCommand(
        id: 'record',
        name: 'Record',
        description: 'Start/stop video recording',
        category: 'Recording',
        parameters: ['action'],
        expectedResponse: 'Recording status changed',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'photo',
        name: 'Capture Photo',
        description: 'Take a still image',
        category: 'Recording',
        parameters: [],
        expectedResponse: 'Photo saved',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'pan_tilt',
        name: 'Pan/Tilt',
        description: 'Move camera gimbal',
        category: 'Control',
        parameters: ['pan', 'tilt'],
        expectedResponse: 'Gimbal moved',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'zoom',
        name: 'Zoom',
        description: 'Adjust lens zoom',
        category: 'Control',
        parameters: ['level'],
        expectedResponse: 'Zoom adjusted',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'night_mode',
        name: 'Toggle Night Mode',
        description: 'Enable/disable low-light enhancement',
        category: 'Settings',
        parameters: ['enabled'],
        expectedResponse: 'Night mode toggled',
        requiresConfirmation: false,
      ),
    ],
    DeviceType.sensor: [
      DeviceCommand(
        id: 'read_temp',
        name: 'Read Temperature',
        description: 'Get current temperature reading',
        category: 'Sensors',
        parameters: [],
        expectedResponse: 'Temp: XX.X°C',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'read_humidity',
        name: 'Read Humidity',
        description: 'Get current humidity level',
        category: 'Sensors',
        parameters: [],
        expectedResponse: 'Humidity: XX%',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'read_pressure',
        name: 'Read Pressure',
        description: 'Get atmospheric pressure',
        category: 'Sensors',
        parameters: [],
        expectedResponse: 'Pressure: XX.X hPa',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'calibrate',
        name: 'Calibrate Sensors',
        description: 'Run sensor calibration routine',
        category: 'Maintenance',
        parameters: [],
        expectedResponse: 'Calibration complete',
        requiresConfirmation: true,
      ),
      DeviceCommand(
        id: 'reset',
        name: 'Reset Sensor',
        description: 'Reset sensor to factory defaults',
        category: 'Maintenance',
        parameters: [],
        expectedResponse: 'Reset complete',
        requiresConfirmation: true,
      ),
    ],
    DeviceType.gateway: [
      DeviceCommand(
        id: 'status',
        name: 'Gateway Status',
        description: 'Get gateway health and statistics',
        category: 'System',
        parameters: [],
        expectedResponse: 'Status report',
        requiresConfirmation: false,
      ),
      DeviceCommand(
        id: 'restart',
        name: 'Restart Gateway',
        description: 'Restart the gateway device',
        category: 'System',
        parameters: [],
        expectedResponse: 'Restarting...',
        requiresConfirmation: true,
      ),
    ],
  };

  static List<DeviceCommand> getCommandsForDevice(MeshDevice device) {
    return commandsByType[device.type] ?? [];
  }

  static DeviceCommand? getCommand(DeviceType type, String commandId) {
    final commands = commandsByType[type] ?? [];
    try {
      return commands.firstWhere((c) => c.id == commandId);
    } catch (e) {
      return null;
    }
  }

  static Map<String, List<DeviceCommand>> getCommandsByCategory(
    DeviceType type,
  ) {
    final commands = commandsByType[type] ?? [];
    final grouped = <String, List<DeviceCommand>>{};
    for (final cmd in commands) {
      if (!grouped.containsKey(cmd.category)) {
        grouped[cmd.category] = [];
      }
      grouped[cmd.category]!.add(cmd);
    }
    return grouped;
  }
}
