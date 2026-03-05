import 'package:flutter/material.dart';

import '../router/router_keys.dart';

enum SnackbarType { success, error, info }

void showAppSnackbar(
  BuildContext? context,
  String message, {
  SnackbarType type = SnackbarType.info,
}) {
  final color = switch (type) {
    SnackbarType.success => Colors.green,
    SnackbarType.error => Colors.red,
    SnackbarType.info => Colors.blue,
  };

  final messenger = context != null
      ? ScaffoldMessenger.maybeOf(context)
      : appScaffoldMessengerKey.currentState;

  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
