import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final String imagePath;
  final String text;
  final Color backgroundColor;
  final TextStyle? textStyle;
  final Duration fadeDuration;

  const SplashScreen({
    super.key,
    required this.imagePath,
    required this.text,
    this.backgroundColor = Colors.white,
    this.textStyle,
    this.fadeDuration = const Duration(seconds: 1),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward(); // Start fade-in animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1000;

    // 🧠 Responsive sizing
    final imageSize = isSmall
        ? size.width * 0.5
        : isTablet
        ? size.width * 0.35
        : 250.0;

    final textFontSize = isSmall
        ? 16.0
        : isTablet
        ? 18.0
        : 20.0;

    // ✨ Reduced spacing between logo and text
    const spacing = 1.0;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 20 : 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🖼️ Logo / Image
                Image.asset(
                  widget.imagePath,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: spacing),

                // ✨ App Title / Text
                Text(
                  widget.text,
                  style:
                      widget.textStyle ??
                      TextStyle(
                        fontSize: textFontSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
