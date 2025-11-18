import 'package:flutter/material.dart';

class DPadWidget extends StatelessWidget {
  final void Function(String cmd) onCommand;

  const DPadWidget({super.key, required this.onCommand});

  @override
  Widget build(BuildContext context) {
    final double size = 64;

    Widget buildButton({
      required IconData icon,
      required String cmd,
    }) {
      return GestureDetector(
        onTapDown: (_) => onCommand(cmd), // Enviar comando mientras se toca
        onTapUp: (_) => onCommand('S'),   // Soltar -> Stop
        onTapCancel: () => onCommand('S'),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Arriba
        buildButton(icon: Icons.keyboard_arrow_up, cmd: 'F'),
        const SizedBox(height: 8),

        // Izquierda - Stop - Derecha
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildButton(icon: Icons.keyboard_arrow_left, cmd: 'L'),
            const SizedBox(width: 8),
            buildButton(icon: Icons.stop, cmd: 'S'),
            const SizedBox(width: 8),
            buildButton(icon: Icons.keyboard_arrow_right, cmd: 'R'),
          ],
        ),
        const SizedBox(height: 8),

        // Abajo
        buildButton(icon: Icons.keyboard_arrow_down, cmd: 'B'),
      ],
    );
  }
}
