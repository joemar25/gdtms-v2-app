import 'package:flutter/material.dart';

class PayoutCard extends StatefulWidget {
  const PayoutCard({super.key});

  @override
  State<PayoutCard> createState() => _PayoutCardState();
}

class _PayoutCardState extends State<PayoutCard> {
  bool _isBalanceVisible = true; // ✅ controls visibility

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final bool isSmall = screenWidth < 350;
    final bool isMedium = screenWidth < 500;

    final double padding = isSmall ? 10 : 16;
    final double balanceFontSize = isSmall
        ? 20
        : isMedium
        ? 24
        : 28;
    final double labelFontSize = isSmall
        ? 12
        : isMedium
        ? 13
        : 14;
    final double buttonFontSize = isSmall
        ? 11
        : isMedium
        ? 12
        : 13;
    final double iconSize = isSmall ? 14 : 16;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top balance section
          _buildBalanceSection(labelFontSize, balanceFontSize),
          const SizedBox(height: 16),

          // Spacer pushes button to bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildButton(buttonFontSize, iconSize, fullWidth: true),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection(double labelSize, double balanceSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Available Payout Balance ",
              style: TextStyle(color: Colors.white, fontSize: labelSize),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isBalanceVisible = !_isBalanceVisible; // toggle visibility
                });
              },
              child: Icon(
                _isBalanceVisible ? Icons.remove_red_eye : Icons.visibility_off,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isBalanceVisible ? "PHP 0.00" : "••••••••",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: balanceSize,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(
    double fontSize,
    double iconSize, {
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(Icons.credit_card, size: iconSize, color: Colors.white),
        label: Text(
          "WORK IN PROGRESS!!",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(172, 255, 198, 129),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
