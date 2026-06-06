import 'package:flutter/material.dart';

import 'device_model.dart';

/// Describes a dockable controller surface exposed to operators (future hardware / daemons attach here).
class ControlSurfaceDef {
  const ControlSurfaceDef({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

/// Roadmap toolkit families bound to Meshtastic / multi-radio / GNSS ecosystems (UI only until daemons attach).
enum MeshToolkitFamily {
  multiProtocolMeshtastic,
  uavAvionics,
  groundVehicleRc,
  gimbalImaging,
  gnssWaypoint,
  spectrumLab,
}

/// Profiles map device classes to surfaces you will wire to your daemon + drivers later.
abstract final class MeshHardwareProfiles {
  static const List<ControlSurfaceDef> _uav = [
    ControlSurfaceDef(
      id: 'flight_core',
      label: 'Flight core',
      description: 'Arming, RTL, altitude & failsafe hooks',
      icon: Icons.flight,
    ),
    ControlSurfaceDef(
      id: 'stick_inputs',
      label: 'Stick & rates',
      description: 'Rates, expo, yaw authority (RC bridge)',
      icon: Icons.games,
    ),
    ControlSurfaceDef(
      id: 'waypoints',
      label: 'Waypoints',
      description: 'Mission planner upload / orbit',
      icon: Icons.polyline,
    ),
    ControlSurfaceDef(
      id: 'gimbal',
      label: 'Gimbal / aim',
      description: 'Slave camera line-of-sight to mesh host',
      icon: Icons.screen_rotation_alt,
    ),
    ControlSurfaceDef(
      id: 'telemetry_osd',
      label: 'Telemetry / OSD',
      description: 'MAVLink?style HUD fields over mesh',
      icon: Icons.analytics_outlined,
    ),
    ControlSurfaceDef(
      id: 'fence_geofence',
      label: 'Geofence',
      description: 'Soft borders & corridor enforcement',
      icon: Icons.hexagon_outlined,
    ),
    ControlSurfaceDef(
      id: 'battery_power',
      label: 'Power',
      description: 'Cell health, RTL reserve, ESC logs',
      icon: Icons.battery_charging_full,
    ),
    ControlSurfaceDef(
      id: 'failover_rf',
      label: 'RF failover',
      description: 'LoRa ? WiFi handoff thresholds',
      icon: Icons.sync_alt,
    ),
    ControlSurfaceDef(
      id: 'logging_blackbox',
      label: 'Black box',
      description: 'Session capture export to host OS FS',
      icon: Icons.sd_storage,
    ),
    ControlSurfaceDef(
      id: 'perm_matrix',
      label: 'ACL / permissions',
      description: 'Per-operator roles on this UAV',
      icon: Icons.vpn_key_outlined,
    ),
  ];

  static const List<ControlSurfaceDef> _camera = [
    ControlSurfaceDef(
      id: 'stream',
      label: 'Stream preview',
      description: 'WebRTC / raw frame ingest',
      icon: Icons.videocam_outlined,
    ),
    ControlSurfaceDef(
      id: 'recording',
      label: 'Record / ingest',
      description: 'Rolling buffer & offload',
      icon: Icons.fiber_smart_record_outlined,
    ),
    ControlSurfaceDef(
      id: 'exposure_isp',
      label: 'Exposure / ISP',
      description: 'Shutter, gain, WB',
      icon: Icons.tungsten,
    ),
    ControlSurfaceDef(
      id: 'ptz',
      label: 'PTZ servo',
      description: 'Fine pan/tilt + optical zoom rails',
      icon: Icons.open_with,
    ),
    ControlSurfaceDef(
      id: 'encoder',
      label: 'Encoder',
      description: 'Bitrate ladder & FEC over mesh',
      icon: Icons.settings_input_hdmi,
    ),
    ControlSurfaceDef(
      id: 'overlay',
      label: 'Overlays',
      description: 'OSD symbology & callsign watermark',
      icon: Icons.grid_on_outlined,
    ),
    ControlSurfaceDef(
      id: 'ptz_presets',
      label: 'Presets',
      description: 'Recall stored aim points',
      icon: Icons.camera_indoor_outlined,
    ),
    ControlSurfaceDef(
      id: 'storage',
      label: 'Storage',
      description: 'Rolling SD offload plan',
      icon: Icons.folder_open,
    ),
    ControlSurfaceDef(
      id: 'network_priorities',
      label: 'Link QoS',
      description: 'Prioritize telemetry vs imagery',
      icon: Icons.network_ping,
    ),
    ControlSurfaceDef(
      id: 'acl_camera',
      label: 'Operator ACL',
      description: 'Who may arm shutter / slew',
      icon: Icons.verified_user_outlined,
    ),
  ];

  static const List<ControlSurfaceDef> _sensor = [
    ControlSurfaceDef(
      id: 'live_plots',
      label: 'Live plots',
      description: 'Time-series gauges',
      icon: Icons.show_chart,
    ),
    ControlSurfaceDef(
      id: 'calibration_routine',
      label: 'Calibration',
      description: 'Factory / field trim flows',
      icon: Icons.architecture_outlined,
    ),
    ControlSurfaceDef(
      id: 'alert_rules',
      label: 'Threshold rules',
      description: 'Latched alarms to mesh broadcast',
      icon: Icons.notification_important_outlined,
    ),
    ControlSurfaceDef(
      id: 'wake_schedule',
      label: 'Wake schedule',
      description: 'Duty-cycled radios',
      icon: Icons.schedule_outlined,
    ),
    ControlSurfaceDef(
      id: 'relay_peers',
      label: 'Aggregator peers',
      description: 'Forward streams to gateways',
      icon: Icons.hub_outlined,
    ),
    ControlSurfaceDef(
      id: 'field_notes',
      label: 'Field notes',
      description: 'Operator annotations',
      icon: Icons.note_alt_outlined,
    ),
    ControlSurfaceDef(
      id: 'export',
      label: 'Export',
      description: 'CSV / Parquet via host OS',
      icon: Icons.download_outlined,
    ),
    ControlSurfaceDef(
      id: 'diagnostics',
      label: 'Self-test',
      description: 'Loopback & noise floor',
      icon: Icons.build_circle_outlined,
    ),
    ControlSurfaceDef(
      id: 'mesh_priority',
      label: 'Mesh priority',
      description: 'Packet class & CoS',
      icon: Icons.low_priority,
    ),
    ControlSurfaceDef(
      id: 'acl_sensor',
      label: 'ACL',
      description: 'Read vs configure roles',
      icon: Icons.lock_outline,
    ),
  ];

  static const List<ControlSurfaceDef> _gateway = [
    ControlSurfaceDef(
      id: 'route_table',
      label: 'Route fabric',
      description: 'Next-hop table & cost',
      icon: Icons.account_tree_outlined,
    ),
    ControlSurfaceDef(
      id: 'noise_keys',
      label: 'Noise keys',
      description: 'Session ratchet status',
      icon: Icons.key_outlined,
    ),
    ControlSurfaceDef(
      id: 'whitelist',
      label: 'Whitelist',
      description: 'Peer admission control',
      icon: Icons.verified_outlined,
    ),
    ControlSurfaceDef(
      id: 'qos_shaping',
      label: 'QoS shaping',
      description: 'Per-class bandwidth caps',
      icon: Icons.speed,
    ),
    ControlSurfaceDef(
      id: 'bridge_wan',
      label: 'WAN bridge',
      description: 'Optional uplink (disabled in pure mesh)',
      icon: Icons.cloud_off_outlined,
    ),
    ControlSurfaceDef(
      id: 'syslog',
      label: 'Syslog export',
      description: 'Forward to host logging',
      icon: Icons.terminal,
    ),
    ControlSurfaceDef(
      id: 'watchdog',
      label: 'Watchdog',
      description: 'Restart daemons on fault',
      icon: Icons.security_update_good_outlined,
    ),
    ControlSurfaceDef(
      id: 'tuning_antenna',
      label: 'RF chain',
      description: 'AGC / preamp sense',
      icon: Icons.settings_input_antenna,
    ),
    ControlSurfaceDef(
      id: 'backup_restore',
      label: 'Backup',
      description: 'Config snapshot to VFS',
      icon: Icons.save_alt_outlined,
    ),
    ControlSurfaceDef(
      id: 'acl_gateway',
      label: 'Root ACL',
      description: 'Break-glass operator list',
      icon: Icons.admin_panel_settings_outlined,
    ),
  ];

  static const List<ControlSurfaceDef> _generic = [
    ControlSurfaceDef(
      id: 'identity',
      label: 'Identity',
      description: 'Device attestation & callsign',
      icon: Icons.badge_outlined,
    ),
    ControlSurfaceDef(
      id: 'link_budget',
      label: 'Link budget',
      description: 'SNR, RSSI, hop count',
      icon: Icons.cell_tower,
    ),
    ControlSurfaceDef(
      id: 'firmware',
      label: 'Firmware slot',
      description: 'Staged OTA via mesh',
      icon: Icons.system_update_alt,
    ),
    ControlSurfaceDef(
      id: 'script_hooks',
      label: 'Script hooks',
      description: 'Host OS automation triggers',
      icon: Icons.code,
    ),
    ControlSurfaceDef(
      id: 'perm_matrix',
      label: 'Permissions',
      description: 'Role matrix for this node',
      icon: Icons.grid_on,
    ),
  ];

  static List<ControlSurfaceDef> surfacesForDeviceType(DeviceType type) {
    switch (type) {
      case DeviceType.drone:
        return _uav;
      case DeviceType.camera:
        return _camera;
      case DeviceType.sensor:
        return _sensor;
      case DeviceType.gateway:
        return _gateway;
      case DeviceType.relay:
      case DeviceType.mobile:
      case DeviceType.unknown:
        return [..._generic, ..._gateway.take(4)];
    }
  }

  static List<(MeshToolkitFamily, String, IconData)> toolkitRoadmap() => const [
        (MeshToolkitFamily.multiProtocolMeshtastic, 'Meshtastic / LoRa mesh', Icons.hub_outlined),
        (MeshToolkitFamily.uavAvionics, 'UAV stacks (ArduPilot / PX4?class)', Icons.flight),
        (MeshToolkitFamily.groundVehicleRc, 'RC surface & scale trucks', Icons.directions_car),
        (MeshToolkitFamily.gimbalImaging, 'Gimbal & cinema rigs', Icons.movie_filter_outlined),
        (MeshToolkitFamily.gnssWaypoint, 'GNSS / APRS waypointing', Icons.explore_outlined),
        (MeshToolkitFamily.spectrumLab, 'Lab-grade spectrum / sniffers', Icons.graphic_eq),
      ];
}
