import 'package:flutter/material.dart';
import 'carousel.dart';
import 'login_card.dart';

class Body extends StatelessWidget {
  const Body({super.key});

  final List<String> _images = const [
    'assets/images/delivery2.png',
    'assets/images/about.png',
    'assets/images/warehousing.png',
  ];

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              FadeCarousel(images: _images, height: screenHeight * 0.35),
              const LoginCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
