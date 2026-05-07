import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// A premium slide-to-confirm widget for high-stakes actions like removal or deletion.
class DSSlideToConfirm extends StatefulWidget {
  const DSSlideToConfirm({
    super.key,
    required this.onConfirm,
    this.label = 'SLIDE TO CONFIRM',
    this.color = DSColors.error,
    this.height = 52.0,
  });

  final VoidCallback onConfirm;
  final String label;
  final Color color;
  final double height;

  @override
  State<DSSlideToConfirm> createState() => _DSSlideToConfirmState();
}

class _DSSlideToConfirmState extends State<DSSlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _position = 0;
  bool _confirmed = false;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxSlide) {
    if (_confirmed) return;
    setState(() {
      _position = (_position + details.delta.dx).clamp(0.0, maxSlide);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxSlide) {
    if (_confirmed) return;
    if (_position >= maxSlide * 0.85) {
      setState(() {
        _position = maxSlide;
        _confirmed = true;
      });
      widget.onConfirm();
    } else {
      _resetAnimation = Tween<double>(begin: _position, end: 0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
      );

      _resetAnimation.addListener(() {
        setState(() {
          _position = _resetAnimation.value;
        });
      });
      _resetController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final handleSize = widget.height;
        final maxSlide = maxWidth - handleSize;

        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: DSStyles.pillRadius,
            border: Border.all(
              color: widget.color.withValues(alpha: isDark ? 0.3 : 0.2),
            ),
          ),
          child: Stack(
            children: [
              // Background Label
              Center(
                child: Opacity(
                  opacity: (1 - (_position / (maxSlide * 0.7))).clamp(0.0, 1.0),
                  child: Text(
                    widget.label,
                    style: DSTypography.label(color: widget.color).copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: DSTypography.sizeXs,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),

              // The Slider Handle
              Positioned(
                left: _position,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxSlide),
                  onHorizontalDragEnd: (d) => _onDragEnd(d, maxSlide),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: DSStyles.pillRadius,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed
                          ? Icons.check_rounded
                          : Icons.chevron_right_rounded,
                      color: DSColors.white,
                      size: DSIconSize.md,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
