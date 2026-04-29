import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/wallet/widgets/earnings_card.dart';
import 'package:fsi_courier_app/shared/widgets/payment_method_card.dart';

class WalletFlipCard extends StatefulWidget {
  const WalletFlipCard({
    super.key,
    required this.tentativePayout,
    required this.pendingRequestAmt,
    required this.isLatestPending,
    required this.showPending,
    required this.paymentMethod,
    this.canConsolidate = false,
    this.onConsolidate,
  });

  final dynamic tentativePayout;
  final dynamic pendingRequestAmt;
  final bool isLatestPending;
  final bool showPending;
  final Map<String, dynamic>? paymentMethod;
  final bool canConsolidate;
  final VoidCallback? onConsolidate;

  @override
  State<WalletFlipCard> createState() => _WalletFlipCardState();
}

class _WalletFlipCardState extends State<WalletFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DSAnimations.dSlow,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (!mounted) return;
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    // If not latest pending, only show the front (no flip needed)
    if (!widget.isLatestPending || widget.paymentMethod == null) {
      return EarningsCard(
        tentativePayout: widget.tentativePayout,
        pendingRequestAmt: widget.pendingRequestAmt,
        canConsolidate: widget.canConsolidate,
        onConsolidate: widget.onConsolidate,
        isLatestPending: widget.isLatestPending,
        showPending: widget.showPending,
        isFlipping: false,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * math.pi;
        final isUnder = angle > math.pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isUnder
              ? Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: EarningsCard(
                    tentativePayout: widget.tentativePayout,
                    pendingRequestAmt: widget.pendingRequestAmt,
                    canConsolidate: widget.canConsolidate,
                    onConsolidate: widget.onConsolidate,
                    isLatestPending: widget.isLatestPending,
                    showPending: widget.showPending,
                    watermarkIcon: Icons.account_balance_rounded,
                    onTap: _flip,
                    child: PaymentMethodCard(
                      data: widget.paymentMethod!,
                      isTransparent: true,
                    ),
                  ),
                )
              : EarningsCard(
                  tentativePayout: widget.tentativePayout,
                  pendingRequestAmt: widget.pendingRequestAmt,
                  canConsolidate: widget.canConsolidate,
                  onConsolidate: widget.onConsolidate,
                  isLatestPending: widget.isLatestPending,
                  showPending: widget.showPending,
                  onTap: _flip,
                ),
        );
      },
    );
  }
}
