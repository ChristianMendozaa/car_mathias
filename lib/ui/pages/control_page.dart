import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bluetooth/bluetooth_controller.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/joystick_widget.dart';

class CustomAssignment {
  final String label;
  final String charValue;

  const CustomAssignment({
    required this.label,
    required this.charValue,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'char': charValue,
      };

  static CustomAssignment fromJson(Map<String, dynamic> json) {
    return CustomAssignment(
      label: json['label'] as String? ?? '',
      charValue: json['char'] as String? ?? '',
    );
  }
}

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

  // --------- Asignaciones personalizadas ---------
  static const String _kPrefsKeyAssignments = 'custom_assignments';
  final Set<String> _reservedChars = {'F', 'B', 'L', 'R', 'S'};
  List<CustomAssignment> _customAssignments = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKeyAssignments);
    if (raw == null || raw.isEmpty) {
      setState(() {
        _customAssignments = [];
      });
      return;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final parsed = decoded
          .map((e) => CustomAssignment.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _customAssignments = parsed;
      });
    } catch (_) {
      await prefs.remove(_kPrefsKeyAssignments);
      setState(() {
        _customAssignments = [];
      });
    }
  }

  Future<void> _saveAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_customAssignments.map((e) => e.toJson()).toList());
    await prefs.setString(_kPrefsKeyAssignments, raw);
  }

  bool _charIsDuplicate(String ch, {int? exceptIndex}) {
    if (_reservedChars.contains(ch)) return true;
    for (int i = 0; i < _customAssignments.length; i++) {
      if (exceptIndex != null && i == exceptIndex) continue;
      if (_customAssignments[i].charValue == ch) return true;
    }
    return false;
  }

  Future<void> _showAddOrEditDialog(
      {CustomAssignment? existing, int? index}) async {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(text: existing?.label ?? '');
    final charController =
        TextEditingController(text: existing?.charValue ?? '');

    final result = await showDialog<CustomAssignment>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title:
              Text(existing == null ? 'Nueva asignación' : 'Editar asignación'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta',
                    hintText: 'Ej: Luces',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'La etiqueta es obligatoria';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: charController,
                  decoration: const InputDecoration(
                    labelText: 'Carácter a enviar',
                    hintText: 'Un solo carácter (ASCII)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 1,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Ingresa un carácter';
                    if (value.runes.length != 1) return 'Debe ser 1 carácter';
                    if (_charIsDuplicate(value, exceptIndex: index)) {
                      return 'Ese carácter ya está asignado';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(
                    CustomAssignment(
                      label: labelController.text.trim(),
                      charValue: charController.text.trim(),
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    setState(() {
      if (existing != null && index != null) {
        _customAssignments[index] = result;
      } else {
        _customAssignments.add(result);
      }
    });
    await _saveAssignments();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null
            ? 'Asignación agregada'
            : 'Asignación actualizada'),
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar asignación'),
        content: Text('¿Eliminar "${_customAssignments[index].label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _customAssignments.removeAt(index);
    });
    await _saveAssignments();
  }

  Future<void> _resetAssignments() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer asignaciones'),
        content: const Text(
          'Se eliminarán todas las asignaciones nuevas y se conservarán los controles por defecto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKeyAssignments);
    setState(() {
      _customAssignments = [];
    });
  }

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
                    onPressed: connected ? _bt.disconnect : _openDevicePicker,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'reset') {
                        _resetAssignments();
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'reset',
                        child: Text('Restablecer asignaciones'),
                      ),
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                child: Padding(
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
                      const SizedBox(height: 8),
                      // ---------- Asignaciones personalizadas ----------
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Asignaciones personalizadas',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (_customAssignments.isNotEmpty)
                                  Text(
                                    '${_customAssignments.length}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _customAssignments.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No hay asignaciones. Toca + para agregar.',
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : Scrollbar(
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      child: ListView.separated(
                                        itemCount: _customAssignments.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 6),
                                        itemBuilder: (ctx, index) {
                                          final item =
                                              _customAssignments[index];
                                          return Card(
                                            child: ListTile(
                                              title: Text(item.label),
                                              subtitle: Text(
                                                  'Carácter: ${item.charValue}'),
                                              onTap: () => _bt
                                                  .sendCommand(item.charValue),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Editar',
                                                    icon:
                                                        const Icon(Icons.edit),
                                                    onPressed: () =>
                                                        _showAddOrEditDialog(
                                                      existing: item,
                                                      index: index,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Eliminar',
                                                    icon: const Icon(
                                                        Icons.delete_outline),
                                                    onPressed: () =>
                                                        _confirmDelete(index),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showAddOrEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
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
