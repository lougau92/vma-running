import 'package:flutter/material.dart';
import 'vma_home.dart';

class VmaApp extends StatelessWidget {
  const VmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VMA Training',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const VmaHomePage(),
    );
  }
}
