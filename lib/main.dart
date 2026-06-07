import 'package:flutter/material.dart';

void main() {
  runApp(const AutomaticWateringApp());
}

class AutomaticWateringApp extends StatelessWidget {
  const AutomaticWateringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Automatic Watering',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatic Watering'),
      ),
      body: const Center(
        child: Text('Automatic watering mobile app'),
      ),
    );
  }
}
