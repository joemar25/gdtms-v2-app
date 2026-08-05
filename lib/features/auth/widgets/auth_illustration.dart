// DOCS: docs/development-standards.md
// DOCS: docs/features/auth.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fsi_courier_app/design_system/design_system.dart';

/// Loads a brand illustration (SVG or raster) with a compact icon fallback.
class AuthIllustration extends StatefulWidget {
  const AuthIllustration({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackColor,
    this.semanticLabel,
    this.borderRadius,
    this.showSurface = false,
    this.padding,
    this.compactFallback = false,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? fallbackColor;
  final String? semanticLabel;
  final BorderRadius? borderRadius;
  final bool showSurface;
  final EdgeInsetsGeometry? padding;
  final bool compactFallback;

  bool get _isSvg => assetPath.toLowerCase().endsWith('.svg');

  @override
  State<AuthIllustration> createState() => _AuthIllustrationState();
}

class _AuthIllustrationState extends State<AuthIllustration> {
  late Future<ByteData?> _assetFuture;

  @override
  void initState() {
    super.initState();
    _assetFuture = _load();
  }

  @override
  void didUpdateWidget(covariant AuthIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _assetFuture = _load();
    }
  }

  Future<ByteData?> _load() async {
    try {
      return await rootBundle.load(widget.assetPath);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        widget.fallbackColor ??
        (isDark ? DSColors.primaryDark : DSColors.primary);

    final fallback = _Fallback(
      icon: widget.fallbackIcon,
      color: accent,
      width: widget.compactFallback ? DSIconSize.heroSm : widget.width,
      height: widget.compactFallback ? DSIconSize.heroSm : widget.height,
    );

    Widget content = FutureBuilder<ByteData?>(
      future: _assetFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.compactFallback ? DSIconSize.heroSm : widget.width,
            height: widget.compactFallback ? DSIconSize.heroSm : widget.height,
            child: Center(
              child: SizedBox(
                width: DSIconSize.md,
                height: DSIconSize.md,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent.withValues(alpha: DSStyles.alphaMuted),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) return fallback;

        if (widget._isSvg) {
          try {
            final svg = String.fromCharCodes(data.buffer.asUint8List());
            return SvgPicture.string(
              svg,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              semanticsLabel: widget.semanticLabel,
              placeholderBuilder: (_) => fallback,
            );
          } catch (_) {
            return fallback;
          }
        }

        return Image.asset(
          widget.assetPath,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          semanticLabel: widget.semanticLabel,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );

    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }
    if (widget.showSurface) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
              : accent.withValues(alpha: DSStyles.alphaSoft),
          borderRadius: widget.borderRadius ?? DSStyles.sheetRadius,
        ),
        child: content,
      );
    } else if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    return content;
  }
}

/// Brand mark with optional pulsing glow ring — typically [AppAssets.fsiIcon].
class AuthLogoMark extends StatelessWidget {
  const AuthLogoMark({
    super.key,
    this.size = 88,
    this.assetPath,
    this.fallbackIcon = Icons.local_shipping_rounded,
    this.pulse = true,
    this.showGlowRing = true,
  });

  final double size;
  final String? assetPath;
  final IconData fallbackIcon;

  /// Continuous breathe animation. Prefer `false` on quieter screens (splash).
  final bool pulse;

  /// Soft radial wash behind the tile.
  final bool showGlowRing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final path = assetPath;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final tile = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? DSColors.cardElevatedDark : DSColors.white,
        borderRadius: BorderRadius.circular(DSStyles.radius2XL),
        border: Border.all(
          color: isDark
              ? DSColors.white.withValues(alpha: 0.10)
              : DSColors.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: DSColors.primary.withValues(alpha: isDark ? 0.35 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: DSColors.gold.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? Icon(fallbackIcon, size: size * 0.42, color: DSColors.primary)
          : AuthIllustration(
              assetPath: path,
              fallbackIcon: fallbackIcon,
              width: size - DSSpacing.md * 2,
              height: size - DSSpacing.md * 2,
              fit: BoxFit.contain,
              fallbackColor: DSColors.primary,
              semanticLabel: 'App logo',
            ),
    );

    final mark = showGlowRing
        ? Container(
            width: size + 18,
            height: size + 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  DSColors.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                  DSColors.primary.withValues(alpha: 0),
                ],
              ),
            ),
            child: tile,
          )
        : tile;

    if (reduceMotion || !pulse) return mark;

    return mark
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.04, 1.04),
          duration: DSAnimations.dHeroX2,
          curve: Curves.easeInOut,
        )
        .custom(
          duration: DSAnimations.dHeroX2,
          builder: (context, value, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: DSColors.primary.withValues(
                      alpha: (isDark ? 0.22 : 0.12) + value * 0.10,
                    ),
                    blurRadius: 28 + value * 16,
                    spreadRadius: value * 2,
                  ),
                ],
                shape: BoxShape.circle,
              ),
              child: child,
            );
          },
        );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.icon,
    required this.color,
    this.width,
    this.height,
  });

  final IconData icon;
  final Color color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final w = width ?? DSIconSize.heroSm;
    final h = height ?? DSIconSize.heroSm;
    final iconSize = (w < h ? w : h) * 0.48;
    return SizedBox(
      width: w,
      height: h,
      child: Center(
        child: Icon(icon, size: iconSize.clamp(16, 40), color: color),
      ),
    );
  }
}
