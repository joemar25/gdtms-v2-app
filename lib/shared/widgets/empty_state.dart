// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: DSIconSize.heroMd * 2.0,
              child:
                  Icon(
                        Icons.inbox_rounded,
                        size: DSIconSize.heroMd * 1.5,
                        color: Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.5),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(
                        begin: 0.1,
                        duration: 500.ms,
                        curve: Curves.easeOut,
                      ),
            ),
            DSSpacing.hMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
