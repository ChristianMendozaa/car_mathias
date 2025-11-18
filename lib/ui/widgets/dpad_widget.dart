import 'package:flutter/material.dart';

class DPadWidget extends StatelessWidget {
  final void Function(String cmd) onCommand;

  const DPadWidget({super.key, required this.onCommand});

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;

    Widget buildButton({
      required double size,
      required IconData icon,
      required String cmd,
    }) {
      return GestureDetector(
        onTapDown: (_) => onCommand(cmd),
        onTapUp: (_) => onCommand('S'),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // We need 3 buttons vertically with 2 spacings, and 3 horizontally with 2 spacings
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 200.0;
        final sizeByHeight = (maxH - 2 * spacing) / 3.0;
        final sizeByWidth = (maxW - 2 * spacing) / 3.0;
        double size = sizeByHeight < sizeByWidth ? sizeByHeight : sizeByWidth;
        // Clamp to a reasonable minimum so it's still tappable
        if (size < 36) size = 36;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildButton(size: size, icon: Icons.keyboard_arrow_up, cmd: 'F'),
            const SizedBox(height: spacing),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildButton(size: size, icon: Icons.keyboard_arrow_left, cmd: 'L'),
                const SizedBox(width: spacing),
                buildButton(size: size, icon: Icons.stop, cmd: 'S'),
                const SizedBox(width: spacing),
                buildButton(size: size, icon: Icons.keyboard_arrow_right, cmd: 'R'),
              ],
            ),
            const SizedBox(height: spacing),
            buildButton(size: size, icon: Icons.keyboard_arrow_down, cmd: 'B'),
          ],
        );
      },
    );
  }
}
