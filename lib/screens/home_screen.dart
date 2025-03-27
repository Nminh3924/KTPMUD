import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'admin_home_screen.dart';
import 'engineer_home_screen.dart';
import 'caretaker_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Điều hướng dựa trên vai trò
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authProvider.userRole == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
      } else if (authProvider.userRole == 'engineer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EngineerHomeScreen()),
        );
      } else if (authProvider.userRole == 'caretaker') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CaretakerHomeScreen()),
        );
      } else {
        // Trường hợp không xác định được vai trò, đăng xuất
        authProvider.logout();
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    // Trả về một màn hình tạm trong lúc điều hướng
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}