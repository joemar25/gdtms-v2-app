import 'dart:async';
import 'package:flutter/material.dart';

class FadeCarousel extends StatefulWidget {
  final List<String> images;
  final double height;

  const FadeCarousel({super.key, required this.images, required this.height});

  @override
  State<FadeCarousel> createState() => _FadeCarouselState();
}

class _FadeCarouselState extends State<FadeCarousel> {
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _currentPage = (_currentPage + 1) % widget.images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: List.generate(widget.images.length, (index) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 800),
            opacity: _currentPage == index ? 1.0 : 0.0,
            curve: Curves.easeInOut,
            child: Image.asset(
              widget.images[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          );
        }),
      ),
    );
  }
}
