import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class Header extends StatefulWidget {
  final String logoPath; // allow custom logo if needed

  const Header({super.key, this.logoPath = 'assets/logo.png'});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  late Timer _timer;
  late String _time;
  late String _date;
  late String _day;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _time = DateFormat("h:mm a").format(now); // 2:18 PM
      _date = DateFormat("d MMM").format(now).toUpperCase(); // 24 AUG
      _day = DateFormat("EEEE").format(now).toUpperCase(); // SUNDAY
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive scaling factors
    final isSmall = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;

    // Adjust sizes based on device width
    final logoHeight = isSmall
        ? 35.0
        : isTablet
        ? 60.0
        : 72.0;

    final timeFontSize = isSmall
        ? 26.0
        : isTablet
        ? 34.0
        : 40.0;

    final dateFontSize = isSmall
        ? 14.0
        : isTablet
        ? 18.0
        : 20.0;

    final paddingH = isSmall
        ? 20.0
        : isTablet
        ? 40.0
        : 80.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: 16),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Logo
          Image.asset(widget.logoPath, height: logoHeight),

          // Right Time + Date/Day
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _time,
                style: TextStyle(
                  fontSize: timeFontSize,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: logoHeight * 0.7,
                width: 1.5,
                color: Colors.black54,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _date,
                    style: TextStyle(
                      fontSize: dateFontSize,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    _day,
                    style: TextStyle(
                      fontSize: dateFontSize,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
