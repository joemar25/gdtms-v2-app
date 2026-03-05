import 'package:flutter/material.dart';
import '../../Dashboard/model/delivery_model.dart';
import 'package:intl/intl.dart';

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case "delivered":
      return Colors.green;
    case "failed":
      return Colors.red;
    case "pending":
      return Colors.lightBlue;
    default:
      return Colors.grey; // fallback or for other statuses
  }
}

class DeliveryInfoCard extends StatelessWidget {
  final Delivery delivery;

  const DeliveryInfoCard({super.key, required this.delivery});

  // Standard row: label left, value right
  Widget _infoRow(String label, String? value, {bool bold = false}) {
    final displayValue = (value == null || value.trim().isEmpty)
        ? 'N/A'
        : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Flexible(
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? Colors.black87 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Column style: label on top, value below
  Widget _infoColumn(String label, String? value, {bool boldValue = false}) {
    final displayValue = (value == null || value.trim().isEmpty)
        ? 'N/A'
        : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 14,
              fontWeight: boldValue ? FontWeight.bold : FontWeight.normal,
              color: boldValue ? Colors.black87 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Format date strings nicely
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return "N/A";
    try {
      final parsedDate = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(parsedDate);
    } catch (e) {
      return dateStr; // fallback if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Receiver Card at the top
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.name.isNotEmpty
                          ? delivery.name
                          : "Unknown Receiver",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivery.contact.isNotEmpty
                          ? delivery.contact
                          : "No contact info",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: Colors.green, size: 24),
                onPressed: delivery.contact.isEmpty
                    ? null
                    : () {
                        // TODO: Implement call
                      },
              ),
            ],
          ),
        ),

        // Main Card with Delivery Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow("Barcode", delivery.barcodeValue, bold: true),
              _infoRow("Product", delivery.product, bold: true),
              _infoRow("Sequence Number", delivery.sequenceNumber, bold: true),
              const SizedBox(height: 12),

              // Address with bold value
              _infoColumn("Address", delivery.address, boldValue: true),
              const SizedBox(height: 12),

              // Special Instructions section with bold value
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Special Instructions / Landmark",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivery.specialInstruction?.isNotEmpty == true
                          ? delivery.specialInstruction!
                          : "N/A",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Divider before metadata
              const Divider(color: Colors.black12, thickness: 1),
              const SizedBox(height: 8),

              // TAT, Transmittal Date, Status below labels
              _infoColumn("TAT", delivery.tat),
              _infoColumn(
                "Transmittal Date",
                _formatDate(delivery.transmittalDate),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Status",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
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
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
