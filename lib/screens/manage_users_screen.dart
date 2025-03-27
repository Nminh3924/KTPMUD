import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> with SingleTickerProviderStateMixin {
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
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.userRole != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chỉ admin mới được truy cập màn hình này!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Padding(
        padding: const EdgeInsets.all(24.0), // Padding cố định từ code mới
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8), // Bo viền từ code mới
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Padding từ code mới
                labelColor: const Color.fromARGB(255, 2, 46, 50),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color.fromARGB(255, 2, 46, 50),
                labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 16),
                tabs: const [
                  Tab(text: 'Quản lý'),
                  Tab(text: 'Thêm nhân sự'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    ManageUsersTab(),
                    AddUserTab(),
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

class AddUserTab extends StatefulWidget {
  const AddUserTab({super.key});

  @override
  State<AddUserTab> createState() => _AddUserTabState();
}

class _AddUserTabState extends State<AddUserTab> with AutomaticKeepAliveClientMixin {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _hometownController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = '';
  String? _selectedUserId;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _isRoleSelected = false;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsers();

    _employeeIdController.addListener(() {
      String currentValue = _employeeIdController.text;
      String prefix = _selectedRole == 'caretaker' ? 'NV' : 'KS';

      if (currentValue.length < 2 || !currentValue.startsWith(prefix)) {
        String newValue = prefix + (currentValue.length > 2 ? currentValue.substring(2) : '');
        _employeeIdController.value = _employeeIdController.value.copyWith(
          text: newValue,
          selection: TextSelection.collapsed(offset: newValue.length),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_users.isEmpty) {
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _employeeIdController.dispose();
    _dateOfBirthController.dispose();
    _hometownController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isUserSelected() {
    if (_selectedUserId == null) {
      _showSnackBar('Vui lòng chọn người dùng để thực hiện hành động!', Colors.orange);
      return false;
    }
    return true;
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final users = await authProvider.getUsers();
      if (mounted) {
        setState(() {
          _users = (users as List<dynamic>).map((user) {
            return {
              'id': user['id'] ?? 'Unknown ID',
              'name': user['name'] ?? 'No Name',
              'role': user['role'] ?? 'Unknown Role',
              'avatar_url': user['avatar_url'],
              'employee_id': user['employee_id'] ?? 'No Employee ID',
              'date_of_birth': user['date_of_birth'],
              'hometown': user['hometown'] ?? 'No Hometown',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
        _showSnackBar('Lỗi khi tải danh sách người dùng: $e', Colors.red);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleCreateUser() async {
    final authProvider = context.read<AuthProvider>();
    final employeeId = _employeeIdController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final dateOfBirthText = _dateOfBirthController.text.trim();
    final hometown = _hometownController.text.trim();

    if (!_isRoleSelected) {
      _showSnackBar('Vui lòng chọn vai trò trước!', Colors.orange);
      return;
    }

    if (employeeId.isEmpty || name.isEmpty || password.isEmpty || dateOfBirthText.isEmpty || hometown.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ thông tin!', Colors.orange);
      return;
    }

    DateTime? dateOfBirth;
    try {
      dateOfBirth = DateTime.parse(dateOfBirthText);
    } catch (e) {
      _showSnackBar('Ngày sinh không hợp lệ!', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final success = await authProvider.createUser(
        employeeId,
        password,
        _selectedRole,
        name: name,
        employeeId: employeeId,
        dateOfBirth: dateOfBirth,
        hometown: hometown,
      );
      if (mounted) {
        if (success) {
          _showSnackBar('Tạo tài khoản thành công!', Colors.green);
          _employeeIdController.clear();
          _nameController.clear();
          _passwordController.clear();
          _dateOfBirthController.clear();
          _hometownController.clear();
          await _loadUsers();
        } else {
          _showSnackBar('Tạo tài khoản thất bại!', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteUser() async {
    if (!_isUserSelected()) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: const Text('Bạn có chắc muốn xoá tài khoản này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.deleteUser(_selectedUserId!);
      if (success && mounted) {
        _showSnackBar('Xoá tài khoản thành công!', Colors.green);
        setState(() => _selectedUserId = null);
        await _loadUsers();
        if (authProvider.currentUserId == _selectedUserId) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else if (mounted) {
        _showSnackBar('Xoá tài khoản thất bại!', Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_isUserSelected()) return;

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      _showSnackBar('Vui lòng nhập mật khẩu mới!', Colors.orange);
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('Mật khẩu mới phải có ít nhất 6 ký tự!', Colors.orange);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('Mật khẩu mới và mật khẩu xác nhận không khớp!', Colors.orange);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.changePassword(
        _selectedUserId!,
        newPassword,
        oldPassword: null,
      );
      if (success && mounted) {
        _showSnackBar('Đổi mật khẩu thành công!', Colors.green);
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        if (authProvider.currentUserId == _selectedUserId) {
          await authProvider.logout();
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          await _loadUsers();
        }
      } else if (mounted) {
        _showSnackBar('Đổi mật khẩu thất bại!', Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi khi đổi mật khẩu: $e', Colors.red);
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

  void _updateEmployeeIdPrefix(String newRole) {
    String prefix = newRole == 'caretaker' ? 'NV' : 'KS';
    String currentId = _employeeIdController.text;

    if (currentId.isEmpty || currentId.length < 2) {
      _employeeIdController.text = prefix;
    } else {
      String newId = prefix + (currentId.length > 2 ? currentId.substring(2) : '');
      _employeeIdController.text = newId;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = context.watch<AuthProvider>();

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào, ${authProvider.currentUserId ?? 'Unknown'} (${authProvider.userRole ?? 'Unknown'})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tạo tài khoản mới:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole.isEmpty ? null : _selectedRole,
            hint: const Text('Chọn vai trò'),
            decoration: InputDecoration(
              labelText: 'Vai trò',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedRole = value;
                  _isRoleSelected = true;
                  _updateEmployeeIdPrefix(value);
                });
              }
            },
            items: const [
              DropdownMenuItem(value: 'engineer', child: Text('Kỹ sư')),
              DropdownMenuItem(value: 'caretaker', child: Text('Nhân viên chăm sóc')),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _employeeIdController,
            enabled: _isRoleSelected,
            decoration: InputDecoration(
              labelText: 'Mã số nhân viên (ID)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: _isRoleSelected,
            decoration: InputDecoration(
              labelText: 'Tên người dùng',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            enabled: _isRoleSelected,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dateOfBirthController,
            enabled: _isRoleSelected,
            decoration: InputDecoration(
              labelText: 'Ngày tháng năm sinh (YYYY-MM-DD)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            readOnly: true,
            onTap: _isRoleSelected ? () => _selectDate(context) : null,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hometownController,
            enabled: _isRoleSelected,
            decoration: InputDecoration(
              labelText: 'Quê quán',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isRoleSelected ? _handleCreateUser : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: const Color.fromARGB(255, 2, 46, 50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tạo tài khoản', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chọn người dùng để quản lý:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedUserId,
            hint: const Text('Chọn người dùng'),
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedUserId = value;
                });
              }
            },
            items: _users.isEmpty
                ? [const DropdownMenuItem(child: Text('Không có người dùng nào'))]
                : _users.map<DropdownMenuItem<String>>((user) {
                    return DropdownMenuItem<String>(
                      value: user['id'] as String,
                      child: Row(
                        children: [
                          user['avatar_url'] != null
                              ? CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(user['avatar_url'] as String),
                                )
                              : const CircleAvatar(radius: 16, child: Icon(Icons.person)),
                          const SizedBox(width: 8),
                          Text('${user['name'] ?? 'No Name'} (${user['id']} - ${user['role']})'),
                        ],
                      ),
                    );
                  }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chỉnh sửa thông tin:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordController,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(
                  color: Color.fromARGB(255, 2, 46, 50),
                  width: 1.5,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                  color: const Color.fromARGB(255, 2, 46, 50),
                ),
                onPressed: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
            ),
            obscureText: _obscureNewPassword,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Xác nhận mật khẩu mới',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(
                  color: Color.fromARGB(255, 2, 46, 50),
                  width: 1.5,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  color: const Color.fromARGB(255, 2, 46, 50),
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            obscureText: _obscureConfirmPassword,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleChangePassword,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: const Color.fromARGB(255, 2, 46, 50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleDeleteUser,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Xoá tài khoản', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ManageUsersTab extends StatefulWidget {
  const ManageUsersTab({super.key});

  @override
  State<ManageUsersTab> createState() => _ManageUsersTabState();
}

class _ManageUsersTabState extends State<ManageUsersTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = false;
  Map<String, dynamic>? _selectedUser;
  bool _isSearchVisible = false;
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final users = await authProvider.getUsers();
      if (mounted) {
        setState(() {
          _users = (users as List<dynamic>).map((user) {
            return {
              'id': user['id'] ?? 'Unknown ID',
              'name': user['name'] ?? 'No Name',
              'role': user['role'] ?? 'Unknown Role',
              'avatar_url': user['avatar_url'],
              'employee_id': user['employee_id'] ?? 'No Employee ID',
              'date_of_birth': user['date_of_birth'],
              'hometown': user['hometown'] ?? 'No Hometown',
            };
          }).toList();
          _filteredUsers = List.from(_users);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = [];
          _filteredUsers = [];
          _isLoading = false;
        });
        _showSnackBar('Lỗi khi tải danh sách người dùng: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
      );
    }
  }

  void _showUserProfile(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
    });
  }

  void _goBack() {
    setState(() {
      _selectedUser = null;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _filteredUsers = List.from(_users);
      }
    });
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          final name = (user['name'] ?? 'No Name').toLowerCase();
          final id = (user['id'] ?? 'Unknown ID').toLowerCase();
          final role = (user['role'] ?? 'Unknown Role').toLowerCase();
          final employeeId = (user['employee_id'] ?? 'No Employee ID').toLowerCase();
          final dateOfBirth = user['date_of_birth'] != null
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(user['date_of_birth'])).toLowerCase()
              : 'Không có';
          final hometown = (user['hometown'] ?? 'No Hometown').toLowerCase();

          return name.contains(query) ||
              id.contains(query) ||
              role.contains(query) ||
              employeeId.contains(query) ||
              dateOfBirth.contains(query) ||
              hometown.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return const Center(child: Text('Không có người dùng nào'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final fontSize = totalWidth * 0.018;
        final padding = const EdgeInsets.all(16); // Padding cố định từ code mới
        const columnRatios = [0.05, 0.23, 0.15, 0.1, 0.15, 0.20]; // Tỷ lệ cột từ code cũ

        return _selectedUser == null
            ? SingleChildScrollView(
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Danh sách người dùng:',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4A4A),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_isSearchVisible)
                                SizedBox(
                                  width: totalWidth * 0.25,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Tìm kiếm...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  _isSearchVisible ? Icons.close : Icons.search,
                                  size: fontSize * 1.5,
                                  color: const Color.fromARGB(255, 2, 46, 50),
                                ),
                                onPressed: _toggleSearch,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: totalWidth * 0.01,
                          dataRowHeight: fontSize * 3.0,
                          headingRowHeight: fontSize * 2.2,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(8), // Bo viền từ code mới
                          ),
                          columns: [
                            DataColumn(
                              label: Container(
                                width: totalWidth * columnRatios[0],
                                child: Center(
                                  child: Text(
                                    'STT',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9),
                                  ),
                                ),
                              ),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Container(
                                width: totalWidth * columnRatios[1],
                                child: Center(
                                  child: Text(
                                    'Tên',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: totalWidth * columnRatios[2],
                                child: Center(
                                  child: Text(
                                    'Vai trò',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: totalWidth * columnRatios[3],
                                child: Center(
                                  child: Text(
                                    'Mã NV',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: totalWidth * columnRatios[4],
                                child: Center(
                                  child: Text(
                                    'Ngày sinh',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: totalWidth * columnRatios[5],
                                child: Center(
                                  child: Text(
                                    'Quê quán',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: _filteredUsers.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final user = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    width: totalWidth * columnRatios[0],
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _showUserProfile(user),
                                        child: Text(
                                          '$index',
                                          style: TextStyle(fontSize: fontSize * 0.8),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: totalWidth * columnRatios[1],
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _showUserProfile(user),
                                        child: Text(
                                          user['name'] ?? 'No Name',
                                          style: TextStyle(fontSize: fontSize * 0.8),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: totalWidth * columnRatios[2],
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _showUserProfile(user),
                                        child: Text(
                                          user['role'] ?? 'Unknown Role',
                                          style: TextStyle(fontSize: fontSize * 0.8),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: totalWidth * columnRatios[3],
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _showUserProfile(user),
                                        child: Text(
                                          user['employee_id'] ?? 'No Employee ID',
                                          style: TextStyle(fontSize: fontSize * 0.8),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: totalWidth * columnRatios[4],
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _showUserProfile(user),
                                        child: Text(
                                          user['date_of_birth'] != null
                                              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(user['date_of_birth']))
                                              : 'Không có',
                                          style: TextStyle(fontSize: fontSize * 0.8),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: totalWidth * columnRatios[5],
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _showUserProfile(user),
                                        child: Text(
                                          user['hometown'] ?? 'No Hometown',
                                          style: TextStyle(fontSize: fontSize * 0.8),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : UserProfileView(user: _selectedUser!, onBack: _goBack);
      },
    );
  }
}

class UserProfileView extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBack;

  const UserProfileView({super.key, required this.user, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final fontSize = totalWidth * 0.018;
        final padding = const EdgeInsets.all(16);

        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: const Color.fromARGB(255, 2, 46, 50), size: fontSize * 1.2),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hồ sơ người dùng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: totalWidth * 0.05),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: totalWidth * 0.08,
                          backgroundImage: user['avatar_url'] != null
                              ? NetworkImage(user['avatar_url'] as String)
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 55),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin cá nhân:',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProfileField('Tên', user['name'] ?? 'Không có tên', fontSize),
                                  const SizedBox(height: 24),
                                  _buildProfileField('Mã số nhân viên', user['employee_id'] ?? 'Không có mã', fontSize),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProfileField(
                                    'Ngày tháng năm sinh',
                                    user['date_of_birth'] != null
                                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(user['date_of_birth']))
                                        : 'Không có ngày sinh',
                                    fontSize,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildProfileField('Quê quán', user['hometown'] ?? 'Không có quê quán', fontSize),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileField(String label, String value, double fontSize) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      );
}