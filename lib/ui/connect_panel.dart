import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../headband/headband_connection.dart';
import '../headband/models.dart';

/// Scanning, connecting and the connection status (headband-connection spec).
class ConnectPanel extends ConsumerStatefulWidget {
  const ConnectPanel({super.key});

  @override
  ConsumerState<ConnectPanel> createState() => _ConnectPanelState();
}

class _ConnectPanelState extends ConsumerState<ConnectPanel> {
  StreamSubscription<List<DeviceInfo>>? _scan;
  List<DeviceInfo> _found = const [];
  bool _scanning = false;
  bool _scanned = false;
  String? _error;

  AppServices get _services => ref.read(servicesProvider);

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  void _startScan() {
    _scan?.cancel();
    setState(() {
      _found = const [];
      _scanning = true;
      _scanned = false;
      _error = null;
    });
    _scan = _services.connection.scan().listen(
      (devices) => setState(() => _found = devices),
      onError: (Object e) => setState(() {
        _error = e is BluetoothUnavailableException
            ? e.guidance
            : 'Scanning failed: $e';
      }),
      onDone: () => setState(() {
        _scanning = false;
        _scanned = true;
      }),
    );
  }

  Future<void> _connect(DeviceInfo device) async {
    await _scan?.cancel();
    setState(() {
      _scanning = false;
      _error = null;
    });
    try {
      await _services.connection.connect(device);
      await _services.settingsRepository.saveLastDevice(device);
    } on ConnectTimeoutException {
      if (mounted) {
        setState(
          () => _error =
              'Could not connect to ${device.name}. Check that it is on and '
              'nearby, then retry.',
        );
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Could not connect: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final connection = services.connection;
    final last = services.settingsRepository.loadLastDevice();
    final lastUsable =
        last != null &&
        (last.family != HeadbandFamily.simulated || services.simulator != null);

    return ValueListenableBuilder(
      valueListenable: connection.state,
      builder: (context, state, _) {
        if (state != HeadbandConnectionState.disconnected) {
          return _ConnectedHeader(connection: connection);
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect your headband',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (lastUsable)
                      FilledButton.icon(
                        key: const ValueKey('quick-connect'),
                        onPressed: () => _connect(last),
                        icon: const Icon(Icons.bluetooth_connected),
                        label: Text('Connect to ${last.name}'),
                      ),
                    OutlinedButton.icon(
                      key: const ValueKey('scan'),
                      onPressed: _scanning ? null : _startScan,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: Text(_scanning ? 'Scanning…' : 'Scan'),
                    ),
                  ],
                ),
                if (_scanning) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                for (final d in _found)
                  ListTile(
                    key: ValueKey('device-${d.serialNumber}'),
                    leading: const Icon(Icons.headset),
                    title: Text(d.name),
                    subtitle: Text('Serial ${d.serialNumber}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _connect(d),
                  ),
                if (_scanned && _found.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'No headband found. Make sure it is switched on and '
                      'charged, keep it close to your Mac, then scan again.',
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectedHeader extends StatelessWidget {
  const _ConnectedHeader({required this.connection});

  final HeadbandConnection connection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([connection.state, connection.battery]),
      builder: (context, _) {
        final state = connection.state.value;
        final battery = connection.battery.value;
        final label = switch (state) {
          HeadbandConnectionState.connected => 'Connected',
          HeadbandConnectionState.connecting => 'Connecting…',
          HeadbandConnectionState.reconnecting => 'Reconnecting…',
          HeadbandConnectionState.disconnected => 'Disconnected',
        };
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              key: const ValueKey('connection-state'),
              avatar: Icon(
                state == HeadbandConnectionState.connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_searching,
                size: 18,
              ),
              label: Text('${connection.device?.name ?? 'Headband'}: $label'),
            ),
            if (battery != null)
              Chip(
                key: const ValueKey('battery'),
                avatar: Icon(
                  connection.isLowBattery
                      ? Icons.battery_alert
                      : Icons.battery_std,
                  size: 18,
                  color: connection.isLowBattery ? scheme.error : null,
                ),
                label: Text(
                  connection.isLowBattery
                      ? 'Battery low: $battery%'
                      : 'Battery $battery%',
                ),
              ),
            if (state == HeadbandConnectionState.connected)
              TextButton(
                onPressed: connection.disconnect,
                child: const Text('Disconnect'),
              ),
          ],
        );
      },
    );
  }
}
