import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // Thêm import này
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/manage_users_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/engineer_home_screen.dart';
import 'screens/caretaker_home_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo locale cho intl (để sử dụng DateFormat với 'vi_VN')
  try {
    await initializeDateFormatting('vi_VN', null);
    debugPrint('Locale vi_VN initialized successfully');
  } catch (e) {
    debugPrint('Error initializing locale vi_VN: $e');
  }

  // Khởi tạo Supabase
  try {
    await Supabase.initialize(
      url: 'https://ywzvjzqxnsxswfcdxsnv.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3enZqenF4bnN4c3dmY2R4c252Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE4NTg0MTEsImV4cCI6MjA1NzQzNDQxMX0.EZwrhHr_qNn26dQkNqtLuqzjx-PT_30Iusa9OQyxwNQ',
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
  }

  // Khởi tạo Hive
  try {
    await Hive.initFlutter();
    await Hive.openBox('sensor_data'); // Mở box để lưu trữ dữ liệu
    debugPrint('Hive initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Hive: $e');
  }

  // Chỉ gọi runApp một lần
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 198, 40, 40),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTAM 158176',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/manage-users': (_) => const ManageUsersScreen(),
        '/admin-home': (_) => const AdminHomeScreen(),
        '/engineer-home': (_) => const EngineerHomeScreen(),
        '/caretaker-home': (_) => const CaretakerHomeScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authProvider = context.read<AuthProvider>();

    // Đảm bảo splash screen hiển thị ít nhất 1 giây
    const minimumSplashDuration = Duration(seconds: 1);
    final splashTimer = Future.delayed(minimumSplashDuration);

    try {
      // Khởi tạo AuthProvider
      await authProvider.initialize(); // Đảm bảo AuthProvider đã sẵn sàng
      await splashTimer; // Đợi ít nhất 1 giây để hiển thị splash screen

      if (authProvider.isLoggedIn && authProvider.userRole != null) {
        final role = authProvider.userRole!;
        debugPrint('Auto-navigating to $role home screen');
        switch (role) {
          case 'admin':
            Navigator.pushReplacementNamed(context, '/admin-home');
            break;
          case 'engineer':
            Navigator.pushReplacementNamed(context, '/engineer-home');
            break;
          case 'caretaker':
            Navigator.pushReplacementNamed(context, '/caretaker-home');
            break;
          default:
            Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        debugPrint('No session found, navigating to /login');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lỗi khi kiểm tra trạng thái đăng nhập. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 3)); // Đợi để người dùng thấy thông báo
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'HTAM 158176',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đang kiểm tra trạng thái đăng nhập...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}