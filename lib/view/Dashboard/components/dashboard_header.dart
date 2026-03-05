import 'package:flutter/material.dart';
import 'package:fsi_courier_app/view/Notifications_page/notifications_page.dart';

class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white, // ✅ stays white when scrolling
      surfaceTintColor:
          Colors.white, // ✅ prevents material tint overlay on scroll
      elevation: 0, // ✅ no shadow
      scrolledUnderElevation:
          0, // ✅ prevents auto-shadow on scroll (Material 3)
      automaticallyImplyLeading: false, // ✅ so it doesn’t double-draw icons

      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.black87),
        onPressed: () {
          // ✅ Open the sidebar drawer
          Scaffold.of(context).openDrawer();
        },
      ),
      centerTitle: true,
      title: const Text(
        "Dashboard",
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsPage()),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
