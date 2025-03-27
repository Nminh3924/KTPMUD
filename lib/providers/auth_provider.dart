import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

// Enum để xác định lý do thất bại khi đăng nhập
enum LoginFailureReason { notFound, wrongPassword, error }

// Lớp ngoại lệ tùy chỉnh để xử lý lỗi xác thực
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

// Hằng số cho các thông báo lỗi
class AuthErrorMessages {
  static const String userNotFound = 'Tài khoản không tồn tại. Vui lòng kiểm tra lại ID.';
  static const String wrongPassword = 'ID hoặc Mật khẩu không đúng. Vui lòng thử lại.';
  static const String unauthorized = 'Bạn không có quyền thực hiện hành động này.';
  static const String onlyOneAdmin = 'Chỉ được phép có một tài khoản admin.';
  static const String cannotDeleteAdmin = 'Không thể xóa tài khoản admin.';
  static const String onlyAdminCanCreate = 'Chỉ admin mới có thể tạo tài khoản.';
  static const String onlyAdminCanDelete = 'Chỉ admin mới có thể xóa tài khoản.';
  static const String onlyAdminCanFetch = 'Chỉ admin mới có thể xem danh sách người dùng.';
  static const String passwordTooWeak = 'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số.';
  static const String oldPasswordRequired = 'Vui lòng nhập mật khẩu cũ để đổi mật khẩu.';
  static const String userAlreadyExists = 'Tài khoản đã tồn tại. Vui lòng chọn ID khác.';
  static const String sessionInvalid = 'Phiên đăng nhập không hợp lệ, vui lòng đăng nhập lại.';
}

class AuthProvider extends ChangeNotifier {
  String? _userRole;
  String? _currentUserId;
  String? _currentAvatarUrl;
  String? _sessionToken;
  bool? _isAdmin;
  LoginFailureReason? _loginFailureReason;
  final SupabaseClient _supabase = Supabase.instance.client;

  // GlobalKey để hiển thị SnackBar
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Getter để truy cập ScaffoldMessengerKey
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey => _scaffoldMessengerKey;

  // Getter để truy cập các thuộc tính
  String? get userRole => _userRole;
  String? get currentUserId => _currentUserId;
  String? get currentAvatarUrl => _currentAvatarUrl;
  bool? get isAdmin => _isAdmin;
  LoginFailureReason? get loginFailureReason => _loginFailureReason;
  bool get isLoggedIn => _currentUserId != null && _sessionToken != null;

  AuthProvider() {
    // Không gọi _loadSavedSession() trong constructor nữa
  }

  /// Khởi tạo trạng thái của AuthProvider
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('currentUserId');
    _userRole = prefs.getString('userRole');
    _sessionToken = prefs.getString('sessionToken');
    _isAdmin = prefs.getBool('isAdmin');

    if (_currentUserId != null && _sessionToken != null) {
      try {
        final profile = await getCurrentUserProfile();
        if (profile != null) {
          _currentAvatarUrl = profile['avatar_url'] as String?;
          _isAdmin = profile['is_admin'] as bool? ?? (_userRole == 'admin');
          await prefs.setBool('isAdmin', _isAdmin!);
        } else {
          // Nếu không tải được profile, xóa session nếu không phải admin
          if (_userRole != 'admin') {
            await _clearSession(prefs);
          }
        }
      } catch (e) {
        debugPrint('Error loading saved session: $e');
        await _clearSession(prefs);
      }
    } else {
      _sessionToken = const Uuid().v4();
      debugPrint('No session loaded, created new sessionToken: $_sessionToken');
    }
    debugPrint(
        'Loaded session: currentUserId = $_currentUserId, userRole = $_userRole, isAdmin = $_isAdmin, avatarUrl = $_currentAvatarUrl, sessionToken = $_sessionToken');
    notifyListeners();
  }

  /// Xóa session từ SharedPreferences
  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove('currentUserId');
    await prefs.remove('userRole');
    await prefs.remove('sessionToken');
    await prefs.remove('isAdmin');
    _currentUserId = null;
    _userRole = null;
    _isAdmin = null;
    _sessionToken = null;
    debugPrint('Session cleared');
  }

  /// Cập nhật header cho SupabaseClient
  void _updateClientHeaders(SupabaseClient client, String? userId, String? sessionToken, bool? isAdmin) {
    final effectiveUserId = userId ?? 'unknown';
    final effectiveSessionToken = sessionToken ?? 'unknown';
    final effectiveIsAdmin = isAdmin ?? false;

    final headers = {
      'app.current_user_id': effectiveUserId,
      'app.session_token': effectiveSessionToken,
      'app.is_admin': effectiveIsAdmin.toString(),
    };
    client.rest.headers.addAll(headers);

    debugPrint(
        'Header set: app.current_user_id = $effectiveUserId, app.session_token = $effectiveSessionToken, app.is_admin = $effectiveIsAdmin');
    debugPrint('All headers: ${client.rest.headers}');
  }

  /// Hash mật khẩu bằng BCrypt
  String _hashPassword(String password) {
    _validatePassword(password);
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Kiểm tra mật khẩu với hash
  bool _checkPassword(String password, String hashedPassword) {
    return BCrypt.checkpw(password, hashedPassword);
  }

  /// Kiểm tra độ mạnh của mật khẩu
  void _validatePassword(String password) {
    if (password.length < 8) {
      throw AuthException(AuthErrorMessages.passwordTooWeak);
    }
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    if (!(hasUppercase && hasLowercase && hasNumber)) {
      throw AuthException(AuthErrorMessages.passwordTooWeak);
    }
  }

  /// Kiểm tra quyền admin
  Future<bool> _checkAdminRights() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('Admin check failed: currentUserId is null or empty');
      throw AuthException('Không thể kiểm tra quyền admin: ID người dùng trống.');
    }
    try {
      final client = Supabase.instance.client;
      _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);
      final response = await client
          .from('users')
          .select('role, is_admin')
          .eq('id', _currentUserId!)
          .maybeSingle();
      debugPrint('Admin check response: $response');
      if (response == null) {
        debugPrint('Admin check failed: User $_currentUserId not found');
        throw AuthException('Không tìm thấy người dùng $_currentUserId.');
      }
      final isAdmin = (response['role'] == 'admin' || response['is_admin'] == true);
      debugPrint('Admin check result for id = $_currentUserId: $isAdmin');
      return isAdmin;
    } catch (e) {
      debugPrint('Admin check error: $e');
      throw AuthException('Lỗi khi kiểm tra quyền admin: $e');
    }
  }

  /// Đăng nhập người dùng
  Future<bool> login(String id, String password) async {
    try {
      final client = Supabase.instance.client;
      _updateClientHeaders(client, null, _sessionToken, null);
      debugPrint('Attempting to login with id: $id');
      final response = await client.from('users').select().eq('id', id).maybeSingle();
      debugPrint('Login response: $response');
      if (response == null) {
        _loginFailureReason = LoginFailureReason.notFound;
        debugPrint('Login failed: User $id not found');
        throw AuthException(AuthErrorMessages.userNotFound);
      }
      final storedPassword = response['password'] as String;
      if (!_checkPassword(password, storedPassword)) {
        _loginFailureReason = LoginFailureReason.wrongPassword;
        debugPrint('Login failed: Wrong password for user $id');
        throw AuthException(AuthErrorMessages.wrongPassword);
      }
      _userRole = response['role'] as String;
      _currentUserId = id;
      _currentAvatarUrl = response['avatar_url'] as String?;
      _isAdmin = response['is_admin'] as bool? ?? (_userRole == 'admin');
      _sessionToken = const Uuid().v4();
      _loginFailureReason = null;

      debugPrint(
          'Login successful: role = $_userRole, currentUserId = $_currentUserId, isAdmin = $_isAdmin, avatarUrl = $_currentAvatarUrl, sessionToken = $_sessionToken');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', _currentUserId!);
      await prefs.setString('userRole', _userRole!);
      await prefs.setString('sessionToken', _sessionToken!);
      await prefs.setBool('isAdmin', _isAdmin!);
      debugPrint('Session saved');

      notifyListeners();
      return true;
    } catch (e) {
      _loginFailureReason = LoginFailureReason.error;
      debugPrint('Login error: $e');
      throw AuthException('Đăng nhập thất bại: $e');
    }
  }

  /// Đổi mật khẩu người dùng
  Future<bool> changePassword(String userId, String newPassword, {String? oldPassword}) async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        debugPrint('Change password failed: currentUserId is null or empty');
        throw AuthException('Không thể đổi mật khẩu: ID người dùng trống.');
      }
      final client = Supabase.instance.client;
      _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);
      debugPrint(
          'Client created with app.current_user_id = $_currentUserId, app.session_token = $_sessionToken, app.is_admin = $_isAdmin, headers: ${client.rest.headers}');

      // Kiểm tra người dùng tồn tại
      final check = await client.from('users').select().eq('id', userId).maybeSingle();
      debugPrint('Change password check response: $check');
      if (check == null) {
        debugPrint('Change password failed: User $userId not found or access denied');
        throw AuthException('Người dùng $userId không tồn tại hoặc không có quyền truy cập.');
      }
      final user = check;
      debugPrint('User data before update: $user');

      debugPrint(
          'Attempting to change password for userId: $userId, currentUserId: $_currentUserId, userRole: $_userRole, isAdmin: $_isAdmin');

      // Kiểm tra quyền và mật khẩu cũ
      if (_currentUserId == userId) {
        if (oldPassword == null) {
          debugPrint('Change password failed: oldPassword is null for user $userId');
          throw AuthException(AuthErrorMessages.oldPasswordRequired);
        }
        final storedPassword = user['password'] as String;
        debugPrint('Old password entered: $oldPassword');
        debugPrint('Stored password hash from database: $storedPassword');
        if (!_checkPassword(oldPassword, storedPassword)) {
          debugPrint('Change password failed: Incorrect old password for user $userId. BCrypt check failed.');
          throw AuthException('Mật khẩu cũ không đúng.');
        }
        debugPrint('Old password verified successfully for user $userId');
      } else if (_isAdmin == true && _currentUserId != userId) {
        debugPrint('Admin authorized to change password for $userId');
      } else {
        debugPrint('Change password failed: Unauthorized for user $_currentUserId to change $userId');
        throw AuthException(AuthErrorMessages.unauthorized);
      }

      // Tạo hash mật khẩu mới
      final newPasswordHash = _hashPassword(newPassword);
      debugPrint('New password hash: $newPasswordHash');

      // Gọi RPC để đổi mật khẩu
      debugPrint('Calling RPC change_user_password for user $userId');
      await client.rpc('change_user_password', params: {
        'p_user_id': userId,
        'p_new_password_hash': newPasswordHash,
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin,
      });

      debugPrint('Password changed successfully for user $userId via RPC');

      // Xóa session nếu người dùng đổi mật khẩu của chính họ
      if (_currentUserId == userId) {
        final prefs = await SharedPreferences.getInstance();
        await _clearSession(prefs);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Change password error: $e');
      if (e.toString().contains('No rows affected')) {
        throw AuthException('Không thể đổi mật khẩu: Không có thay đổi nào được thực hiện.');
      } else if (e.toString().contains('Unauthorized')) {
        throw AuthException('Không thể đổi mật khẩu: Không có quyền truy cập.');
      } else {
        throw AuthException('Không thể đổi mật khẩu: $e');
      }
    }
  }

  /// Tạo người dùng mới (chỉ admin mới có quyền)
  Future<bool> createUser(
    String newId,
    String password,
    String role, {
    required String name,
    required String employeeId,
    required DateTime dateOfBirth,
    required String hometown,
  }) async {
    try {
      if (!(await _checkAdminRights())) {
        debugPrint('Create user failed: Only admin can create users');
        throw AuthException(AuthErrorMessages.onlyAdminCanCreate);
      }
      final client = Supabase.instance.client;
      _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);

      // Tạo hash mật khẩu
      final passwordHash = _hashPassword(password);
      debugPrint('Password hash for new user $newId: $passwordHash');

      // Gọi RPC để tạo người dùng
      debugPrint('Calling RPC create_user for user $newId');
      await client.rpc('create_user', params: {
        'p_new_id': newId,
        'p_password_hash': passwordHash,
        'p_role': role,
        'p_name': name,
        'p_employee_id': employeeId,
        'p_date_of_birth': dateOfBirth.toIso8601String(),
        'p_hometown': hometown,
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin,
      });

      debugPrint('User $newId created successfully via RPC');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Create user error: $e');
      if (e.toString().contains('Only one admin account is allowed')) {
        throw AuthException(AuthErrorMessages.onlyOneAdmin);
      } else if (e.toString().contains('User') && e.toString().contains('already exists')) {
        throw AuthException(AuthErrorMessages.userAlreadyExists);
      } else if (e.toString().contains('Only admin can create users')) {
        throw AuthException(AuthErrorMessages.onlyAdminCanCreate);
      }
      throw AuthException('Không thể tạo tài khoản: $e');
    }
  }

  /// Tải avatar lên và cập nhật URL avatar (ghi đè ảnh cũ)
  Future<String?> uploadAvatar(String userId, String filePath) async {
  try {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('Upload avatar failed: currentUserId is null or empty');
      throw AuthException('Không thể tải ảnh: ID người dùng trống.');
    }
    if (_currentUserId != userId) {
      debugPrint('Upload avatar failed: User $_currentUserId is not authorized to update $userId');
      throw AuthException('Bạn chỉ có thể cập nhật ảnh đại diện của chính mình.');
    }

    final client = Supabase.instance.client;
    _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);

    // Kiểm tra người dùng tồn tại
    final check = await client.from('users').select().eq('id', userId).maybeSingle();
    debugPrint('Upload avatar check response: $check');
    if (check == null) {
      debugPrint('Upload avatar failed: User $userId not found');
      throw AuthException('Người dùng $userId không tồn tại.');
    }

    // Xóa file cũ nếu tồn tại
    final oldAvatarUrl = check['avatar_url'] as String?;
    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      try {
        final oldFileName = path.basename(oldAvatarUrl.split('?')[0]);
        final deleteResponse = await _supabase.storage.from('avatars').remove([oldFileName]);
        debugPrint('Delete old avatar response: $deleteResponse');
        debugPrint('Deleted old avatar: $oldFileName');
      } catch (e) {
        debugPrint('Error deleting old avatar: $e');
        // Tiếp tục tải file mới ngay cả khi xóa file cũ thất bại
      }
    }

    // Tạo tên file duy nhất với timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = 'avatar-$userId-$timestamp.jpg';

    // Tải file mới lên
    final file = File(filePath);
    final fileBytes = await file.readAsBytes();
    debugPrint('Uploading avatar: $fileName, size: ${fileBytes.length} bytes');

    final uploadResponse = await _supabase.storage.from('avatars').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false, // Không cần upsert vì tên file là duy nhất
          ),
        );
    debugPrint('Upload response: $uploadResponse');

    // Lấy URL công khai
    final url = _supabase.storage.from('avatars').getPublicUrl(fileName);
    debugPrint('Avatar uploaded successfully, URL: $url');

    // Gọi RPC để cập nhật avatar_url
    debugPrint('Calling RPC update_user_avatar for user $userId');
    await client.rpc('update_user_avatar', params: {
      'p_user_id': userId,
      'p_avatar_url': url,
      'p_current_user_id': _currentUserId,
    });

    _currentAvatarUrl = url;
    debugPrint('Avatar updated in database for user $userId: $url');
    notifyListeners();
    return url;
  } catch (e) {
    debugPrint('Upload avatar error: $e');
    throw AuthException('Không thể tải ảnh đại diện: $e');
  }
}

  /// Thông báo cập nhật avatar
  void notifyAvatarUpdated(String url) {
    _currentAvatarUrl = url;
    debugPrint('Avatar updated: $url');
    notifyListeners();
  }

  /// Xóa người dùng (chỉ admin mới có quyền)
  Future<bool> deleteUser(String userId) async {
    try {
      if (!(await _checkAdminRights())) {
        debugPrint('Delete user failed: Only admin can delete users');
        throw AuthException(AuthErrorMessages.onlyAdminCanDelete);
      }
      final client = Supabase.instance.client;
      _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);

      // Gọi RPC để xóa người dùng
      debugPrint('Calling RPC delete_user for user $userId');
      final result = await client.rpc('delete_user', params: {
        'p_user_id': userId,
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin,
      });

      debugPrint('RPC delete_user result: $result');
      if (result == null || result == 0) {
        throw AuthException('Không thể xóa tài khoản: Không có thay đổi nào được thực hiện.');
      }

      if (_currentUserId == userId) await logout();
      debugPrint('User $userId deleted successfully via RPC, rows affected: $result');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete user error: $e');
      if (e.toString().contains('Cannot delete the admin account')) {
        throw AuthException(AuthErrorMessages.cannotDeleteAdmin);
      } else if (e.toString().contains('User') && e.toString().contains('not found')) {
        throw AuthException('Không tìm thấy tài khoản $userId.');
      } else if (e.toString().contains('Only admin can delete users')) {
        throw AuthException(AuthErrorMessages.onlyAdminCanDelete);
      }
      throw AuthException('Không thể xóa tài khoản: $e');
    }
  }

  /// Lấy danh sách người dùng (chỉ admin mới có quyền)
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        debugPrint('Fetch users failed: currentUserId is null or empty');
        throw AuthException('Không thể lấy danh sách: ID người dùng trống.');
      }
      if (!(await _checkAdminRights())) {
        debugPrint('Fetch users failed: Only admin can fetch users');
        throw AuthException(AuthErrorMessages.onlyAdminCanFetch);
      }
      final client = Supabase.instance.client;
      _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);
      debugPrint(
          'Fetching users with currentUserId: $_currentUserId, sessionToken: $_sessionToken, isAdmin: $_isAdmin');
      final response = await client.from('users').select().neq('id', 'admin');
      debugPrint('Loaded users: $response');
      return (response as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('Fetch users error: $e');
      throw AuthException('Không thể lấy danh sách người dùng: $e');
    }
  }

  /// Lấy thông tin profile của người dùng hiện tại
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        debugPrint('Fetch profile failed: currentUserId is null or empty');
        throw AuthException('Không thể lấy thông tin: ID người dùng trống.');
      }
      final client = Supabase.instance.client;
      _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);
      debugPrint(
          'Fetching profile for currentUserId: $_currentUserId, sessionToken: $_sessionToken, isAdmin: $_isAdmin, headers: ${client.rest.headers}');
      final response = await client.from('users').select().eq('id', _currentUserId!).maybeSingle();
      debugPrint('Profile fetch response: $response');
      if (response == null) {
        debugPrint('Fetch profile failed: User $_currentUserId not found or RLS restricted');
        throw AuthException('Người dùng $_currentUserId không tồn tại hoặc không có quyền truy cập.');
      }
      _currentAvatarUrl = response['avatar_url'] as String?;
      _isAdmin = response['is_admin'] as bool? ?? (_userRole == 'admin');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdmin', _isAdmin!);
      debugPrint('Fetched profile: $response, isAdmin updated to $_isAdmin');
      return response;
    } catch (e) {
      debugPrint('Fetch profile error: $e');
      throw AuthException('Không thể lấy thông tin cá nhân: $e');
    }
  }

  /// Đăng xuất người dùng
  Future<void> logout() async {
    try {
      _userRole = null;
      _currentUserId = null;
      _currentAvatarUrl = null;
      _isAdmin = null;
      debugPrint('Logout successful');

      final prefs = await SharedPreferences.getInstance();
      await _clearSession(prefs);

      // Tạo sessionToken mới sau khi đăng xuất
      _sessionToken = const Uuid().v4();
      debugPrint('Created new sessionToken after logout: $_sessionToken');

      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      throw AuthException('Không thể đăng xuất: $e');
    }
  }

  /// Kiểm tra header (dùng để debug)
  Future<List<Map<String, dynamic>>> logHeaders() async {
    try {
      final client = Supabase.instance.client;
      _updateClientHeaders(client, _currentUserId, _sessionToken, _isAdmin);
      final response = await client.rpc('log_headers').select();
      debugPrint('Log headers response: $response');
      return (response as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('Log headers error: $e');
      throw AuthException('Không thể kiểm tra header: $e');
    }
  }
}