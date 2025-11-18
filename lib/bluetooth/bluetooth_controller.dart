import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothController extends ChangeNotifier {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  BluetoothConnection? _connection;
  BluetoothDevice? connectedDevice;
  bool isConnecting = false;
  bool isDisconnecting = false;

  bool get isConnected => _connection != null && _connection!.isConnected;

  List<BluetoothDevice> bondedDevices = [];

  BluetoothController() {
    _init();
  }

  Future<void> _init() async {
    // Asegurarse que el BT esté encendido
    final isEnabled = await _bluetooth.isEnabled ?? false;
    if (!isEnabled) {
      await _bluetooth.requestEnable();
    }

    // Cargar dispositivos emparejados
    bondedDevices = await _bluetooth.getBondedDevices();
    notifyListeners();
  }

  Future<void> refreshBondedDevices() async {
    bondedDevices = await _bluetooth.getBondedDevices();
    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected) {
      await disconnect();
    }

    isConnecting = true;
    notifyListeners();

    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      _connection = connection;
      connectedDevice = device;

      isConnecting = false;
      notifyListeners();

      // Escuchar el stream de datos (por si quieres leer algo luego)
      _connection!.input?.listen((Uint8List data) {
        final text = utf8.decode(data);
        debugPrint('Recibido desde HC-05: $text');
      }).onDone(() {
        debugPrint('Conexión finalizada por el remoto.');
        _connection = null;
        connectedDevice = null;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error al conectar: $e');
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_connection != null) {
      isDisconnecting = true;
      notifyListeners();

      await _connection!.close();
      _connection = null;
      connectedDevice = null;
      isDisconnecting = false;
      notifyListeners();
    }
  }

  Future<void> sendCommand(String command) async {
    if (!isConnected) {
      debugPrint('No hay conexión para enviar comando');
      return;
    }

    try {
      _connection!.output.add(utf8.encode(command));
      await _connection!.output.allSent;
      debugPrint('Comando enviado: $command');
    } catch (e) {
      debugPrint('Error al enviar comando: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
