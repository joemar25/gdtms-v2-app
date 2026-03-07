import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';

// Set to [false] when this feature is ready to use.
const bool _isUnderConstruction = true;

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeaderBar(title: 'Sync'),
      body: _isUnderConstruction
          ? const _UnderConstructionBody()
          : const _SyncBody(),
    );
  }
}

// ── Under Construction ────────────────────────────────────────────────────────

class _UnderConstructionBody extends StatelessWidget {
  const _UnderConstructionBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/anim/under-construction.json',
              width: 220,
              height: 220,
              repeat: true,
            ),
            const SizedBox(height: 20),
            Text(
              'Under Development',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The Sync feature (offline-to-online syncing) is currently under development and will be available in a future update.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Future Sync Body ──────────────────────────────────────────────────────────
// Replace the contents here when the sync feature is implemented.

class _SyncBody extends StatelessWidget {
  const _SyncBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Sync feature coming soon.'),
    );
  }
}
