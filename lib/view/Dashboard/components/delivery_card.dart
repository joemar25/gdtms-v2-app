import 'package:flutter/material.dart';
import '../model/delivery_model.dart';
import '../../Delivery_Details/delivery_details_page.dart';

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case "delivered":
      return Colors.green;
    case "failed":
      return Colors.red;
    case "pending":
      return Colors.lightBlue;
    default:
      return Colors.grey;
  }
}

class DeliveryCard extends StatelessWidget {
  final Delivery delivery;

  const DeliveryCard({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Top row: "Package" label + Status badge (top right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Package:",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(delivery.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusColor(delivery.status),
                    width: 1,
                  ),
                ),
                child: Text(
                  delivery.status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(delivery.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // ✅ Barcode (bold)
          Text(
            delivery.barcodeValue,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),

          const SizedBox(height: 4),

          // ✅ Name (bold) and Address
          Text(
            delivery.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(delivery.address, style: const TextStyle(fontSize: 13)),

          const SizedBox(height: 8),

          // ✅ View Details Button aligned right
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryDetailsPage(delivery: delivery),
                  ),
                );
              },
              child: const Text(
                "View Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
