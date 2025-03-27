import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MainLayout extends StatefulWidget {
  final String role;
  final List<Map<String, dynamic>> menuItems;
  final List<Widget> pages;
  final int initialIndex;

  const MainLayout({
    super.key,
    required this.role,
    required this.menuItems,
    required this.pages,
    this.initialIndex = 0,
  });

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.menuItems.length - 1);
  }

  void _selectPage(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index.clamp(0, widget.menuItems.length - 1);
      });
    }
  }

  Future<void> _handleLogout() async {
    bool canLogout = false;
    int countdown = 5;

    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void startCountdown() {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {
                    countdown--;
                    if (countdown > 0) {
                      startCountdown();
                    } else {
                      canLogout = true;
                    }
                  });
                }
              });
            }

            if (countdown == 5) {
              startCountdown();
            }

            return AlertDialog(
              title: const Text(
                'Xác nhận đăng xuất',
                style: TextStyle(color: Color(0xFF4A4A4A), fontSize: 18),
              ),
              content: const Text(
                'Bạn có chắc chắn muốn đăng xuất không?',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: Color.fromARGB(255, 198, 40, 40), fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: canLogout ? () => Navigator.of(dialogContext).pop(true) : null,
                  child: Text(
                    canLogout ? 'Đăng xuất' : 'Đăng xuất ($countdown)',
                    style: TextStyle(
                      color: canLogout ? const Color.fromARGB(255, 198, 40, 40) : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          },
        );
      },
    );

    if (confirm == true && mounted) {
      debugPrint('Starting logout process...');
      try {
        final authProvider = context.read<AuthProvider>();
        await authProvider.logout();
        debugPrint('Navigating to /login...');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            }
          });
        }
      } catch (e) {
        debugPrint('Logout failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể đăng xuất: $e', style: const TextStyle(fontSize: 14)),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      debugPrint('Logout cancelled or widget not mounted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return ScaffoldMessenger(
      key: authProvider.scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: LayoutBuilder(
          builder: (context, constraints) {
            const double minWidth = 1000; // Giảm từ 1200 xuống 1000
            const double minHeight = 600; // Giảm từ 800 xuống 600

            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final double designWidth = screenWidth < minWidth ? minWidth : screenWidth;
            final double designHeight = screenHeight < minHeight ? minHeight : screenHeight;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: screenWidth),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: designWidth,
                    height: designHeight,
                    child: Container(
                      color: const Color(0xFFF5F6FA),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sidebar
                          Container(
                            width: 270,
                            margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 255, 255, 238),
                                  Color.fromARGB(255, 251, 253, 207),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                // Logo
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    height: 120,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.image_not_supported,
                                          size: 120, color: Colors.grey);
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: widget.menuItems.length,
                                    itemBuilder: (context, index) {
                                      final item = widget.menuItems[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () => _selectPage(index),
                                            hoverColor: const Color.fromARGB(255, 2, 46, 50).withOpacity(0.2),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _selectedIndex == index
                                                    ? const Color.fromARGB(255, 2, 46, 50).withOpacity(0.1)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    item['icon'],
                                                    size: 28,
                                                    color: _selectedIndex == index
                                                        ? const Color.fromARGB(255, 2, 46, 50)
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      item['label'],
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight: _selectedIndex == index
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                        color: _selectedIndex == index
                                                            ? const Color.fromARGB(255, 2, 46, 50)
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Nút đăng xuất
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: _handleLogout,
                                      hoverColor: Colors.red.withOpacity(0.2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.logout, color: Colors.grey, size: 28),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Đăng xuất',
                                                style: TextStyle(fontSize: 17, color: Colors.grey),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Phần chính
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  bottomLeft: Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // AppBar
                                  Container(
                                    height: 80,
                                    margin: const EdgeInsets.only(left: 16, right: 16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color.fromARGB(255, 255, 255, 238),
                                          Color.fromARGB(255, 251, 253, 207),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          widget.menuItems[_selectedIndex]['label'],
                                          style: const TextStyle(
                                            color: Color(0xFF4A4A4A),
                                            fontSize: 27,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.notifications,
                                                color: Color(0xFF4A4A4A),
                                                size: 30,
                                              ),
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Thông báo được nhấp!',
                                                        style: TextStyle(fontSize: 14)),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Consumer<AuthProvider>(
                                              builder: (context, authProvider, child) {
                                                return GestureDetector(
                                                  onTap: () => _selectPage(widget.menuItems.length - 1),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      // Lớp nền: Ảnh avatar
                                                      CircleAvatar(
                                                        radius: 28,
                                                        backgroundColor: Colors.grey[200],
                                                        backgroundImage: authProvider.currentAvatarUrl != null &&
                                                                authProvider.currentAvatarUrl!.isNotEmpty
                                                            ? CachedNetworkImageProvider(
                                                                authProvider.currentAvatarUrl!,
                                                                headers: const {
                                                                  'Authorization':
                                                                      'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3enZqenF4bnN4c3dmY2R4c252Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjY0NzM5NDcsImV4cCI6MjA0MjA0OTk0N30.5oW2XPRv0g2hX7sL0v2zq2i2zq2i2zq2i2zq2i2zq2i',
                                                                },
                                                              )
                                                            : const AssetImage('assets/default_avatar.png'),
                                                      ),
                                                      // Lớp phủ: Viền trắng
                                                      Container(
                                                        width: 56,
                                                        height: 56,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          border: Border.all(color: Colors.white, width: 2),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Nội dung chính
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(opacity: animation, child: child);
                                      },
                                      child: widget.pages[_selectedIndex],
                                      key: ValueKey<int>(_selectedIndex),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}