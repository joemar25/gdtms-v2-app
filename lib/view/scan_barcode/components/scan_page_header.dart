import 'package:flutter/material.dart';

class ScanPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool torchOn;
  final VoidCallback onBack;
  final VoidCallback onToggleFlash;
  final String title;

  const ScanPageHeader({
    super.key,
    required this.torchOn,
    required this.onBack,
    required this.onToggleFlash,
    this.title = "Scan Barcode",
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,

      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: onBack,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            torchOn ? Icons.flash_on : Icons.flash_off,
            color: torchOn ? Colors.amber : Colors.black87,
          ),
          onPressed: onToggleFlash,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
