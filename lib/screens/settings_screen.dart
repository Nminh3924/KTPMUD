import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                labelColor: const Color.fromARGB(255, 2, 46, 50),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color.fromARGB(255, 2, 46, 50),
                labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 16),
                tabs: const [
                  Tab(text: 'Hồ sơ'),
                  Tab(text: 'Bảo mật'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    ProfileTab(),
                    SecurityTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  Map<String, dynamic>? _userProfile;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final profile = await authProvider.getCurrentUserProfile();
      if (mounted) setState(() => _userProfile = profile);
      debugPrint('Profile loaded: $_userProfile');
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi khi tải hồ sơ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUpdateAvatar() async {
    try {
      // Sử dụng file_picker để chọn ảnh
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        _showSnackBar('Không chọn được ảnh!', Colors.orange);
        return;
      }

      final filePath = result.files.single.path!;

      setState(() => _isLoading = true);
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUserId == null) {
        throw Exception('Không tìm thấy ID người dùng');
      }

      final url = await authProvider.uploadAvatar(authProvider.currentUserId!, filePath);
      if (url != null && mounted) {
        // Xóa cache của CachedNetworkImage
        await CachedNetworkImageProvider(url).evict();
        authProvider.notifyAvatarUpdated(url);
        _showSnackBar('Cập nhật ảnh thành công!', Colors.green);
        await _loadProfile();
      } else if (mounted) {
        _showSnackBar('Cập nhật ảnh thất bại!', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('StorageException')) {
          errorMessage = 'Không thể tải ảnh lên do lỗi quyền truy cập. Vui lòng kiểm tra lại cấu hình bucket.';
        }
        _showSnackBar('Lỗi: $errorMessage', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_userProfile == null) return const Center(child: Text('Không thể tải thông tin hồ sơ'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hồ sơ người dùng',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  child: ClipOval(
                    child: authProvider.currentAvatarUrl != null
                        ? CachedNetworkImage(
                            key: ValueKey(authProvider.currentAvatarUrl), // Buộc làm mới khi URL thay đổi
                            imageUrl: authProvider.currentAvatarUrl!,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Image.asset(
                              'assets/default_avatar.png',
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          )
                        : Image.asset(
                            'assets/default_avatar.png',
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _pickAndUpdateAvatar,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                    backgroundColor: const Color.fromARGB(255, 2, 46, 50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Chọn ảnh đại diện', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildProfileField('Họ và Tên', _userProfile!['name'] ?? 'Không có tên'),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: _buildProfileField('Mã số nhân viên', _userProfile!['employee_id'] ?? 'Không có mã'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildProfileField(
                          'Ngày tháng năm sinh',
                          _userProfile!['date_of_birth'] != null
                              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_userProfile!['date_of_birth']))
                              : 'Không có ngày sinh',
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: _buildProfileField('Quê quán', _userProfile!['hometown'] ?? 'Không có quê quán'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4A4A4A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      );
}

class SecurityTab extends StatefulWidget {
  const SecurityTab({super.key});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> with AutomaticKeepAliveClientMixin {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _oldPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ mật khẩu cũ, mật khẩu mới và xác nhận!', Colors.orange);
      return;
    }

    if (newPassword.length < 8) {
      _showSnackBar('Mật khẩu mới phải có ít nhất 8 ký tự!', Colors.orange);
      return;
    }
    final hasUppercase = newPassword.contains(RegExp(r'[A-Z]'));
    final hasLowercase = newPassword.contains(RegExp(r'[a-z]'));
    final hasNumber = newPassword.contains(RegExp(r'[0-9]'));
    if (!(hasUppercase && hasLowercase && hasNumber)) {
      _showSnackBar('Mật khẩu mới phải bao gồm chữ hoa, chữ thường và số!', Colors.orange);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('Mật khẩu mới và xác nhận không khớp!', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUserId == null) {
        _showSnackBar('Không tìm thấy thông tin người dùng!', Colors.red);
        return;
      }
      final success = await authProvider.changePassword(
        authProvider.currentUserId!,
        newPassword,
        oldPassword: oldPassword,
      );
      if (success && mounted) {
        _showSnackBar('Đổi mật khẩu thành công! Vui lòng đăng nhập lại.', Colors.green);
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        await authProvider.logout();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else if (mounted) {
        _showSnackBar('Mật khẩu cũ không đúng hoặc lỗi hệ thống!', Colors.red);
      }
    } catch (e) {
      debugPrint('Change password exception: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showSnackBar('Lỗi khi đổi mật khẩu: $e', Colors.red);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đổi mật khẩu:',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 24),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mật khẩu cũ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _oldPasswordController,
                    obscureText: !_oldPasswordVisible,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _oldPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color.fromARGB(255, 2, 46, 50),
                        ),
                        onPressed: () => setState(() => _oldPasswordVisible = !_oldPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Mật khẩu mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: !_newPasswordVisible,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _newPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color.fromARGB(255, 2, 46, 50),
                        ),
                        onPressed: () => setState(() => _newPasswordVisible = !_newPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Xác nhận mật khẩu mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !_confirmPasswordVisible,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color.fromARGB(255, 2, 46, 50),
                        ),
                        onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                        backgroundColor: const Color.fromARGB(255, 2, 46, 50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('Đổi mật khẩu', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}