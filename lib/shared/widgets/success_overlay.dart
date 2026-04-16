// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:lottie/lottie.dart';

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
      color: Colors.black45,
      child: Center(child: Lottie.asset(AppAssets.animSuccess, repeat: false)),
    );
  }
}
