import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/main.dart';
import 'package:fsi_courier_app/view/Profile/profile_page.dart';
import 'package:fsi_courier_app/view/notifications_page/notifications_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fsi_courier_app/view/scan_barcode/scan_barcode_page.dart';
import 'package:http/http.dart' as http;

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Force white status bar (not transparent)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // ✅ Add a top padding equal to the status bar height
    final double topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      backgroundColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding), // 👈 below status bar
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12, // compact vertical
                      horizontal: 8, // compact horizontal
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🟩 Logo and App Text
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset('assets/icon.png', height: 28), // smaller logo
                            const SizedBox(height: 2),
                            const Text(
                              "Courier App",
                              style: TextStyle(
                                fontSize: 11, // smaller font
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18), // less gap

                        // 🧭 Navigation Menu
                        _buildNavItem(
                          context,
                          icon: Icons.notifications_none,
                          title: "Notifications",
                          iconSize: 20, // smaller icon
                          fontSize: 13, // smaller font
                          verticalPadding: 8, // less padding
                          onTap: () async {
                            Navigator.pop(context);
                            await Future.delayed(const Duration(milliseconds: 200));
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, _, __) => const NotificationsPage(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            }
                          },
                        ),
                        _buildNavItem(
                          context,
                          icon: Icons.person_outline,
                          title: "Profile",
                          iconSize: 20,
                          fontSize: 13,
                          verticalPadding: 8,
                          onTap: () async {
                            Navigator.pop(context);
                            await Future.delayed(const Duration(milliseconds: 200));
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, _, __) => const ProfilePage(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            }
                          },
                        ),
                        _buildNavItem(
                          context,
                          icon: Icons.qr_code_scanner,
                          title: "Scan Package",
                          iconSize: 24, // keep scan prominent
                          fontSize: 14, // keep scan prominent
                          verticalPadding: 12, // keep scan prominent
                          highlight: true, // custom param for visual emphasis
                          onTap: () async {
                            Navigator.pop(context);
                            await Future.delayed(const Duration(milliseconds: 200));
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, _, __) => const ScanPackageBarcodePage(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            }
                          },
                        ),
                        const Spacer(),
                        const SizedBox(height: 6), // less gap before logout

                        // 🔒 Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    "Logout",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: const Text(
                                    "Are you sure you want to logout?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2E7D32,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text("Confirm"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && context.mounted) {
                                try {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final token =
                                      prefs.getString("auth_token") ?? "";

                                  final url = Uri.parse(
                                    '$apiBaseUrl/logout',
                                  );

                                  final response = await http.post(
                                    url,
                                    headers: {
                                      'Content-Type': 'application/json',
                                      'Authorization': 'Bearer $token',
                                    },
                                  );
                                  if (response.statusCode == 200) {
                                    await prefs.remove("auth_token");

                                    // Debug message
                                    debugPrint(
                                      "Logout successful, token removed.",
                                    );

                                    if (context.mounted) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const HomePage(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  } else {
                                    debugPrint(
                                      "Logout failed with status code: ${response.statusCode}",
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Logout failed"),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e")),
                                  );
                                }
                              }
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text("Logout"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 📦 Clickable Navigation Item Builder
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    double iconSize = 24,
    double fontSize = 15,
    double verticalPadding = 12,
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black87,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
