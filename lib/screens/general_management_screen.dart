import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class GeneralManagementScreen extends StatefulWidget {
  const GeneralManagementScreen({super.key});

  @override
  State<GeneralManagementScreen> createState() => _GeneralManagementScreenState();
}

class _GeneralManagementScreenState extends State<GeneralManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                  Tab(text: 'Thống kê kho'),
                  Tab(text: 'Thêm hàng hóa'),
                  Tab(text: 'Xuất hàng'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    InventoryStatsTab(),
                    AddItemTab(),
                    ExportItemTab(),
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

class InventoryStatsTab extends StatefulWidget {
  const InventoryStatsTab({super.key});

  @override
  State<InventoryStatsTab> createState() => _InventoryStatsTabState();
}

class _InventoryStatsTabState extends State<InventoryStatsTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = false;
  bool _isSearchVisible = false;
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchItems();
    });
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
  if (!mounted) return;
  setState(() => _isLoading = true);
  try {
    final authProvider = context.read<AuthProvider>();
    final items = await authProvider.getInventoryItems();
    debugPrint('Items fetched in UI: $items'); // Kiểm tra dữ liệu
    if (mounted) {
      setState(() {
        _items = items ?? [];
        _filteredItems = List.from(_items);
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Fetch error details: $e'); // Log lỗi nếu có
    if (mounted) {
      _showSnackBar('Lỗi khi tải dữ liệu kho: $e', Colors.red);
      setState(() {
        _items = [];
        _filteredItems = [];
        _isLoading = false;
      });
    }
  }
}

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleSearch() {
    if (!mounted) return;
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _filteredItems = List.from(_items);
      }
    });
  }

  void _filterItems() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        _filteredItems = _items.where((item) {
          final name = (item['name'] ?? '').toLowerCase();
          final type = (item['type'] ?? '').toLowerCase();
          final quantity = (item['quantity']?.toString() ?? '').toLowerCase();
          final id = (item['id']?.toString() ?? '').toLowerCase();
          return name.contains(query) || type.contains(query) || quantity.contains(query) || id.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('Kho hiện tại đang trống'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final fontSize = totalWidth * 0.018;
        const padding = EdgeInsets.all(16.0);
        const columnRatios = [0.1, 0.3, 0.25, 0.2];

        return SingleChildScrollView(
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
                      'Danh sách hàng hóa trong kho:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    Row(
                      children: [
                        if (_isSearchVisible)
                          SizedBox(
                            width: totalWidth * 0.25,
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Tìm kiếm...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    columnSpacing: totalWidth * 0.02,
                    dataRowHeight: fontSize * 3.0,
                    headingRowHeight: fontSize * 2.2,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
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
                              'Tên hàng',
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
                              'Loại',
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
                              'Số lượng',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize * 0.9),
                            ),
                          ),
                        ),
                        numeric: true,
                      ),
                    ],
                    rows: _filteredItems.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final item = entry.value;
                      final typeLabel = item['type'] == 'crop'
                          ? 'Cây trồng'
                          : item['type'] == 'fertilizer'
                              ? 'Phân bón'
                              : 'Thuốc trừ sâu';
                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              width: totalWidth * columnRatios[0],
                              child: Center(
                                child: Text(
                                  '$index',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: totalWidth * columnRatios[1],
                              child: Center(
                                child: Text(
                                  item['name'] ?? 'Không có tên',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: totalWidth * columnRatios[2],
                              child: Center(
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              width: totalWidth * columnRatios[3],
                              child: Center(
                                child: Text(
                                  '${item['quantity']?.toString() ?? '0'} ${item['type'] == 'crop' ? 'cây' : 'kg/lít'}',
                                  style: TextStyle(fontSize: fontSize * 0.8),
                                  overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }
}

class AddItemTab extends StatefulWidget {
  const AddItemTab({super.key});

  @override
  State<AddItemTab> createState() => _AddItemTabState();
}

class _AddItemTabState extends State<AddItemTab> with AutomaticKeepAliveClientMixin {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  String _selectedType = '';
  bool _isTypeSelected = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];
  String? _selectedItemId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadItems();
    });
    _idController.addListener(() {
      final currentValue = _idController.text;
      final prefix = _getPrefix(_selectedType);
      if (currentValue.length < prefix.length || !currentValue.startsWith(prefix)) {
        final newValue = prefix + (currentValue.length > prefix.length ? currentValue.substring(prefix.length) : '');
        _idController.value = _idController.value.copyWith(
          text: newValue,
          selection: TextSelection.collapsed(offset: newValue.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final items = await authProvider.getInventoryItems();
      if (mounted) {
        setState(() {
          _items = items ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi khi tải danh sách vật phẩm: $e', Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _isItemSelected() {
    if (_selectedItemId == null) {
      _showSnackBar('Vui lòng chọn vật phẩm để chỉnh sửa hoặc xóa!', Colors.orange);
      return false;
    }
    return true;
  }

  Future<void> _handleCreateItem() async {
    if (!mounted) return;
    if (!_isTypeSelected) {
      _showSnackBar('Vui lòng chọn loại vật phẩm trước!', Colors.orange);
      return;
    }

    final idText = _idController.text.trim();
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());

    if (idText.isEmpty || name.isEmpty || quantity == null || quantity <= 0) {
      _showSnackBar('Vui lòng nhập đầy đủ thông tin và số lượng hợp lệ (> 0)!', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final exists = await authProvider.isInventoryItemExists(idText);

      if (exists) {
        final currentItem = _items.firstWhere((item) => item['id'] == idText, orElse: () => {});
        final currentQuantity = currentItem.isNotEmpty ? (currentItem['quantity'] ?? 0) : 0;
        final newQuantity = currentQuantity + quantity;
        final success = await authProvider.updateInventoryItem(
          id: idText,
          name: name,
          type: _selectedType,
          quantity: newQuantity,
        );
        if (mounted) {
          if (success) {
            _showSnackBar('Cập nhật số lượng thành công!', Colors.green);
            _resetFields();
            await _loadItems();
          } else {
            _showSnackBar('Cập nhật số lượng thất bại! Vui lòng kiểm tra dữ liệu.', Colors.red);
          }
        }
      } else {
        debugPrint('Creating new item: id=$idText, name=$name, type=$_selectedType, quantity=$quantity');
        final success = await authProvider.createInventoryItem(
          id: idText,
          name: name,
          type: _selectedType,
          quantity: quantity,
        );
        if (mounted) {
          if (success) {
            _showSnackBar('Thêm vật phẩm thành công!', Colors.green);
            _resetFields();
            await _loadItems();
          } else {
            _showSnackBar('Thêm vật phẩm thất bại! Vui lòng kiểm tra ID hoặc dữ liệu.', Colors.red);
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi khi thêm/cập nhật vật phẩm: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateItem() async {
    if (!mounted) return;
    if (!_isItemSelected()) return;

    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim());

    if (name.isEmpty || quantity == null || quantity <= 0) {
      _showSnackBar('Vui lòng nhập đầy đủ thông tin và số lượng hợp lệ (> 0)!', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.updateInventoryItem(
        id: _selectedItemId!,
        name: name,
        type: _selectedType,
        quantity: quantity,
      );
      if (mounted) {
        if (success) {
          _showSnackBar('Cập nhật vật phẩm thành công!', Colors.green);
          _resetFields();
          await _loadItems();
        } else {
          _showSnackBar('Cập nhật vật phẩm thất bại!', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi khi cập nhật vật phẩm: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteItem() async {
    if (!mounted) return;
    if (!_isItemSelected()) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa vật phẩm này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.deleteInventoryItem(_selectedItemId!);
      if (mounted) {
        if (success) {
          _showSnackBar('Xóa vật phẩm thành công!', Colors.green);
          _resetFields();
          await _loadItems();
        } else {
          _showSnackBar('Xóa vật phẩm thất bại!', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi khi xóa vật phẩm: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetFields() {
    _idController.clear();
    _nameController.clear();
    _quantityController.clear();
    _selectedType = '';
    _isTypeSelected = false;
    _selectedItemId = null;
  }

  String _getPrefix(String type) {
    switch (type) {
      case 'crop':
        return 'CT-';
      case 'fertilizer':
        return 'PB-';
      case 'pesticide':
        return 'TTS-';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thêm vật phẩm mới:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType.isNotEmpty ? _selectedType : null,
            hint: const Text('Chọn loại vật phẩm'),
            decoration: const InputDecoration(
              labelText: 'Loại vật phẩm',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                  _isTypeSelected = true;
                  _idController.text = _getPrefix(value);
                });
              }
            },
            items: const [
              DropdownMenuItem(value: 'crop', child: Text('Cây trồng')),
              DropdownMenuItem(value: 'fertilizer', child: Text('Phân bón')),
              DropdownMenuItem(value: 'pesticide', child: Text('Thuốc trừ sâu')),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _idController,
            enabled: _isTypeSelected,
            decoration: const InputDecoration(
              labelText: 'ID vật phẩm',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: _isTypeSelected,
            decoration: const InputDecoration(
              labelText: 'Tên vật phẩm',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            enabled: _isTypeSelected,
            decoration: const InputDecoration(
              labelText: 'Số lượng (kg/lít/cây)',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isTypeSelected ? _handleCreateItem : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: const Color.fromARGB(255, 2, 46, 50),
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              disabledBackgroundColor: Colors.grey,
            ),
            child: const Text('Thêm vật phẩm', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chọn vật phẩm để chỉnh sửa/xóa:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedItemId,
            hint: const Text('Chọn vật phẩm'),
            decoration: const InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              errorBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedItemId = value;
                  final item = _items.firstWhere((item) => item['id'].toString() == value);
                  _idController.text = item['id'].toString();
                  _nameController.text = item['name'] ?? '';
                  _quantityController.text = item['quantity']?.toString() ?? '';
                  _selectedType = item['type'] ?? '';
                  _isTypeSelected = true;
                });
              }
            },
            items: _items.isEmpty
                ? [const DropdownMenuItem(child: Text('Không có vật phẩm nào'))]
                : _items.map<DropdownMenuItem<String>>((item) {
                    return DropdownMenuItem<String>(
                      value: item['id'].toString(),
                      child: Text('${item['name'] ?? 'Không có tên'} (${item['type'] ?? 'Không xác định'})'),
                    );
                  }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedItemId != null ? _handleUpdateItem : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: const Color.fromARGB(255, 2, 46, 50),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text('Cập nhật vật phẩm', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedItemId != null ? _handleDeleteItem : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: const Text('Xóa vật phẩm', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ExportItemTab extends StatefulWidget {
  const ExportItemTab({super.key});

  @override
  State<ExportItemTab> createState() => _ExportItemTabState();
}

class _ExportItemTabState extends State<ExportItemTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Tính năng xuất hàng sẽ được phát triển trong tương lai.\nVui lòng kiểm tra lại sau!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Color(0xFF4A4A4A)),
      ),
    );
  }
}