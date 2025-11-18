import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../../bluetooth/bluetooth_controller.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/joystick_widget.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final BluetoothController _bt = BluetoothController();
  bool _useJoystick = false;

  BluetoothDevice? _selectedDevice;

  // Estado adicional para la UI
  bool _isConnecting = false;
  bool _showOverlay = false;

  @override
  void dispose() {
    _bt.dispose();
    super.dispose();
  }

  Future<void> _attemptConnection(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _showOverlay = true;
    });

    try {
      await _bt.connectToDevice(device);

      await Future.delayed(const Duration(milliseconds: 300));

      if (_bt.isConnected) {
        setState(() {
          _isConnecting = false;
          _showOverlay = false;
        });
      } else {
        // Falló
        _showConnectionFailedDialog(device);
      }
    } catch (e) {
      _showConnectionFailedDialog(device);
    }
  }

  void _showConnectionFailedDialog(BluetoothDevice device) {
    setState(() {
      _isConnecting = false;
      _showOverlay = false;
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("No se pudo conectar"),
        content: Text(
          "No fue posible conectar con el dispositivo:\n\n"
          "${device.name ?? device.address}\n\n"
          "¿Quieres intentar de nuevo?",
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Intentar de nuevo"),
            onPressed: () {
              Navigator.pop(context);
              _attemptConnection(device);
            },
          ),
        ],
      ),
    );
  }

  void _openDevicePicker() async {
    await _bt.refreshBondedDevices();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return AnimatedBuilder(
          animation: _bt,
          builder: (context, _) {
            final devices = _bt.bondedDevices;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text('Dispositivos emparejados'),
                  subtitle: Text('Selecciona tu HC-05'),
                ),
                if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No hay dispositivos emparejados.\n'
                      'Empareja el HC-05 en ajustes de Bluetooth.',
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final d = devices[index];
                        return ListTile(
                          title: Text(d.name ?? 'Sin nombre'),
                          subtitle: Text(d.address),
                          onTap: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _selectedDevice = d;
                            });
                            _attemptConnection(d);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  void _sendDirection(String cmd) {
    _bt.sendCommand(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _bt,
          builder: (context, _) {
            final connected = _bt.isConnected;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Carro Bluetooth HC-05'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _bt.refreshBondedDevices,
                  ),
                  IconButton(
                    icon: Icon(
                      connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                    ),
                    onPressed:
                        connected ? _bt.disconnect : _openDevicePicker,
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Estado de conexión
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            connected
                                ? 'Conectado a: ${_bt.connectedDevice?.name ?? _bt.connectedDevice?.address}'
                                : 'No conectado',
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _useJoystick,
                          onChanged: (v) {
                            setState(() => _useJoystick = v);
                          },
                        ),
                        Text(_useJoystick ? 'Joystick' : 'Cruzeta'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botón para elegir dispositivo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.bluetooth_searching),
                          label: Text(
                            _selectedDevice != null
                                ? 'Cambiar dispositivo (${_selectedDevice!.name ?? _selectedDevice!.address})'
                                : 'Seleccionar dispositivo',
                          ),
                          onPressed: _openDevicePicker,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Expanded(
                      child: Center(
                        child: _useJoystick
                            ? JoystickWidget(onCommand: _sendDirection)
                            : DPadWidget(onCommand: _sendDirection),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // ---------- Overlay de CARGA ----------
        if (_showOverlay)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    "Conectando...",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
