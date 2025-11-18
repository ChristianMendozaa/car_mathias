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

  void _computeDirection(Offset clamped) {
    final dx = clamped.dx;
    final dy = clamped.dy;

    //🔥 SIN deadzone = jamás manda "S" por error
    if (clamped.distance < 5) {
      // pequeño centro: NO mandamos nada
      return;
    }

    String cmd;
    if (dy.abs() > dx.abs()) {
      cmd = dy < 0 ? 'F' : 'B';
    } else {
      cmd = dx < 0 ? 'L' : 'R';
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

    canvas.drawCircle(center, size.width / 2.5, outerPaint);

    final knobCenter = center + offset;
    canvas.drawCircle(knobCenter, size.width / 8, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.offset != offset;
}
