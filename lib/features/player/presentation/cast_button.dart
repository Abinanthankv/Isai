import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../data/cast_controller.dart';

/// Cast icon button shown in the Now Playing header.
///
/// Tapping it opens the device picker sheet. The connected state (and the
/// resulting cast transport routing / queue load) is handled by the
/// [CastPlaybackController] and the [MyAudioHandler] bridge.
class CastButton extends StatelessWidget {
  const CastButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cast = CastPlaybackController.instance;
    if (!cast.isSupported) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: cast.isConnected,
      builder: (context, connected, _) {
        return IconButton(
          icon: Icon(
            connected ? Icons.cast_connected : Icons.cast,
            color: connected ? Colors.blueAccent : Colors.white70,
          ),
          onPressed: () => showCastDevicePicker(context),
        );
      },
    );
  }
}

Future<void> showCastDevicePicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _CastDevicePickerSheet(),
  );
}

class _CastDevicePickerSheet extends StatefulWidget {
  const _CastDevicePickerSheet();

  @override
  State<_CastDevicePickerSheet> createState() => _CastDevicePickerSheetState();
}

class _CastDevicePickerSheetState extends State<_CastDevicePickerSheet> {
  final cast = CastPlaybackController.instance;
  bool _connecting = false;
  String? _connectingDevice;

  @override
  void initState() {
    super.initState();
    cast.startDiscovery().catchError((_) {});
  }

  @override
  void dispose() {
    cast.stopDiscovery().catchError((_) {});
    super.dispose();
  }

  Future<void> _connect(GoogleCastDevice device) async {
    setState(() {
      _connecting = true;
      _connectingDevice = device.friendlyName;
    });
    var ok = false;
    try {
      ok = await cast.connect(device);
    } catch (e) {
      debugPrint('[Cast] connect error: $e');
    }
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _connectingDevice = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Casting to ${device.friendlyName}'
          : 'Could not connect to ${device.friendlyName}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cast to device',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    controller: scrollController,
                    shrinkWrap: true,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: cast.isConnected,
                        builder: (context, connected, _) {
                          final device = cast.connectedDevice;
                          if (!connected || device == null) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.cast_connected,
                                    color: Colors.blueAccent),
                                title: Text(
                                  device.friendlyName,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: const Text('Connected',
                                    style: TextStyle(color: Colors.white54)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white70),
                                  onPressed: () {
                                    cast.disconnect().catchError((_) {});
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                              const Divider(color: Colors.white12),
                            ],
                          );
                        },
                      ),
                      StreamBuilder<List<GoogleCastDevice>>(
                        stream: cast.devicesStream,
                        builder: (context, snapshot) {
                          final devices = snapshot.data ?? cast.devices;
                          if (devices.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('Looking for devices…',
                                    style: TextStyle(color: Colors.white54)),
                              ),
                            );
                          }
                          return Column(
                            children: devices.map((d) {
                              final isConnecting = _connecting &&
                                  _connectingDevice == d.friendlyName;
                              return ListTile(
                                leading: const Icon(Icons.tv, color: Colors.white70),
                                title: Text(d.friendlyName,
                                    style: const TextStyle(color: Colors.white)),
                                subtitle: d.modelName != null
                                    ? Text(d.modelName!,
                                        style: const TextStyle(
                                            color: Colors.white54))
                                    : null,
                                trailing: isConnecting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : null,
                                onTap: _connecting ? null : () => _connect(d),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
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
