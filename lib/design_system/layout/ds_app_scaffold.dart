// DOCS: docs/development-standards.md
// DOCS: docs/design-system.md

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/backdrop/backdrop.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';

/// Scaffold for **post-login** list / detail / settings pages.
///
/// Always uses [DsBackdrop.shell] (same as main tabs).
/// Change shell look in [DsBrandBackdropConfig.shell] only.
///
/// Do **not** use for: login, splash, permissions, terms, initial-sync, camera.
///
/// Tab roots only need `backgroundColor: transparent` (shell is in
/// ScaffoldWithNavBar).
class DsAppScaffold extends StatelessWidget {
  const DsAppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.endDrawer,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.showShellBackdrop = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool? resizeToAvoidBottomInset;
  final bool primary;
  final bool showShellBackdrop;

  @override
  Widget build(BuildContext context) {
    final layered = showShellBackdrop
        ? Stack(
            fit: StackFit.expand,
            children: [
              const DsBrandBackdrop(variant: DsBackdrop.shell),
              body,
            ],
          )
        : body;

    return Scaffold(
      backgroundColor: DSColors.transparent,
      appBar: appBar,
      body: layered,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      drawer: drawer,
      endDrawer: endDrawer,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
    );
  }
}
