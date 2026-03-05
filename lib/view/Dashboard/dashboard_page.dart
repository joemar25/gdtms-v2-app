import 'package:flutter/material.dart';
import 'package:fsi_courier_app/view/scan_barcode/scan_barcode_page.dart';
import 'components/dashboard_header.dart';
import 'components/payout_card.dart';
import 'components/announcements.dart';
import 'components/deliveries_section.dart';
import 'components/dashboard_sidebar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Key _deliveriesKey = UniqueKey();
  bool _showRecentOnly = true;

  Future<void> _refreshDashboard() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _deliveriesKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const DashboardSidebar(),
      appBar: const DashboardHeader(),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: const Color(0xFF2E7D32),
        displacement: 30,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PayoutCard(),
              const SizedBox(height: 20),
              const AnnouncementsSection(),
              const SizedBox(height: 20),
              // 🔹 Better UI for Recently Scanned toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showRecentOnly = true;
                        _deliveriesKey = UniqueKey();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _showRecentOnly ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        'Recent',
                        style: TextStyle(
                          color: _showRecentOnly ? Colors.white : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showRecentOnly = false;
                        _deliveriesKey = UniqueKey();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: !_showRecentOnly ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        'All',
                        style: TextStyle(
                          color: !_showRecentOnly ? Colors.white : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DeliveriesSection(
                key: _deliveriesKey,
                showRecentOnly: _showRecentOnly,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD2A679),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text(
          "Scan Barcode",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ScanPackageBarcodePage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
      ),
    );
  }
}
