import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class JoystickWidget extends StatefulWidget {
  final void Function(String cmd) onCommand;

  const JoystickWidget({super.key, required this.onCommand});

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _offset = Offset.zero;
  String _lastCommand = 'S';
  Timer? _repeatTimer;

  final GlobalKey _paintKey = GlobalKey();

  void _sendOnce(String cmd) {
    if (_lastCommand != cmd) {
      _lastCommand = cmd;
      widget.onCommand(cmd);
    }
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _startRepeatingDirection() {
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _computeDirection(_offset);
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
  }

  /// Calcula qué comando mandar según la posición del joystick.
  /// Ahora soporta:
  /// F, B, L, R + diagonales Q, E, Z, C.
  void _computeDirection(Offset clamped) {
    final dx = clamped.dx;
    final dy = clamped.dy;

    const double deadZone = 5.0;
    if (clamped.distance < deadZone) {
      // No mandamos nada, el coche sigue con el último comando
      return;
    }

    final absDx = dx.abs();
    final absDy = dy.abs();

    // Factor para decidir si es “más vertical”, “más horizontal” o diagonal
    const double dominance = 1.7;

    String cmd;

    if (absDy > absDx * dominance) {
      // Casi totalmente vertical → F/B
      cmd = dy < 0 ? 'F' : 'B';
    } else if (absDx > absDy * dominance) {
      // Casi totalmente horizontal → L/R
      cmd = dx < 0 ? 'L' : 'R';
    } else {
      // Zona diagonal → Q/E/Z/C
      if (dy < 0 && dx < 0) {
        cmd = 'Q'; // Adelante + Izquierda
      } else if (dy < 0 && dx > 0) {
        cmd = 'E'; // Adelante + Derecha
      } else if (dy > 0 && dx < 0) {
        cmd = 'Z'; // Atrás + Izquierda
      } else {
        cmd = 'C'; // Atrás + Derecha
      }
    }

    _sendOnce(cmd);
  }

  void _handlePan(globalPos, Size size) {
    final box = _paintKey.currentContext!.findRenderObject() as RenderBox;
    final localPos = box.globalToLocal(globalPos);

    final center = Offset(size.width / 2, size.height / 2);
    final relative = localPos - center;

    final maxRadius = size.width * 0.35;

    Offset clamped = relative;
    if (relative.distance > maxRadius) {
      clamped = Offset.fromDirection(relative.direction, maxRadius);
    }

    setState(() => _offset = clamped);

    _computeDirection(clamped);
  }

  void _handleEnd() {
    _stopRepeating();
    _sendOnce('S');
    setState(() => _offset = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight) * 0.8;

        return Center(
          child: GestureDetector(
            onPanStart: (details) {
              _startRepeatingDirection();
              _handlePan(details.globalPosition, Size(size, size));
            },
            onPanUpdate: (details) {
              _handlePan(details.globalPosition, Size(size, size));
            },
            onPanEnd: (_) => _handleEnd(),
            child: SizedBox(
              key: _paintKey,
              width: size,
              height: size,
              child: CustomPaint(
                painter: _JoystickPainter(_offset),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset offset;

  _JoystickPainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.blueGrey;

    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.withOpacity(0.75);

    // círculo grande
    canvas.drawCircle(center, size.width / 2.5, outerPaint);

    // knob
    final knobCenter = center + offset;
    canvas.drawCircle(knobCenter, size.width / 8, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.offset != offset;
}
