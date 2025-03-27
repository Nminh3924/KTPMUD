import 'package:flutter/material.dart';

class PlaceholderContent extends StatelessWidget {
  final String title;

  const PlaceholderContent({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title - Đang phát triển',
        style: const TextStyle(fontSize: 24, color: Colors.grey),
      ),
    );
  }
}