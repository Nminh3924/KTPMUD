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
  // Thuộc tính trạng thái
  String? _userRole;
  String? _currentUserId;
  String? _currentAvatarUrl;
  String? _sessionToken;
  bool? _isAdmin;
  LoginFailureReason? _loginFailureReason;

  // Khởi tạo Supabase và ScaffoldMessengerKey
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // Getter
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey => _scaffoldMessengerKey;
  String? get userRole => _userRole;
  String? get currentUserId => _currentUserId;
  String? get currentAvatarUrl => _currentAvatarUrl;
  bool? get isAdmin => _isAdmin;
  LoginFailureReason? get loginFailureReason => _loginFailureReason;
  bool get isLoggedIn => _currentUserId != null && _sessionToken != null;

  AuthProvider() {
    // Không gọi _loadSavedSession() trong constructor, sẽ gọi trong initialize()
  }

  // Khởi tạo trạng thái từ SharedPreferences
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
        } else if (_userRole != 'admin') {
          await _clearSession(prefs);
        }
      } catch (e) {
        debugPrint('Error loading saved session: $e');
        await _clearSession(prefs);
      }
    } else {
      _sessionToken = const Uuid().v4();
      debugPrint('No session loaded, generated new sessionToken: $_sessionToken');
    }
    debugPrint('Initialized session: currentUserId = $_currentUserId, userRole = $_userRole, isAdmin = $_isAdmin, avatarUrl = $_currentAvatarUrl, sessionToken = $_sessionToken');
    notifyListeners();
  }

  // Xóa session
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
    notifyListeners();
  }

  // Cập nhật header cho client Supabase
  void _updateClientHeaders(SupabaseClient client, String? userId, String? sessionToken, bool? isAdmin) {
  final effectiveUserId = Supabase.instance.client.auth.currentUser?.id ?? userId ?? 'unknown';
  final effectiveSessionToken = sessionToken ?? const Uuid().v4();
  final effectiveIsAdmin = isAdmin ?? false;

  client.rest.headers['app.current_user_id'] = effectiveUserId;
  client.rest.headers['app.session_token'] = effectiveSessionToken;
  client.rest.headers['app.is_admin'] = effectiveIsAdmin.toString();

  debugPrint('Header set: app.current_user_id = $effectiveUserId, app.session_token = $effectiveSessionToken, app.is_admin = $effectiveIsAdmin');
}

  // Xử lý mật khẩu
  String _hashPassword(String password) {
    _validatePassword(password);
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool _checkPassword(String password, String hashedPassword) {
    return BCrypt.checkpw(password, hashedPassword);
  }

  void _validatePassword(String password) {
    if (password.length < 8) {
      throw AuthException(AuthErrorMessages.passwordTooWeak);
    }
    if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])').hasMatch(password)) {
      throw AuthException(AuthErrorMessages.passwordTooWeak);
    }
  }

  // Kiểm tra quyền admin
  Future<bool> _checkAdminRights() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('Admin check failed: currentUserId is null or empty');
      throw AuthException('Không thể kiểm tra quyền admin: ID người dùng trống.');
    }
    try {
      final response = await _supabase
          .from('users')
          .select('role, is_admin')
          .eq('id', _currentUserId!)
          .maybeSingle();
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

  // Đăng nhập
  Future<bool> login(String id, String password) async {
    try {
      _updateClientHeaders(_supabase, null, _sessionToken, null);
      debugPrint('Attempting login with id: $id');
      final response = await _supabase.from('users').select().eq('id', id).maybeSingle();
      if (response == null) {
        _loginFailureReason = LoginFailureReason.notFound;
        throw AuthException(AuthErrorMessages.userNotFound);
      }
      final storedPassword = response['password'] as String;
      if (!_checkPassword(password, storedPassword)) {
        _loginFailureReason = LoginFailureReason.wrongPassword;
        throw AuthException(AuthErrorMessages.wrongPassword);
      }
      _userRole = response['role'] as String;
      _currentUserId = id;
      _currentAvatarUrl = response['avatar_url'] as String?;
      _isAdmin = response['is_admin'] as bool? ?? (_userRole == 'admin');
      _sessionToken = const Uuid().v4();
      _loginFailureReason = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', _currentUserId!);
      await prefs.setString('userRole', _userRole!);
      await prefs.setString('sessionToken', _sessionToken!);
      await prefs.setBool('isAdmin', _isAdmin!);
      debugPrint('Login successful: role = $_userRole, currentUserId = $_currentUserId, isAdmin = $_isAdmin, avatarUrl = $_currentAvatarUrl, sessionToken = $_sessionToken');

      notifyListeners();
      return true;
    } catch (e) {
      _loginFailureReason = LoginFailureReason.error;
      throw AuthException('Đăng nhập thất bại: $e');
    }
  }

  // Đổi mật khẩu
  Future<bool> changePassword(String userId, String newPassword, {String? oldPassword}) async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        throw AuthException('Không thể đổi mật khẩu: ID người dùng trống.');
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);

      final check = await _supabase.from('users').select().eq('id', userId).maybeSingle();
      if (check == null) {
        throw AuthException('Người dùng $userId không tồn tại hoặc không có quyền truy cập.');
      }

      if (_currentUserId == userId) {
        if (oldPassword == null) {
          throw AuthException(AuthErrorMessages.oldPasswordRequired);
        }
        final storedPassword = check['password'] as String;
        if (!_checkPassword(oldPassword, storedPassword)) {
          throw AuthException('Mật khẩu cũ không đúng.');
        }
      } else if (_isAdmin != true) {
        throw AuthException(AuthErrorMessages.unauthorized);
      }

      final newPasswordHash = _hashPassword(newPassword);
      await _supabase.rpc('change_user_password', params: {
        'p_user_id': userId,
        'p_new_password_hash': newPasswordHash,
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin,
      });

      if (_currentUserId == userId) {
        final prefs = await SharedPreferences.getInstance();
        await _clearSession(prefs);
      }

      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('No rows affected')) {
        throw AuthException('Không thể đổi mật khẩu: Không có thay đổi nào được thực hiện.');
      } else if (e.toString().contains('Unauthorized')) {
        throw AuthException('Không thể đổi mật khẩu: Không có quyền truy cập.');
      }
      throw AuthException('Không thể đổi mật khẩu: $e');
    }
  }

  // Tạo người dùng
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
        throw AuthException(AuthErrorMessages.onlyAdminCanCreate);
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);

      final passwordHash = _hashPassword(password);
      await _supabase.rpc('create_user', params: {
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

      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('Only one admin account is allowed')) {
        throw AuthException(AuthErrorMessages.onlyOneAdmin);
      } else if (e.toString().contains('User') && e.toString().contains('already exists')) {
        throw AuthException(AuthErrorMessages.userAlreadyExists);
      }
      throw AuthException('Không thể tạo tài khoản: $e');
    }
  }

  // Tải ảnh đại diện
  Future<String?> uploadAvatar(String userId, String filePath) async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        throw AuthException('Không thể tải ảnh: ID người dùng trống.');
      }
      if (_currentUserId != userId) {
        throw AuthException('Bạn chỉ có thể cập nhật ảnh đại diện của chính mình.');
      }

      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);

      final check = await _supabase.from('users').select().eq('id', userId).maybeSingle();
      if (check == null) {
        throw AuthException('Người dùng $userId không tồn tại.');
      }

      final oldAvatarUrl = check['avatar_url'] as String?;
      if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
        try {
          final oldFileName = path.basename(oldAvatarUrl.split('?')[0]);
          await _supabase.storage.from('avatars').remove([oldFileName]);
        } catch (e) {
          // Bỏ qua lỗi nếu xóa thất bại
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'avatar-$userId-$timestamp.jpg';
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();

      await _supabase.storage.from('avatars').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
          );

      final url = _supabase.storage.from('avatars').getPublicUrl(fileName);
      await _supabase.rpc('update_user_avatar', params: {
        'p_user_id': userId,
        'p_avatar_url': url,
        'p_current_user_id': _currentUserId,
      });

      _currentAvatarUrl = url;
      notifyListeners();
      return url;
    } catch (e) {
      throw AuthException('Không thể tải ảnh đại diện: $e');
    }
  }

  void notifyAvatarUpdated(String url) {
    _currentAvatarUrl = url;
    notifyListeners();
  }

  // Xóa người dùng
  Future<bool> deleteUser(String userId) async {
    try {
      if (!(await _checkAdminRights())) {
        throw AuthException(AuthErrorMessages.onlyAdminCanDelete);
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);

      final result = await _supabase.rpc('delete_user', params: {
        'p_user_id': userId,
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin,
      });

      if (result == null || result == 0) {
        throw AuthException('Không thể xóa tài khoản: Không có thay đổi nào được thực hiện.');
      }

      if (_currentUserId == userId) await logout();
      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('Cannot delete the admin account')) {
        throw AuthException(AuthErrorMessages.cannotDeleteAdmin);
      } else if (e.toString().contains('User') && e.toString().contains('not found')) {
        throw AuthException('Không tìm thấy tài khoản $userId.');
      }
      throw AuthException('Không thể xóa tài khoản: $e');
    }
  }

  // Lấy danh sách người dùng
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        throw AuthException('Không thể lấy danh sách: ID người dùng trống.');
      }
      if (!(await _checkAdminRights())) {
        throw AuthException(AuthErrorMessages.onlyAdminCanFetch);
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
      final response = await _supabase.from('users').select().neq('id', 'admin');
      return (response as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      throw AuthException('Không thể lấy danh sách người dùng: $e');
    }
  }

  // Lấy thông tin người dùng hiện tại
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        throw AuthException('Không thể lấy thông tin: ID người dùng trống.');
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
      final response = await _supabase.from('users').select().eq('id', _currentUserId!).maybeSingle();
      if (response == null) {
        throw AuthException('Người dùng $_currentUserId không tồn tại hoặc không có quyền truy cập.');
      }
      _currentAvatarUrl = response['avatar_url'] as String?;
      _isAdmin = response['is_admin'] as bool? ?? (_userRole == 'admin');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdmin', _isAdmin!);
      return response;
    } catch (e) {
      throw AuthException('Không thể lấy thông tin cá nhân: $e');
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _clearSession(prefs);
      _sessionToken = const Uuid().v4();
      notifyListeners();
    } catch (e) {
      throw AuthException('Không thể đăng xuất: $e');
    }
  }

  // Lấy log header
  Future<List<Map<String, dynamic>>> logHeaders() async {
    try {
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
      final response = await _supabase.rpc('log_headers').select();
      return (response as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      throw AuthException('Không thể kiểm tra header: $e');
    }
  }

  // Lấy danh sách vật phẩm trong kho
  Future<List<Map<String, dynamic>>> getInventoryItems() async {
  try {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('Fetch inventory failed: currentUserId is null or empty');
      throw AuthException('Không thể lấy danh sách: ID người dùng trống.');
    }
    _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
    debugPrint('Calling get_inventory_items with p_current_user_id: $_currentUserId, p_is_admin: ${_isAdmin ?? false}');
    final response = await _supabase.rpc('get_inventory_items', params: {
      'p_current_user_id': _currentUserId,
      'p_is_admin': _isAdmin ?? false,
    });

    if (response is! List) {
      debugPrint('Unexpected response type: $response');
      throw AuthException('Phản hồi từ Supabase không hợp lệ: $response');
    }
    
    final items = (response as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    debugPrint('Items from Supabase: $items');
    return items;
  } catch (e) {
    debugPrint('Fetch inventory error: $e');
    if (e is PostgrestException) {
      debugPrint('Supabase exception: ${e.message}, details: ${e.details}');
    }
    throw AuthException('Không thể lấy danh sách vật phẩm: $e');
  }
}

  // Thêm hoặc cập nhật vật phẩm trong kho
  Future<bool> createInventoryItem({required String id, required String name, required String type, required double quantity, String? productCode}) async {
    try {
      if (id.isEmpty) {
        debugPrint('Error: id is empty');
        throw AuthException('ID không được để trống.');
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
      final response = await _supabase.rpc('create_or_update_inventory', params: {
        'p_id': id.trim(),
        'p_name': name.trim(),
        'p_type': type.trim(),
        'p_quantity': quantity,
        'p_product_code': productCode?.trim(),
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin ?? false,
      });
      if (response == null || (response is! String && response != true)) {
        debugPrint('Invalid response from Supabase: $response');
        throw AuthException('Lỗi khi thêm vật phẩm: Phản hồi không hợp lệ.');
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Create Error: $e');
      throw AuthException('Không thể thêm vật phẩm: $e');
    }
  }

  // Cập nhật vật phẩm trong kho
  Future<bool> updateInventoryItem({required String id, required String name, required String type, required double quantity, String? productCode}) async {
    try {
      if (id.isEmpty) {
        debugPrint('Error: id is empty');
        throw AuthException('ID không được để trống.');
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
      final response = await _supabase.rpc('update_inventory_item', params: {
        'p_id': id.trim(),
        'p_name': name.trim(),
        'p_type': type.trim(),
        'p_quantity': quantity,
        'p_product_code': productCode?.trim(),
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin ?? false,
      });
      if (response == null || response !is String) {
        debugPrint('Invalid response from Supabase: $response');
        throw AuthException('Lỗi khi cập nhật vật phẩm: Phản hồi không hợp lệ.');
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Update Error: $e');
      throw AuthException('Không thể cập nhật vật phẩm: $e');
    }
  }

  // Xóa vật phẩm trong kho
  Future<bool> deleteInventoryItem(String id) async {
    try {
      if (id.isEmpty) {
        debugPrint('Error: id is empty');
        throw AuthException('ID không được để trống.');
      }
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
      final response = await _supabase.rpc('delete_inventory_item', params: {
        'p_id': id.trim(),
        'p_current_user_id': _currentUserId,
        'p_is_admin': _isAdmin ?? false,
      });
      if (response == null || response !is String) {
        debugPrint('Invalid response from Supabase: $response');
        throw AuthException('Lỗi khi xóa vật phẩm: Phản hồi không hợp lệ.');
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete Error: $e');
      throw AuthException('Không thể xóa vật phẩm: $e');
    }
  }

  // Kiểm tra xem vật phẩm có tồn tại
  Future<bool> isInventoryItemExists(String id) async {
    try {
      _updateClientHeaders(_supabase, _currentUserId, _sessionToken, _isAdmin);
      final response = await _supabase
          .from('inventory')
          .select('id')
          .eq('id', id.trim())
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Error checking inventory item existence: $e');
      return false;
    }
  }
}