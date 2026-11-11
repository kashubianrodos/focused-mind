import 'models.dart';

/// What the headband is currently streaming. The SDK cannot stream
/// resistance and EEG signal at the same time (design D4).
enum StreamMode { idle, resistance, signal }

/// Low-level access to one kind of headband: the real BrainBit SDK or the
/// simulator. Timeouts, reconnection and state live in [HeadbandConnection],
/// so implementations stay thin.
abstract interface class HeadbandSource {
  /// Starts scanning and emits the full list of devices found so far each
  /// time it changes. Throws [BluetoothUnavailableException] (as a stream
  /// error) when Bluetooth cannot be used.
  Stream<List<DeviceInfo>> scan();

  Future<void> stopScan();

  /// Connects to [device]; completes when connected, throws on failure.
  /// May be called again after the link was lost, to reconnect.
  Future<void> connect(DeviceInfo device);

  Future<void> disconnect();

  Future<void> setMode(StreamMode mode);

  /// `true` when the device is back in range, `false` when the link drops.
  Stream<bool> get linkChanges;

  /// Battery level in percent.
  Stream<int> get battery;

  /// Per-electrode contact quality while in [StreamMode.resistance].
  Stream<ContactReport> get resistance;

  /// EEG samples at [samplingRate] while in [StreamMode.signal], in batches.
  Stream<List<EegSample>> get signal;

  int get samplingRate;

  Future<void> dispose();
}
