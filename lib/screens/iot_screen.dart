import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

class IOTScreen extends StatefulWidget {
  const IOTScreen({super.key});

  @override
  State<IOTScreen> createState() => _IOTScreenState();
}

class _IOTScreenState extends State<IOTScreen> with SingleTickerProviderStateMixin {
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
                  Tab(text: 'Dữ liệu'),
                  Tab(text: 'Kết nối WiFi'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    DataTab(),
                    WiFiConnectTab(),
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

class WiFiConnectTab extends StatefulWidget {
  const WiFiConnectTab({super.key});

  @override
  State<WiFiConnectTab> createState() => _WiFiConnectTabState();
}

class _WiFiConnectTabState extends State<WiFiConnectTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> wifiNetworks = [];
  String? selectedSSID;
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchWiFiNetworks();
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  Future<void> fetchWiFiNetworks() async {
    setState(() {
      _isLoading = true;
    });

    const String esp32Ip = "192.168.4.1";
    final String url = "http://$esp32Ip/scan";

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final List<dynamic> networks = json.decode(response.body);
        setState(() {
          wifiNetworks = networks
              .map((network) => {
                    "ssid": network["ssid"].toString(),
                    "rssi": network["rssi"].toString(),
                  })
              .toList();
        });
        _showSnackBar("Lấy danh sách WiFi thành công!", Colors.green);
      } else {
        _showSnackBar("Không thể lấy danh sách WiFi: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e. Vui lòng kết nối lại với ESP32-Config và thử lại.", Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> sendWiFiCredentials() async {
    if (selectedSSID == null || passwordController.text.isEmpty) {
      _showSnackBar("Vui lòng chọn SSID và nhập mật khẩu", Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    const String esp32Ip = "192.168.4.1";
    final String url = "http://$esp32Ip/setwifi";

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          "ssid": selectedSSID,
          "password": passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar("Kết nối WiFi thành công! Vui lòng kết nối lại với WiFi đã chọn.", Colors.green);
        setState(() {
          selectedSSID = null;
          passwordController.clear();
        });
      } else {
        _showSnackBar("Không thể gửi thông tin WiFi: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e", Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kết nối WiFi cho ESP32:',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hướng dẫn: Kết nối với Access Point "ESP32-Config" (mật khẩu: 12345678) trước khi cấu hình WiFi.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn mạng WiFi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _isLoading && wifiNetworks.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedSSID,
                          hint: const Text("Chọn SSID"),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: wifiNetworks.map((network) {
                            return DropdownMenuItem<String>(
                              value: network["ssid"],
                              child: Text("${network['ssid']} (RSSI: ${network['rssi']})"),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSSID = value;
                            });
                          },
                        ),
                  const SizedBox(height: 16),
                  const Text('Mật khẩu WiFi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color.fromARGB(255, 2, 46, 50),
                        ),
                        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : fetchWiFiNetworks,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 50),
                    backgroundColor: const Color.fromARGB(255, 2, 46, 50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Làm mới danh sách', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : sendWiFiCredentials,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 50),
                    backgroundColor: const Color.fromARGB(255, 2, 46, 50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Kết nối WiFi', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DataTab extends StatefulWidget {
  const DataTab({super.key});

  @override
  State<DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<DataTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  List<Map<String, dynamic>> sensorData = [];
  List<Map<String, dynamic>> localSensorData = []; // Dữ liệu lưu cục bộ
  int selectedDays = 5; // Mặc định hiển thị 5 ngày
  DateTime? lastUpdate;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLocalData(); // Tải dữ liệu cục bộ
    _fetchSensorData(); // Lấy dữ liệu mới từ Supabase
  }

  // Tải dữ liệu từ Hive
  Future<void> _loadLocalData() async {
    final box = Hive.box('sensor_data');
    final data = box.get('data', defaultValue: []);
    debugPrint('Loaded local data from Hive: $data');
    setState(() {
      localSensorData = List<Map<String, dynamic>>.from(data);
    });
    _cleanLocalData(); // Xóa dữ liệu cũ hơn 5 ngày
  }

  // Lưu dữ liệu vào Hive
  Future<void> _saveLocalData() async {
    final box = Hive.box('sensor_data');
    await box.put('data', localSensorData);
    debugPrint('Saved local data to Hive: $localSensorData');
  }

  // Xóa dữ liệu cục bộ cũ hơn 5 ngày
  void _cleanLocalData() {
    final now = DateTime.now();
    final fiveDaysAgo = now.subtract(const Duration(days: 5));

    localSensorData.removeWhere((data) {
      try {
        final createdAt = DateTime.parse(data['created_at']);
        return createdAt.isBefore(fiveDaysAgo);
      } catch (e) {
        debugPrint('Error parsing created_at in cleanLocalData: $e');
        return true; // Xóa dữ liệu nếu không parse được
      }
    });

    _saveLocalData(); // Lưu lại dữ liệu sau khi xóa
  }

  // Lấy dữ liệu từ Supabase và đồng bộ với local storage
  Future<void> _fetchSensorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy dữ liệu từ Supabase (1 ngày gần nhất)
      final response = await Supabase.instance.client
          .from('iot_data')
          .select()
          .gte('created_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
          .order('created_at', ascending: true);

      if (response.isEmpty) {
        _showSnackBar("Không có dữ liệu mới trong bảng iot_data", Colors.orange);
      } else {
        final newData = List<Map<String, dynamic>>.from(response);
        debugPrint("Số bản ghi lấy được từ Supabase: ${newData.length}");
        // Đồng bộ với local storage
        _syncWithLocalData(newData);
        _showSnackBar("Lấy dữ liệu thành công! (${newData.length} bản ghi mới)", Colors.green);
      }
    } catch (e) {
      _showSnackBar("Lỗi khi lấy dữ liệu: $e", Colors.red);
      debugPrint("Supabase error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Đồng bộ dữ liệu từ Supabase với local storage
  void _syncWithLocalData(List<Map<String, dynamic>> newData) {
    // Thêm dữ liệu mới từ Supabase vào local storage
    for (var data in newData) {
      final createdAt = data['created_at'];
      // Kiểm tra xem dữ liệu đã tồn tại trong local storage chưa
      final exists = localSensorData.any((d) => d['created_at'] == createdAt);
      if (!exists) {
        localSensorData.add(data);
      }
    }

    // Sắp xếp theo created_at
    localSensorData.sort((a, b) {
      try {
        return DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']));
      } catch (e) {
        debugPrint('Error sorting localSensorData: $e');
        return 0;
      }
    });

    // Xóa dữ liệu cũ hơn 5 ngày
    _cleanLocalData();

    // Cập nhật sensorData để hiển thị theo số ngày được chọn
    _filterDataByDays();
  }

  // Lọc dữ liệu theo số ngày được chọn
  void _filterDataByDays() {
    final now = DateTime.now();
    final daysAgo = now.subtract(Duration(days: selectedDays));
    setState(() {
      sensorData = localSensorData.where((data) {
        try {
          return DateTime.parse(data['created_at']).isAfter(daysAgo);
        } catch (e) {
          debugPrint('Error parsing created_at in filterDataByDays: $e');
          return false;
        }
      }).toList();
      debugPrint('Filtered sensor data: $sensorData');
    });
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

  Widget _buildLineChart({
  required String title,
  required List<FlSpot> spots,
  required double maxY,
  required Color color,
  required List<String> timestamps, // Danh sách thời gian để hiển thị khi chạm
}) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A4A4A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200, // Cung cấp chiều cao cụ thể để tránh lỗi "RenderBox was not laid out"
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.2),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index < 0 || index >= timestamps.length) {
                          return null;
                        }
                        return LineTooltipItem(
                          '${timestamps[index]}\n${spot.y.toStringAsFixed(1)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                    getTooltipColor: (LineBarSpot spot) => Colors.black.withOpacity(0.8), // Sửa thành hàm
                    tooltipRoundedRadius: 8,
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.grey,
                          strokeWidth: 1,
                          dashArray: [5, 5], // Đường nét đứt
                        ),
                        FlDotData(show: false),
                      );
                    }).toList();
                  },
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (event is FlTapUpEvent || event is FlLongPressEnd || event is FlPanEndEvent) {
                      return;
                    }

                    if (event is FlTapDownEvent || event is FlPanUpdateEvent || event is FlLongPressStart || event is FlLongPressMoveUpdate) {
                      final now = DateTime.now();
                      if (lastUpdate != null && now.difference(lastUpdate!).inMilliseconds < 300) {
                        return;
                      }
                      lastUpdate = now;
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 12),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false, // Tắt nhãn trên trục X
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                minX: 0,
                maxX: spots.isNotEmpty ? (spots.length - 1).toDouble() : 0,
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Chuẩn bị dữ liệu cho biểu đồ
    List<FlSpot> soilMoistureSpots = [];
    List<FlSpot> airHumiditySpots = [];
    List<FlSpot> temperatureSpots = [];
    List<String> timestamps = [];

    for (int i = 0; i < sensorData.length; i++) {
      final data = sensorData[i];

      // Kiểm tra và xử lý giá trị null
      double soilMoisture = 0.0;
      double airHumidity = 0.0;
      double temperature = 0.0;

      if (data['soil_moisture'] != null) {
        soilMoisture = (data['soil_moisture'] as num).toDouble();
      }
      if (data['humidity'] != null) {
        airHumidity = (data['humidity'] as num).toDouble();
      }
      if (data['temperature'] != null) {
        temperature = (data['temperature'] as num).toDouble();
      }

      soilMoistureSpots.add(FlSpot(i.toDouble(), soilMoisture));
      airHumiditySpots.add(FlSpot(i.toDouble(), airHumidity));
      temperatureSpots.add(FlSpot(i.toDouble(), temperature));

      // Định dạng thời gian từ created_at, chuyển từ UTC sang múi giờ địa phương (UTC+7)
      try {
        final createdAt = DateTime.parse(data['created_at']);
        final localTime = createdAt.add(const Duration(hours: 7)); // Chuyển sang UTC+7
        final formattedTime = DateFormat('dd/MM HH:mm').format(localTime); // Hiển thị ngày và giờ
        timestamps.add(formattedTime);
      } catch (e) {
        debugPrint('Error parsing created_at for timestamp: $e');
        timestamps.add('Không xác định');
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dữ liệu từ cảm biến:',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
          ),
          const SizedBox(height: 16),
          // Dropdown để chọn khoảng thời gian
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chọn khoảng thời gian:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF4A4A4A)),
              ),
              DropdownButton<int>(
                value: selectedDays,
                items: [1, 2, 3, 4, 5].map((days) {
                  return DropdownMenuItem<int>(
                    value: days,
                    child: Text('$days ngày'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedDays = value;
                      _filterDataByDays(); // Lọc lại dữ liệu
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : sensorData.isEmpty
                  ? const Center(child: Text('Không có dữ liệu cảm biến.'))
                  : Column(
                      children: [
                        _buildLineChart(
                          title: 'Độ ẩm đất (%)',
                          spots: soilMoistureSpots,
                          maxY: 100, 
                          color: const Color(0xFF4A90E2),
                          timestamps: timestamps,
                        ),
                        const SizedBox(height: 16),
                        _buildLineChart(
                          title: 'Độ ẩm (%)',
                          spots: airHumiditySpots,
                          maxY: 100, // 
                          color: const Color(0xFF50E3C2),
                          timestamps: timestamps,
                        ),
                        const SizedBox(height: 16),
                        _buildLineChart(
                          title: 'Nhiệt độ (°C)',
                          spots: temperatureSpots,
                          maxY: 50, // Nhiệt độ tối đa 50°C (có thể điều chỉnh)
                          color: const Color(0xFFFF6B6B),
                          timestamps: timestamps,
                        ),
                      ],
                    ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _fetchSensorData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(150, 50),
                backgroundColor: const Color.fromARGB(255, 2, 46, 50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                  : const Text('Làm mới dữ liệu', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}