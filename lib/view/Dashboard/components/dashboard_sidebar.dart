import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🟩 Logo and App Text
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset('assets/logo.png', height: 40),
                            const SizedBox(height: 4),
                            const Text(
                              "Courier App",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // 🧭 Navigation Menu
                        _buildNavItem(
                          context,
                          icon: Icons.notifications_none,
                          title: "Notifications",
                          onTap: () async {
                            // ✅ Close the sidebar drawer first
                            Navigator.pop(context);

                            // ⏳ Wait a tiny bit to let the drawer closing animation finish
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );

                            // 🚀 Navigate to ProfilePage
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, _, __) =>
                                      const NotificationsPage(),
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
                          onTap: () async {
                            // ✅ Close the sidebar drawer first
                            Navigator.pop(context);

                            // ⏳ Wait a tiny bit to let the drawer closing animation finish
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );

                            // 🚀 Navigate to ProfilePage
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, _, __) =>
                                      const ProfilePage(),
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
                          onTap: () async {
                            // ✅ Close the sidebar drawer first
                            Navigator.pop(context);

                            // ⏳ Wait a tiny bit to let the drawer closing animation finish
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );

                            // 🚀 Navigate to ProfilePage
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, _, __) =>
                                      const ScanPackageBarcodePage(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            }
                          },
                        ),

                        // _buildNavItem(
                        //   context,
                        //   icon: Icons.inventory_2_outlined,
                        //   title: "Deliveries",
                        //   onTap: () {
                        //     Navigator.pop(context);
                        //     // TODO: Navigate to Deliveries
                        //   },
                        // ),
                        const Spacer(),

                        // // 🚨 Emergency Button
                        // SizedBox(
                        //   width: double.infinity,
                        //   child: ElevatedButton.icon(
                        //     onPressed: () {
                        //       // TODO: Emergency call or action
                        //     },
                        //     icon: const Icon(
                        //       Icons.add_call,
                        //       color: Colors.white,
                        //       size: 18,
                        //     ),
                        //     label: const Text(
                        //       "EMERGENCY",
                        //       style: TextStyle(
                        //         fontWeight: FontWeight.w600,
                        //         letterSpacing: 0.5,
                        //       ),
                        //     ),
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: const Color(0xFFFF3D57),
                        //       foregroundColor: Colors.white,
                        //       padding: const EdgeInsets.symmetric(
                        //         horizontal: 16,
                        //         vertical: 14,
                        //       ),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(8),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 10),

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
                                    'https://staging-gdtms-v2.skyward.com.ph/api/mbl/logout',
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
