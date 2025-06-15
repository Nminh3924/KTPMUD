import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LandManagementScreen extends StatefulWidget {
  const LandManagementScreen({super.key});

  @override
  State<LandManagementScreen> createState() => _LandManagementScreenState();
}

class _LandManagementScreenState extends State<LandManagementScreen> {
  List<Map<String, dynamic>> _lands = [];
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final lands = await authProvider.getLands();
      final items = await authProvider.getInventoryItems();
      if (mounted) {
        setState(() {
          _lands = lands ?? [];
          _inventoryItems = items ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi khi tải dữ liệu lô đất: $e', Colors.red);
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

  Future<void> _harvestCrop(int landId) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final landIndex = _lands.indexWhere((l) => l['id'] == landId);
      if (landIndex != -1) {
        final land = _lands[landIndex];
        final cropId = land['crop_id'];
        if (cropId != null) {
          final success = await authProvider.harvestCrop(landId: landId);
          if (mounted) {
            if (success) {
              setState(() {
                _lands[landIndex] = {
                  'id': landId,
                  'name': 'Lô $landId',
                  'crop_id': null,
                  'fertilizer_id': null,
                  'pesticide_id': null,
                  'fertilizer_quantity': 0,
                  'pesticide_quantity': 0,
                  'crop_quantity': 0,
                };
              });
              _showSnackBar('Thu hoạch thành công! Lô đất đã được reset.', Colors.green);
            } else {
              _showSnackBar('Thu hoạch thất bại!', Colors.red);
            }
          }
        } else {
          _showSnackBar('Không có cây nào để thu hoạch trong lô này!', Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi khi thu hoạch: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Quản lý lô đất',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 800.0;
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: maxWidth,
                            child: DataTable(
                              columnSpacing: maxWidth * 0.01,
                              dataRowHeight: maxWidth * 0.06,
                              headingRowHeight: maxWidth * 0.05,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              columns: [
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.08,
                                    child: const Center(
                                      child: Text(
                                        'ID Lô đất',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.15, // Điều chỉnh từ 0.2 xuống 0.15
                                    child: const Center(
                                      child: Text(
                                        'Cây trồng',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.08,
                                    child: const Center(
                                      child: Text(
                                        'Số lượng',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.15, // Điều chỉnh từ 0.2 xuống 0.15
                                    child: const Center(
                                      child: Text(
                                        'Phân bón',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.08,
                                    child: const Center(
                                      child: Text(
                                        'Số lượng',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.15, // Điều chỉnh từ 0.2 xuống 0.15
                                    child: const Center(
                                      child: Text(
                                        'Thuốc trừ sâu',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.08,
                                    child: const Center(
                                      child: Text(
                                        'Số lượng',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: maxWidth * 0.1,
                                    child: const Center(
                                      child: Text(
                                        'Thu hoạch',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              rows: List.generate(10, (index) {
                                final land = _lands.firstWhere(
                                  (l) => l['id'] == (index + 1),
                                  orElse: () => {
                                    'id': index + 1,
                                    'name': 'Lô ${index + 1}',
                                    'crop_id': null,
                                    'fertilizer_id': null,
                                    'pesticide_id': null,
                                    'fertilizer_quantity': 0,
                                    'pesticide_quantity': 0,
                                    'crop_quantity': 0
                                  },
                                );
                                final crop = land['crop_id'] != null
                                    ? _inventoryItems.firstWhere(
                                        (item) => item['id'].toString() == land['crop_id'].toString(),
                                        orElse: () => {'name': 'Chưa chọn'},
                                      )
                                    : {'name': 'Chưa chọn'};
                                final fertilizer = land['fertilizer_id'] != null
                                    ? _inventoryItems.firstWhere(
                                        (item) => item['id'].toString() == land['fertilizer_id'].toString(),
                                        orElse: () => {'name': 'Chưa chọn'},
                                      )
                                    : {'name': 'Chưa chọn'};
                                final pesticide = land['pesticide_id'] != null
                                    ? _inventoryItems.firstWhere(
                                        (item) => item['id'].toString() == land['pesticide_id'].toString(),
                                        orElse: () => {'name': 'Chưa chọn'},
                                      )
                                    : {'name': 'Chưa chọn'};

                                return DataRow(cells: [
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.08,
                                      child: Center(
                                        child: Text(
                                          land['id'].toString(),
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.15, // Điều chỉnh từ 0.2 xuống 0.15
                                      child: Center(
                                        child: Text(
                                          crop['name'] ?? 'Chưa chọn',
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.08,
                                      child: Center(
                                        child: Text(
                                          land['crop_quantity'].toString(),
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.15, // Điều chỉnh từ 0.2 xuống 0.15
                                      child: Center(
                                        child: Text(
                                          fertilizer['name'] ?? 'Chưa chọn',
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.08,
                                      child: Center(
                                        child: Text(
                                          land['fertilizer_quantity'].toString(),
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.15, // Điều chỉnh từ 0.2 xuống 0.15
                                      child: Center(
                                        child: Text(
                                          pesticide['name'] ?? 'Chưa chọn',
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.08,
                                      child: Center(
                                        child: Text(
                                          land['pesticide_quantity'].toString(),
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: maxWidth * 0.1,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.agriculture),
                                          onPressed: () => _harvestCrop(land['id']),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]);
                              }),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}