// DOCS: docs/development-standards.md
// DOCS: docs/features/auth.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/auth/widgets/auth_illustration.dart';

/// Shared shell for unauthenticated auth screens.
///
/// Login-style shell. Backdrop defaults to [DsBackdrop.auth].
/// Gates/splash should use [DsBackdrop.gate] (or [DSGateShell]).
class AuthShell extends ConsumerWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.loading = false,
    this.showThemeToggle = true,
    this.maxContentWidth = 400,
    this.backdrop = DsBackdrop.auth,
    this.backdropConfig,
  });

  final Widget child;
  final bool loading;
  final bool showThemeToggle;
  final double maxContentWidth;

  /// Scenic variant. Ignored when [backdropConfig] is set.
  final DsBackdrop backdrop;

  /// Full layer override — rare one-offs only.
  final DsBrandBackdropConfig? backdropConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DsBrandBackdrop(
              variant: backdropConfig == null ? backdrop : null,
              config: backdropConfig,
            ),

            if (showThemeToggle)
              Positioned(
                top: topInset + DSSpacing.sm,
                right: DSSpacing.sm,
                child: const _AuthThemeToggle()
                    .animate()
                    .fadeIn(duration: DSAnimations.dNormal, delay: 350.ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      duration: DSAnimations.dNormal,
                      delay: 350.ms,
                      curve: Curves.easeOutBack,
                    ),
              ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    DSSpacing.lg,
                    DSSpacing.md,
                    DSSpacing.lg,
                    DSSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: child,
                  ),
                ),
              ),
            ),

            if (loading)
              ColoredBox(
                color: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
                child: const Center(child: CircularProgressIndicator()),
              ).animate().fadeIn(duration: DSAnimations.dFast),
          ],
        ),
      ),
    );
  }
}

/// Glass form surface — delegates to [DSGlassCard] (shared design system).
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DSGlassCard(
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.lg,
        DSSpacing.lg,
        DSSpacing.lg,
        DSSpacing.md,
      ),
      child: child,
    );
  }
}

/// Icon chip for reset / change password.
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({
    super.key,
    required this.icon,
    this.size = 68,
    this.iconSize = DSIconSize.xl,
    this.color,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? (isDark ? DSColors.primaryDark : DSColors.primary);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? DSColors.cardElevatedDark.withValues(alpha: 0.92)
            : DSColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(DSStyles.radius2XL),
        border: Border.all(
          color: accent.withValues(alpha: DSStyles.alphaSubtle),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: accent),
    );
  }
}

/// Header with logo/icon motion (bounce + optional float loop).
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.title,
    this.showLogo = false,
    this.logoAssetPath,
    this.logoSize = 88,
    this.leadingIcon,
    this.iconColor,
    this.logoPulse = true,
    this.logoFloat = true,
  });

  final String? title;
  final bool showLogo;
  final String? logoAssetPath;
  final double logoSize;
  final IconData? leadingIcon;
  final Color? iconColor;

  /// Continuous scale/glow on [AuthLogoMark]. Off for quieter screens.
  final bool logoPulse;

  /// Gentle vertical float after entry.
  final bool logoFloat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget mark;
    if (showLogo) {
      mark = AuthLogoMark(
        size: logoSize,
        assetPath: logoAssetPath ?? AppAssets.fsiIcon,
        pulse: logoPulse,
      );
    } else if (leadingIcon != null) {
      mark = AuthIconBadge(icon: leadingIcon!, color: iconColor);
    } else {
      mark = const SizedBox.shrink();
    }

    // Entry: scale-bounce (DS hero) then optional soft continuous float.
    mark = mark
        .animate()
        .fadeIn(duration: DSAnimations.dNormal)
        .scale(
          begin: const Offset(0.72, 0.72),
          end: const Offset(1, 1),
          duration: DSAnimations.dHero,
          curve: Curves.easeOutBack,
        );

    if (!reduceMotion && logoFloat && (showLogo || leadingIcon != null)) {
      mark = mark
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: 0,
            end: -6,
            duration: DSAnimations.dHeroX2,
            curve: Curves.easeInOut,
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: mark),
        if (title != null && title!.isNotEmpty) ...[
          DSSpacing.hMd,
          Text(
                title!,
                textAlign: TextAlign.center,
                style: DSTypography.heading().copyWith(
                  fontSize: DSTypography.sizeXl,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: DSTypography.lsSlightlyTight,
                ),
              )
              .animate()
              .fadeIn(delay: 180.ms, duration: DSAnimations.dNormal)
              .slideY(
                begin: 0.18,
                end: 0,
                delay: 180.ms,
                duration: DSAnimations.dNormal,
                curve: Curves.easeOutCubic,
              ),
        ],
      ],
    );
  }
}

/// Primary CTA with press scale + shimmering brand gradient fill.
class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? DSAnimations.scalePressed : DSAnimations.scaleNormal,
        duration: DSAnimations.dMicro,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : DSStyles.alphaDisabled,
          duration: DSAnimations.dFast,
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: enabled
                  ? DSColors.primaryGradient
                  : LinearGradient(
                      colors: [
                        DSColors.primary.withValues(alpha: 0.45),
                        DSColors.primary.withValues(alpha: 0.45),
                      ],
                    ),
              borderRadius: BorderRadius.circular(DSStyles.radiusXL),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: DSColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: DSTypography.button(color: DSColors.white).copyWith(
                fontSize: DSTypography.sizeMd,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Password strength bars.
class AuthPasswordStrengthMeter extends StatelessWidget {
  const AuthPasswordStrengthMeter({super.key, required this.password});

  final String password;

  int get _score {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final score = _score;
    final color = switch (score) {
      0 || 1 => DSColors.error,
      2 => DSColors.warning,
      3 => DSColors.pending,
      _ => DSColors.success,
    };

    return Padding(
      padding: const EdgeInsets.only(top: DSSpacing.sm),
      child: Row(
        children: List.generate(4, (i) {
          final active = i < score;
          return Expanded(
            child: AnimatedContainer(
              duration: DSAnimations.dFast,
              curve: Curves.easeOut,
              height: 3,
              margin: EdgeInsets.only(right: i < 3 ? DSSpacing.xs : 0),
              decoration: BoxDecoration(
                color: active ? color : DSColors.neutral.withValues(alpha: 0.2),
                borderRadius: DSStyles.fullRadius,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AuthThemeToggle extends ConsumerWidget {
  const _AuthThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: DSColors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref
              .read(authProvider.notifier)
              .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
        },
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: DSAnimations.dFast,
          padding: const EdgeInsets.all(DSSpacing.sm),
          decoration: BoxDecoration(
            color: isDark
                ? DSColors.white.withValues(alpha: 0.12)
                : DSColors.white.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? DSColors.white.withValues(alpha: 0.10)
                  : DSColors.separatorLight,
            ),
            boxShadow: [
              BoxShadow(
                color: DSColors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: DSAnimations.dFast,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              size: DSIconSize.md,
              color: isDark ? DSColors.white : DSColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
