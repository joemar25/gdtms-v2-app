import 'package:flutter/material.dart';

/// Wraps [child] and overlays a semi-transparent loading spinner when
/// [isLoading] is true. Used on screens that perform async operations
/// (e.g. profile save, payout submit) to block interaction during the request.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
