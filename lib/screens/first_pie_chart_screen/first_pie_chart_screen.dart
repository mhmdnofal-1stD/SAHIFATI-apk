import 'package:flutter/material.dart';
import '../sahifa_screen/sahifa_screen.dart';

class FirstPieChartScreen extends StatelessWidget {
  const FirstPieChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SahifaScreen(firstScreen: true);
  }
}
