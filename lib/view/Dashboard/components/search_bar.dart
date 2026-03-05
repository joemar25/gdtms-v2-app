import 'package:flutter/material.dart';

class SearchBarSection extends StatelessWidget {
  const SearchBarSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3, // 🟩 Subtle shadow for elevation
      borderRadius: BorderRadius.circular(8),
      shadowColor: Colors.black26,
      child: TextField(
        decoration: InputDecoration(
          hintText: "Track Package Serial",
          filled: true,
          fillColor: Colors.white, // 🟨 White background for contrast
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.gps_fixed, color: Colors.green),
            onPressed: () {},
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none, // Remove border
          ),
        ),
      ),
    );
  }
}
