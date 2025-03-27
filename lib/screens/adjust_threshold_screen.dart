import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm để sử dụng inputFormatters
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';

class AdjustThresholdScreen extends StatefulWidget {
  const AdjustThresholdScreen({super.key});

  @override
  _AdjustThresholdScreenState createState() => _AdjustThresholdScreenState();
}

class _AdjustThresholdScreenState extends State<AdjustThresholdScreen> {
  final _minThresholdController = TextEditingController();
  final _maxThresholdController = TextEditingController();
  String _message = '';
  final supabase = Supabase.instance.client;
  int? _thresholdId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentThresholds();
  }

  Future<void> _fetchCurrentThresholds() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final response = await supabase
          .from('thresholds')
          .select()
          .order('id', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _thresholdId = response['id'];
          _minThresholdController.text = response['min_soil_moisture'].toString();
          _maxThresholdController.text = response['max_soil_moisture'].toString();
        });
      } else {
        setState(() {
          _message = 'Không tìm thấy ngưỡng. Vui lòng liên hệ quản trị viên để khởi tạo dữ liệu.';
          _minThresholdController.text = '30';
          _maxThresholdController.text = '70';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Lỗi khi lấy ngưỡng: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateThresholds() async {
    final authProvider = context.read<AuthProvider>();
    // Kiểm tra vai trò, chỉ cho phép 'engineer'
    if (!['engineer'].contains(authProvider.userRole)) {
      setState(() {
        _message = 'Lỗi: Chỉ kỹ sư mới có thể cập nhật ngưỡng.';
      });
      return;
    }

    final minThreshold = int.tryParse(_minThresholdController.text) ?? 0;
    final maxThreshold = int.tryParse(_maxThresholdController.text) ?? 0;

    // Kiểm tra giới hạn tối thiểu (0%) và tối đa (100%)
    if (minThreshold < 0 || maxThreshold < 0) {
      setState(() {
        _message = 'Lỗi: Ngưỡng không thể nhỏ hơn 0%.';
      });
      return;
    }
    if (minThreshold > 100 || maxThreshold > 100) {
      setState(() {
        _message = 'Lỗi: Ngưỡng không thể vượt quá 100%.';
      });
      return;
    }

    if (minThreshold >= maxThreshold) {
      setState(() {
        _message = 'Lỗi: Ngưỡng tối thiểu phải nhỏ hơn ngưỡng tối đa.';
      });
      return;
    }

    if (_thresholdId == null) {
      setState(() {
        _message = 'Lỗi: Không có bản ghi ngưỡng để cập nhật. Vui lòng liên hệ quản trị viên.';
      });
      return;
    }

    // Hiển thị thông báo xác nhận với giao diện cải thiện
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Xác Nhận Cập Nhật',
          style: TextStyle(color: Color.fromARGB(255, 2, 46, 50)),
        ),
        content: const Text('Bạn có chắc chắn muốn cập nhật ngưỡng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color.fromARGB(255, 198, 40, 40)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xác Nhận',
              style: TextStyle(color: Color.fromARGB(255, 198, 40, 40)),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final userId = authProvider.currentUserId ?? 'unknown';

      await supabase.from('thresholds').update({
        'min_soil_moisture': minThreshold,
        'max_soil_moisture': maxThreshold,
        'updated_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _thresholdId!);

      setState(() {
        _message = 'Cập nhật ngưỡng thành công!';
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi khi cập nhật ngưỡng: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // Màu nền giống SettingsScreen
      // Xóa hoàn toàn AppBar
      body: Padding(
        padding: const EdgeInsets.all(24.0), // Padding giống SettingsScreen
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // Container trắng giống SettingsScreen
            border: Border.all(color: Colors.grey.withOpacity(0.2)), // Viền nhẹ
            borderRadius: BorderRadius.circular(8), // Bo góc
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator()) // Hiển thị loading
              : SingleChildScrollView( // Cho phép cuộn
                  padding: const EdgeInsets.all(24), // Padding bên trong giống SettingsScreen
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Khôi phục tiêu đề "Điều chỉnh ngưỡng độ ẩm đất" bên trong container
                      const Text(
                        'Điều chỉnh ngưỡng độ ẩm đất',
                        style: TextStyle(
                          fontSize: 25, // Kích thước tiêu đề giống SettingsScreen
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A4A4A), // Màu chữ giống SettingsScreen
                        ),
                      ),
                      const SizedBox(height: 24), // Khoảng cách giống SettingsScreen
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400), // Giới hạn chiều rộng giống SettingsScreen
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ngưỡng độ ẩm tối thiểu (%)',
                                style: TextStyle(
                                  fontSize: 14, // Kích thước nhãn giống SettingsScreen
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8), // Khoảng cách giống SettingsScreen
                              TextField(
                                controller: _minThresholdController,
                                decoration: InputDecoration(
                                  hintText: '0 - 100',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8), // Bo góc giống SettingsScreen
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ), // Padding bên trong giống SettingsScreen
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                              const SizedBox(height: 16), // Khoảng cách giống SettingsScreen
                              const Text(
                                'Ngưỡng độ ẩm tối đa (%)',
                                style: TextStyle(
                                  fontSize: 14, // Kích thước nhãn giống SettingsScreen
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8), // Khoảng cách giống SettingsScreen
                              TextField(
                                controller: _maxThresholdController,
                                decoration: InputDecoration(
                                  hintText: '0 - 100',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8), // Bo góc giống SettingsScreen
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ), // Padding bên trong giống SettingsScreen
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                              const SizedBox(height: 32), // Khoảng cách giống SettingsScreen
                              Center(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _updateThresholds,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(200, 50), // Kích thước nút giống SettingsScreen
                                    backgroundColor: const Color.fromARGB(255, 2, 46, 50), // Màu nút giống SettingsScreen
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8), // Bo góc giống SettingsScreen
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white),
                                        ) // Hiển thị loading giống SettingsScreen
                                      : const Text(
                                          'Cập nhật ngưỡng',
                                          style: TextStyle(fontSize: 16), // Kích thước chữ giống SettingsScreen
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16), // Khoảng cách giống SettingsScreen
                              Center(
                                child: Text(
                                  _message,
                                  style: TextStyle(
                                    color: _message.startsWith('Lỗi') ? Colors.red : Colors.green,
                                    fontSize: 14, // Kích thước chữ thông báo
                                  ),
                                  textAlign: TextAlign.center,
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
    );
  }

  @override
  void dispose() {
    _minThresholdController.dispose();
    _maxThresholdController.dispose();
    super.dispose();
  }
}