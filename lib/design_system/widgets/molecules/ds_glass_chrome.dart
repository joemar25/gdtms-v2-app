// DOCS: docs/development-standards.md
// DOCS: docs/styles.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_glass.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_spacing.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';

/// Default **liquid green glass** chrome — header + floating bottom nav.
///
/// iPhone-style stack (order matters — never opaque under blur):
/// 1. [BackdropFilter] — heavy blur of real content/scenery behind chrome
/// 2. White frost film (subtle milk)
/// 3. Translucent brand green tint
/// 4. Specular sheen + hairline light catch
/// 5. Edge rim
///
/// Use [edge] to match placement:
/// - [DSGlassChromeEdge.header] — full-bleed bar + soft bottom fade
/// - [DSGlassChromeEdge.floating] — pill nav + lift shadows
/// - [DSGlassChromeEdge.strip] — integrated sub-header; height follows child
///   when parent height is unbounded (do not clamp to [DSGlass.chromeHeight])
///
/// Set [solidBrand] for **header extensions** (update status strip, failed-
/// delivery filters): opaque [DSColors.primary] / [DSColors.primaryDark] so
/// the strip is the same paint as the continuous app bar — not a second
/// BackdropFilter that samples different scenery and drifts mint/dark.
class DSGlassChrome extends StatelessWidget {
  const DSGlassChrome({
    super.key,
    this.child,
    this.borderRadius,
    this.showBottomBorder = false,
    this.showBorder = true,
    this.boxShadow = true,
    this.edge = DSGlassChromeEdge.floating,
    this.solidBrand = false,
  });

  final Widget? child;
  final BorderRadius? borderRadius;
  final bool showBottomBorder;
  final bool showBorder;
  final bool boxShadow;
  final DSGlassChromeEdge edge;

  /// Opaque brand fill (no blur). Use for continuous header + strip unit.
  final bool solidBrand;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.zero;
    final brand = isDark ? DSColors.primaryDark : DSColors.primary;

    // Solid continuous unit = full primary. Glass chrome = translucent wash.
    final glassTint = solidBrand
        ? brand
        : brand.withValues(
            alpha: isDark ? DSGlass.chromeAlphaDark : DSGlass.chromeAlphaLight,
          );
    final frost = solidBrand
        ? DSColors.transparent
        : DSColors.white.withValues(
            alpha: isDark ? DSGlass.frostAlphaDark : DSGlass.frostAlphaLight,
          );

    // Specular — light catch only. Avoid dark brand wash at bottom (reads as
    // dirty spots under rounded header corners).
    final sheenTop = DSColors.white.withValues(
      alpha: solidBrand ? (isDark ? 0.06 : 0.08) : (isDark ? 0.08 : 0.10),
    );
    final sheenMid = DSColors.white.withValues(
      alpha: solidBrand ? 0.0 : (isDark ? 0.02 : 0.03),
    );
    // Bottom sheen stays light (white), never extra brand/dark band.
    final sheenBottom = DSColors.white.withValues(
      alpha: solidBrand ? 0.0 : (isDark ? 0.03 : 0.04),
    );

    final rimBright = DSColors.white.withValues(alpha: isDark ? 0.22 : 0.32);
    // Soft light rim — not dark edge under the curve.
    final rimSoft = DSColors.white.withValues(alpha: isDark ? 0.14 : 0.22);

    final bool isFloating = edge == DSGlassChromeEdge.floating;
    final bool isHeader = edge == DSGlassChromeEdge.header;
    final bool isStrip = edge == DSGlassChromeEdge.strip;
    // Continuous header→strip: no bottom hairline/dissolve on header, or a
    // seam appears between the two pieces and they stop reading as one unit.
    final bool paintBottomEdge = showBottomBorder && (isHeader || !isStrip);

    final Border? border = showBorder
        ? Border.all(
            color: rimBright,
            width: isFloating ? 1.25 : DSStyles.borderWidth,
          )
        : (paintBottomEdge
              ? Border(
                  bottom: BorderSide(
                    color: rimSoft,
                    width: DSStyles.borderWidth,
                  ),
                )
              : null);

    final List<BoxShadow>? shadows = !boxShadow
        ? null
        : (isHeader || isStrip
              ? DSGlass.headerShadow(context)
              : DSGlass.shadow(context, tone: DSGlassTone.chrome));

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight;
        // Strip under header (status/filter) sizes to child — never force
        // chromeHeight or the status track (80+) + hint overflows (~52 pad area).
        final sizeToChild =
            edge == DSGlassChromeEdge.strip && !constraints.hasBoundedHeight;

        // Decorative layers fill the stack; when sizeToChild they use
        // Positioned.fill so the non-positioned [child] defines height.
        Widget fillLayer(Widget layer) =>
            sizeToChild ? Positioned.fill(child: layer) : layer;

        final hairline = IgnorePointer(
          child: Container(
            height: 1.25,
            margin: EdgeInsets.symmetric(
              horizontal: isFloating ? DSSpacing.md : 0,
            ),
            decoration: BoxDecoration(
              borderRadius: isFloating ? BorderRadius.circular(1) : null,
              gradient: LinearGradient(
                colors: [
                  DSColors.transparent,
                  DSColors.white.withValues(alpha: isDark ? 0.22 : 0.30),
                  DSColors.white.withValues(alpha: isDark ? 0.22 : 0.30),
                  DSColors.transparent,
                ],
                stops: const [0.0, 0.12, 0.88, 1.0],
              ),
            ),
          ),
        );

        final List<Widget> stackChildren = [
          // 1) White frost film — skip on solid brand (would wash primary mint).
          if (!solidBrand)
            fillLayer(DecoratedBox(decoration: BoxDecoration(color: frost))),
          // 2) Brand green — opaque when [solidBrand], translucent glass otherwise.
          fillLayer(DecoratedBox(decoration: BoxDecoration(color: glassTint))),
          // 3) Vertical specular (thickness + light).
          fillLayer(
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    sheenTop,
                    sheenMid,
                    DSColors.transparent,
                    sheenBottom,
                  ],
                  stops: const [0.0, 0.18, 0.50, 1.0],
                ),
              ),
            ),
          ),
          // 4) Diagonal light sweep — glass only (solid brand keeps pure primary).
          if (!solidBrand)
            fillLayer(
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1.0, -1.0),
                    end: const Alignment(0.6, 0.8),
                    colors: [
                      DSColors.white.withValues(alpha: isDark ? 0.05 : 0.06),
                      DSColors.transparent,
                      DSColors.transparent,
                      brand.withValues(alpha: isDark ? 0.10 : 0.08),
                    ],
                    stops: const [0.0, 0.28, 0.70, 1.0],
                  ),
                ),
              ),
            ),
          // 5) Side edge catch (pill bars especially).
          if (isFloating)
            fillLayer(
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      DSColors.white.withValues(alpha: isDark ? 0.04 : 0.05),
                      DSColors.transparent,
                      DSColors.transparent,
                      DSColors.white.withValues(alpha: isDark ? 0.03 : 0.04),
                    ],
                    stops: const [0.0, 0.14, 0.86, 1.0],
                  ),
                ),
              ),
            ),
          // 6) Top hairline highlight (1px light catch).
          if (sizeToChild)
            Positioned(top: 0, left: 0, right: 0, child: hairline)
          else
            Align(alignment: Alignment.topCenter, child: hairline),
          // 7) No dark bottom dissolve — brand fade under rounded corners
          // looked like dirty spots (Dispatch / list headers). Soft lift is
          // only [DSGlass.headerShadow] (green ambient, no black).
          // 8) Rim.
          if (border != null)
            fillLayer(
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: border,
                  ),
                ),
              ),
            ),
          // 9) Foreground — sizes the strip when [sizeToChild].
          if (sizeToChild) child ?? const SizedBox.shrink() else ...[?child],
        ];

        final stack = Stack(
          fit: sizeToChild ? StackFit.loose : StackFit.expand,
          children: stackChildren,
        );

        // Solid brand continuous unit: no BackdropFilter — color is exact
        // primary so header + strip extension always match. Glass chrome blurs.
        Widget glass = ClipRRect(
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: solidBrand
              ? stack
              : BackdropFilter(
                  filter: DSGlass.liquidFilterFor(context),
                  child: stack,
                ),
        );

        if (bounded) {
          glass = SizedBox.expand(child: glass);
        } else if (sizeToChild) {
          glass = SizedBox(
            width: constraints.hasBoundedWidth
                ? constraints.maxWidth
                : double.infinity,
            child: glass,
          );
        } else {
          glass = SizedBox(
            width: constraints.hasBoundedWidth
                ? constraints.maxWidth
                : double.infinity,
            height: DSGlass.chromeHeight,
            child: glass,
          );
        }

        if (shadows == null) return glass;

        return DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
          child: glass,
        );
      },
    );
  }
}
