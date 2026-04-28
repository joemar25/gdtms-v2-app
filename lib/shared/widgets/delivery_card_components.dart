import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ── Bouncing card wrapper ──────────────────────────────────────────────────────
class BouncingCardWrapper extends StatefulWidget {
  const BouncingCardWrapper({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<BouncingCardWrapper> createState() => _BouncingCardWrapperState();
}

class _BouncingCardWrapperState extends State<BouncingCardWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(_) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _onTapCancel(_) {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return Listener(
      onPointerDown: _onTapDown,
      onPointerUp: _onTapUp,
      onPointerCancel: _onTapCancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────
class DeliveryStatusBadge extends StatelessWidget {
  const DeliveryStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: DSStyles.alphaActiveAccent),
        borderRadius: DSStyles.pillRadius,
        border: Border.all(
          color: color.withValues(alpha: DSStyles.alphaDarkShadow),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini pill ──────────────────────────────────────────────────────────────────
class DeliveryMiniPill extends StatelessWidget {
  const DeliveryMiniPill({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
    required this.border,
    required this.fg,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color border;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DSStyles.pillRadius,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tiny pill ──────────────────────────────────────────────────────────────────
class DeliveryTinyPill extends StatelessWidget {
  const DeliveryTinyPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: DSStyles.alphaActiveAccent),
        borderRadius: DSStyles.pillRadius,
        border: Border.all(
          color: color.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Detail cell ────────────────────────────────────────────────────────────────
class DeliveryDetailCell extends StatelessWidget {
  const DeliveryDetailCell({
    super.key,
    required this.label,
    required this.value,
    required this.isDark,
    required this.subtextColor,
    this.valueColor,
    this.isItalic = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color subtextColor;
  final Color? valueColor;
  final bool isItalic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: subtextColor,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                valueColor ??
                (isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary),
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

// ── Info chip ──────────────────────────────────────────────────────────────────
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.isDark = false,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }
}
