// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class SuccessOverlay extends StatefulWidget {
  const SuccessOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<SuccessOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
      child: Center(
        child: const Icon(
          Icons.check_circle_rounded,
          color: DSColors.success,
          size: 120,
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
      ),
    );
  }
}
