/// Device-independent types shared by every [HeadbandSource].
library;

/// One EEG sample of the four BrainBit-family electrodes, in volts.
class EegSample {
  const EegSample(this.o1, this.o2, this.t3, this.t4);

  final double o1;
  final double o2;
  final double t3;
  final double t4;
}

enum Electrode { o1, o2, t3, t4 }

enum ContactQuality { good, fair, poor }

/// Resistance thresholds from design D4; tuned against real Mindo data.
const double goodContactMaxOhms = 500e3;
const double fairContactMaxOhms = 2e6;

/// Maps a measured electrode resistance to a [ContactQuality].
///
/// The SDK reports infinity (and sometimes NaN) until skin contact is made,
/// both of which are poor.
ContactQuality contactQualityFromOhms(double ohms) {
  if (ohms.isNaN || ohms.isInfinite || ohms < 0) return ContactQuality.poor;
  if (ohms < goodContactMaxOhms) return ContactQuality.good;
  if (ohms < fairContactMaxOhms) return ContactQuality.fair;
  return ContactQuality.poor;
}

/// Per-electrode contact quality, measured outside a session.
class ContactReport {
  const ContactReport(this.byElectrode);

  ContactReport.fromOhms({
    required double o1,
    required double o2,
    required double t3,
    required double t4,
  }) : byElectrode = {
         Electrode.o1: contactQualityFromOhms(o1),
         Electrode.o2: contactQualityFromOhms(o2),
         Electrode.t3: contactQualityFromOhms(t3),
         Electrode.t4: contactQualityFromOhms(t4),
       };

  final Map<Electrode, ContactQuality> byElectrode;

  ContactQuality operator [](Electrode e) =>
      byElectrode[e] ?? ContactQuality.poor;

  /// True when no electrode is poor (the calibration gate).
  bool get allAtLeastFair =>
      Electrode.values.every((e) => this[e] != ContactQuality.poor);

  Iterable<Electrode> get poorElectrodes =>
      Electrode.values.where((e) => this[e] == ContactQuality.poor);
}

enum HeadbandConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// The BrainBit SDK device families this app supports.
enum HeadbandFamily {
  /// Mindo, reported by the SDK as `SensorLEHeadband` (11).
  headband,

  /// Original BrainBit (`SensorLEBrainBit`, 3).
  brainBit,

  /// BrainBit 2 (`SensorLEBrainBit2`, 18).
  brainBit2,

  /// The in-app simulator.
  simulated,
}

/// A headband found by a scan, and what is remembered for quick reconnect.
class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.serialNumber,
    required this.address,
    required this.family,
    this.model = 0,
  });

  final String name;
  final String serialNumber;
  final String address;
  final HeadbandFamily family;
  final int model;

  Map<String, Object> toJson() => {
    'name': name,
    'serialNumber': serialNumber,
    'address': address,
    'family': family.name,
    'model': model,
  };

  static DeviceInfo? fromJson(Map<String, Object?> json) {
    final family = HeadbandFamily.values
        .where((f) => f.name == json['family'])
        .firstOrNull;
    if (family == null) return null;
    return DeviceInfo(
      name: json['name'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      address: json['address'] as String? ?? '',
      family: family,
      model: json['model'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo &&
      other.address == address &&
      other.serialNumber == serialNumber &&
      other.family == family;

  @override
  int get hashCode => Object.hash(address, serialNumber, family);
}

/// Why a scan could not run, with guidance for the user.
enum BluetoothProblem { poweredOff, permissionDenied, unavailable }

class BluetoothUnavailableException implements Exception {
  const BluetoothUnavailableException(this.problem, [this.detail = '']);

  final BluetoothProblem problem;
  final String detail;

  String get guidance => switch (problem) {
    BluetoothProblem.poweredOff =>
      'Bluetooth is turned off. Turn it on in Control Center or '
          'System Settings › Bluetooth, then scan again.',
    BluetoothProblem.permissionDenied =>
      'Focused Mind needs Bluetooth access to find your headband. '
          'Allow it in System Settings › Privacy & Security › Bluetooth, '
          'then scan again.',
    BluetoothProblem.unavailable =>
      'Bluetooth is not available right now. Check that it is on and that '
          'Focused Mind is allowed to use it in System Settings › Privacy & '
          'Security › Bluetooth.',
  };

  @override
  String toString() => 'BluetoothUnavailableException($problem, $detail)';
}

/// Low-battery warning level from the headband-connection spec.
const int lowBatteryPercent = 15;
