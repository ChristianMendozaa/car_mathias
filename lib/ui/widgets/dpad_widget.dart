import 'package:flutter/material.dart';

class DPadWidget extends StatefulWidget {
  final void Function(String cmd) onCommand;

  const DPadWidget({super.key, required this.onCommand});

  @override
  State<DPadWidget> createState() => _DPadWidgetState();
}

class _DPadWidgetState extends State<DPadWidget> {
  // pointerId -> dirección ('F','B','L','R')
  final Map<int, String> _pointerToDir = {};
  String _lastCmd = 'S';

  void _sendIfChanged(String cmd) {
    if (_lastCmd != cmd) {
      _lastCmd = cmd;
      widget.onCommand(cmd);
    }
  }

  String _computeCommand() {
    final active = _pointerToDir.values.toSet();

    final bool f = active.contains('F');
    final bool b = active.contains('B');
    final bool l = active.contains('L');
    final bool r = active.contains('R');

    // Diagonales
    if (f && !b && l && !r) return 'Q'; // Adelante + Izquierda
    if (f && !b && r && !l) return 'E'; // Adelante + Derecha
    if (b && !f && l && !r) return 'Z'; // Atrás + Izquierda
    if (b && !f && r && !l) return 'C'; // Atrás + Derecha

    // Simples
    if (f && !b && !l && !r) return 'F';
    if (b && !f && !l && !r) return 'B';
    if (l && !r && !f && !b) return 'L';
    if (r && !l && !f && !b) return 'R';

    // Si hay cosas contradictorias (F+B o L+R mezclados raro) -> Stop
    if (active.isEmpty) return 'S';
    return 'S';
  }

  void _updateAndSend() {
    final cmd = _computeCommand();
    _sendIfChanged(cmd);
  }

  Widget _buildDirButton({
    required double size,
    required IconData icon,
    required String dirChar,
  }) {
    return Listener(
      onPointerDown: (event) {
        _pointerToDir[event.pointer] = dirChar;
        _updateAndSend();
      },
      onPointerUp: (event) {
        _pointerToDir.remove(event.pointer);
        _updateAndSend();
      },
      onPointerCancel: (event) {
        _pointerToDir.remove(event.pointer);
        _updateAndSend();
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildStopButton(double size) {
    return GestureDetector(
      onTapDown: (_) {
        _pointerToDir.clear();
        _sendIfChanged('S');
      },
      onTapUp: (_) {
        _pointerToDir.clear();
        _sendIfChanged('S');
      },
      onTapCancel: () {
        _pointerToDir.clear();
        _sendIfChanged('S');
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.stop, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        final maxH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 200.0;

        // 3 filas/columnas (arriba, centro, abajo) con 2 espacios
        final sizeByHeight = (maxH - 2 * spacing) / 3.0;
        final sizeByWidth = (maxW - 2 * spacing) / 3.0;
        double size = sizeByHeight < sizeByWidth ? sizeByHeight : sizeByWidth;
        if (size < 36) size = 36;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila superior:    [   F   ]
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: size + spacing), // espacio a la izquierda
                _buildDirButton(
                  size: size,
                  icon: Icons.keyboard_arrow_up,
                  dirChar: 'F',
                ),
                SizedBox(width: size + spacing), // espacio a la derecha
              ],
            ),
            const SizedBox(height: spacing),
            // Fila central:  [ L ] [ S ] [ R ]
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDirButton(
                  size: size,
                  icon: Icons.keyboard_arrow_left,
                  dirChar: 'L',
                ),
                const SizedBox(width: spacing),
                _buildStopButton(size),
                const SizedBox(width: spacing),
                _buildDirButton(
                  size: size,
                  icon: Icons.keyboard_arrow_right,
                  dirChar: 'R',
                ),
              ],
            ),
            const SizedBox(height: spacing),
            // Fila inferior:    [   B   ]
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: size + spacing),
                _buildDirButton(
                  size: size,
                  icon: Icons.keyboard_arrow_down,
                  dirChar: 'B',
                ),
                SizedBox(width: size + spacing),
              ],
            ),
          ],
        );
      },
    );
  }
}
