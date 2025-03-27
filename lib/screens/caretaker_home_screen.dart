import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/main_layout.dart';
import '../providers/auth_provider.dart';
import 'settings_screen.dart';
import '../widgets/placeholder_content.dart';

class CaretakerHomeScreen extends StatelessWidget {
  const CaretakerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Danh sách các mục trong SideBar cho Caretaker
    final List<Map<String, dynamic>> menuItems = [
      {'icon': Icons.dashboard, 'label': 'Tổng quan'},
      {'icon': Icons.book, 'label': 'Nhật ký canh tác'},
      {'icon': Icons.settings, 'label': 'Setting'},
    ];

    // Danh sách các trang nội dung
    final List<Widget> pages = [
      const CaretakerDashboardContent(),
      const PlaceholderContent(title: 'Nhật ký canh tác'),
      const SettingsScreen(),
    ];

    return MainLayout(
      role: 'caretaker',
      menuItems: menuItems,
      pages: pages,
    );
  }
}

// Nội dung Tổng quan cho Caretaker
class CaretakerDashboardContent extends StatelessWidget {
  const CaretakerDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.currentUserId ?? 'Caretaker';

    return Container(
      color: const Color(0xFFF5F6FA), // Màu nền giống các trang khác
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Padding giống SettingsScreen
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // Container trắng giống SettingsScreen
            border: Border.all(color: Colors.grey.withOpacity(0.2)), // Viền nhẹ
            borderRadius: BorderRadius.circular(8), // Bo góc
          ),
          child: Center(
            child: SingleChildScrollView( // Cho phép cuộn nếu nội dung dài
              padding: const EdgeInsets.all(24), // Padding bên trong giống SettingsScreen
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chào mừng, $userId!',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Color(0xFF4A4A4A), // Đổi màu chữ để đồng bộ
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}