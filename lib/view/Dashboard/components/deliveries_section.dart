import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../model/delivery_model.dart';
import '../components/delivery_card.dart';

class DeliveriesSection extends StatefulWidget {
  final bool showRecentOnly; // Filter flag

  const DeliveriesSection({super.key, this.showRecentOnly = true});

  @override
  State<DeliveriesSection> createState() => _DeliveriesSectionState();
}

class _DeliveriesSectionState extends State<DeliveriesSection> {
  final List<Delivery> _deliveries = []; // All deliveries
  bool _isLoading = false;
  int _currentPage = 1;
  static const int _perPage = 5;
  static const String _cacheKey = 'recently_scanned_deliveries';

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    if (widget.showRecentOnly) {
      // Load cached recent deliveries
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString != null) {
        final List<dynamic> data = json.decode(jsonString);
        final cached = data.map((e) => Delivery.fromJson(e)).toList();
        setState(() {
          _deliveries.clear();
          _deliveries.addAll(cached);
        });
      }
    } else {
      // Fetch all deliveries from API
      final token = prefs.getString('auth_token') ?? '';
      final url = Uri.parse(
        'https://staging-gdtms-v2.skyward.com.ph/api/mbl/deliveries?active=true&per_page=1000',
      );

      try {
        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          final List<dynamic> data = decoded['data'];
          final fetched = data.map((e) => Delivery.fromJson(e)).toList();
          setState(() {
            _deliveries.clear();
            _deliveries.addAll(fetched);
          });
        } else {
          debugPrint('Failed to fetch deliveries: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error fetching deliveries: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> addScannedDelivery(Delivery delivery) async {
    final prefs = await SharedPreferences.getInstance();
    _deliveries.removeWhere((d) => d.id == delivery.id);
    _deliveries.insert(0, delivery);
    setState(() {});
    final jsonString = json.encode(_deliveries.map((d) => d.toJson()).toList());
    await prefs.setString(_cacheKey, jsonString);
  }

  void _previousPage() {
    if (_currentPage > 1) setState(() => _currentPage--);
  }

  void _nextPage() {
    final totalPages = (_filteredDeliveries.length / _perPage).ceil();
    if (_currentPage < totalPages) setState(() => _currentPage++);
  }

  List<Delivery> get _filteredDeliveries {
    if (widget.showRecentOnly) {
      return _deliveries.take(10).toList(); // show only recent
    }
    return _deliveries; // show all
  }

  @override
  Widget build(BuildContext context) {
    if (_deliveries.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      );
    }

    if (_deliveries.isEmpty) {
      return const Center(child: Text("No deliveries available."));
    }

    final filtered = _filteredDeliveries;
    final startIndex = (_currentPage - 1) * _perPage;
    final endIndex = (_currentPage * _perPage).clamp(0, filtered.length);
    final currentPageItems = filtered.sublist(startIndex, endIndex);
    final totalPages = (filtered.length / _perPage).ceil();

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentPageItems.length,
          itemBuilder: (context, index) {
            return DeliveryCard(delivery: currentPageItems[index]);
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _currentPage > 1 ? _previousPage : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage > 1
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                    ),
                    child: Icon(
                      Icons.arrow_left,
                      color: _currentPage > 1 ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    "$_currentPage / $totalPages",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _currentPage < totalPages ? _nextPage : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage < totalPages
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                    ),
                    child: Icon(
                      Icons.arrow_right,
                      color: _currentPage < totalPages
                          ? Colors.green
                          : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
