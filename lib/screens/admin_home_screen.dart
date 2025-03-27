import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_layout.dart';
import 'manage_users_screen.dart';
import 'settings_screen.dart';
import 'iot_screen.dart';
import '../widgets/placeholder_content.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const menuItems = [
      {'icon': Icons.dashboard, 'label': 'Tổng quan'},
      {'icon': Icons.person, 'label': 'Nhân sự'},
      {'icon': Icons.trending_up, 'label': 'Sản lượng'},
      {'icon': Icons.account_balance_wallet, 'label': 'Quản lý chung'},
      {'icon': Icons.work, 'label': 'Quy trình'},
      {'icon': Icons.book, 'label': 'Nhật ký canh tác'},
      {'icon': Icons.wifi, 'label': 'IOT'},
      {'icon': Icons.settings, 'label': 'Setting'},
    ];

    final pages = [
      const AdminDashboardContent(),
      const ManageUsersScreen(),
      const PlaceholderContent(title: 'Sản lượng'),
      const PlaceholderContent(title: 'Quản lý chung'),
      const PlaceholderContent(title: 'Quy trình'),
      const PlaceholderContent(title: 'Nhật ký canh tác'),
      const IOTScreen(),
      const SettingsScreen(),
    ];

    return MainLayout(
      role: 'admin',
      menuItems: menuItems,
      pages: pages,
    );
  }
}

class AdminDashboardContent extends StatefulWidget {
  const AdminDashboardContent({super.key});

  @override
  _AdminDashboardContentState createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<AdminDashboardContent>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> sensorData = [];
  Map<String, dynamic>? weatherData;
  int selectedDays = 5;
  bool isLoading = true, isRefreshing = false, isLoadingWeather = false;
  Timer? _weatherRefreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _weatherRefreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (mounted) _fetchWeather();
    });
  }

  @override
  void dispose() {
    _weatherRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await Future.wait([_fetchWeather(), _loadSensorData()]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchWeather() async {
    const apiKey = 'dbdfffa409b4fe43b582bbda01cf879f';
    const city = 'Hanoi';
    final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric');

    try {
      setState(() => isLoadingWeather = true);
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          weatherData = json.decode(response.body);
          isLoadingWeather = false;
        });
      } else {
        _showSnackBar('Không thể tải dữ liệu thời tiết!', Colors.red);
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      if (mounted) {
        _showSnackBar('Lỗi khi tải dữ liệu thời tiết: $e', Colors.red);
        setState(() => isLoadingWeather = false);
      }
    }
  }

  Future<void> _fetchSensorDataFromApi() async {
    try {
      final response = await Supabase.instance.client
          .from('iot_data')
          .select()
          .order('created_at', ascending: false);
      final box = await Hive.openBox('sensor_data');
      await box.put('data', response);
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');
      if (mounted) _showSnackBar('Lỗi khi tải dữ liệu cảm biến: $e', Colors.red);
    }
  }

  Future<void> _loadSensorData() async {
    if (!mounted) return;
    setState(() => isRefreshing = true);
    await _fetchSensorDataFromApi();
    final box = await Hive.openBox('sensor_data');
    final rawData = box.get('data', defaultValue: []);
    final convertedData = (rawData as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();

    if (mounted) {
      setState(() {
        sensorData = List.from(convertedData);
        isRefreshing = false;
      });
      _filterDataByDays();
    }
  }

  void _filterDataByDays() {
    if (sensorData.isEmpty || !mounted) return;
    final now = DateTime.now();
    final daysAgo = now.subtract(Duration(days: selectedDays));
    setState(() {
      sensorData = sensorData.where((data) {
        try {
          final createdAt = DateTime.parse(data['created_at'] as String);
          return createdAt.isAfter(daysAgo) &&
              ((data['soil_moisture'] as num? ?? 0) != 0 ||
                  (data['humidity'] as num? ?? 0) != 0 ||
                  (data['temperature'] as num? ?? 0) != 0);
        } catch (e) {
          debugPrint('Error parsing created_at: $e');
          return false;
        }
      }).toList();
    });
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(fontSize: 16)), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildWeatherCard(),
                      const SizedBox(height: 20),
                      IoTChart(
                        sensorData: sensorData,
                        selectedDays: selectedDays,
                        onDaysChanged: (value) => setState(() {
                          selectedDays = value;
                          _loadSensorData();
                        }),
                        onRefresh: _loadSensorData,
                        isRefreshing: isRefreshing,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWeatherCard() {
    Color startColor = Colors.blue.shade200, endColor = Colors.blue.shade400;
    if (weatherData != null) {
      final weatherCondition = weatherData!['weather'][0]['main'].toString().toLowerCase();
      if (weatherCondition.contains('rain')) {
        startColor = Colors.grey.shade400;
        endColor = Colors.grey.shade600;
      } else if (weatherCondition.contains('clear')) {
        startColor = Colors.yellow.shade300;
        endColor = Colors.orange.shade300;
      } else if (weatherCondition.contains('cloud')) {
        startColor = Colors.grey.shade300;
        endColor = Colors.grey.shade500;
      }
    }

    String sunrise = 'N/A', sunset = 'N/A';
    if (weatherData != null) {
      final sunriseTimestamp = weatherData!['sys']['sunrise'] as int?;
      final sunsetTimestamp = weatherData!['sys']['sunset'] as int?;
      if (sunriseTimestamp != null && sunsetTimestamp != null) {
        sunrise = DateFormat('HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(sunriseTimestamp * 1000).toLocal());
        sunset = DateFormat('HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(sunsetTimestamp * 1000).toLocal());
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 40, // 40 là padding 2 bên (20 + 20)
        ),
        child: IntrinsicWidth(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [startColor, endColor],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min, // Đảm bảo Row không mở rộng hết chiều ngang
                    children: [
                      const Text(
                        'Tình hình thời tiết',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.black54, size: 20),
                        onPressed: _fetchWeather,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: isLoadingWeather
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : Row(
                            mainAxisSize: MainAxisSize.min, // Đảm bảo Row không mở rộng hết chiều ngang
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: weatherData != null
                                      ? Image.network(
                                          'http://openweathermap.org/img/wn/${weatherData!['weather'][0]['icon']}@2x.png',
                                          fit: BoxFit.contain,
                                        )
                                      : const Icon(Icons.cloud, size: 40, color: Colors.white70),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    weatherData != null
                                        ? '${weatherData!['name']}, ${weatherData!['sys']['country']}'
                                        : 'Đang tải...',
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    weatherData != null
                                        ? '${weatherData!['main']['temp'].toStringAsFixed(1)}°C'
                                        : 'N/A',
                                    style: const TextStyle(
                                        fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    weatherData != null
                                        ? 'Cảm giác: ${weatherData!['main']['feels_like'].toStringAsFixed(1)}°C'
                                        : 'N/A',
                                    style: const TextStyle(fontSize: 16, color: Colors.orangeAccent),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    weatherData != null
                                        ? (weatherData!['weather'][0]['description'] as String).toUpperCase()
                                        : 'Không có dữ liệu',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 5),
                                  _buildWeatherDetail(Icons.water_drop, Colors.teal,
                                      'Độ ẩm: ${weatherData != null ? weatherData!['main']['humidity'] : 'N/A'}%'),
                                  const SizedBox(height: 5),
                                  _buildWeatherDetail(Icons.air, Colors.greenAccent,
                                      'Gió: ${weatherData != null ? weatherData!['wind']['speed'] : 'N/A'} m/s'),
                                  const SizedBox(height: 5),
                                  _buildWeatherDetail(Icons.cloud, Colors.blueGrey,
                                      'Mây: ${weatherData != null ? weatherData!['clouds']['all'] : 'N/A'}%'),
                                ],
                              ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildWeatherDetail(
                                      Icons.thermostat,
                                      Colors.redAccent,
                                      'Áp suất: ${weatherData != null ? weatherData!['main']['pressure'] : 'N/A'} hPa'),
                                  const SizedBox(height: 5),
                                  _buildWeatherDetail(
                                      Icons.visibility,
                                      Colors.purpleAccent,
                                      'Tầm nhìn: ${weatherData != null ? (weatherData!['visibility'] / 1000).toStringAsFixed(1) : 'N/A'} km'),
                                  const SizedBox(height: 5),
                                  _buildWeatherDetail(Icons.wb_sunny, Colors.amber, 'Mặt trời mọc: $sunrise'),
                                  const SizedBox(height: 5),
                                  _buildWeatherDetail(
                                      Icons.nights_stay, Colors.indigoAccent, 'Mặt trời lặn: $sunset'),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 16, color: color)),
      ],
    );
  }
}

class IoTChart extends StatefulWidget {
  final List<Map<String, dynamic>> sensorData;
  final int selectedDays;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const IoTChart({
    super.key,
    required this.sensorData,
    required this.selectedDays,
    required this.onDaysChanged,
    required this.onRefresh,
    required this.isRefreshing,
  });

  @override
  _IoTChartState createState() => _IoTChartState();
}

class _IoTChartState extends State<IoTChart> {
  List<FlSpot> soilMoistureSpots = [];
  List<FlSpot> airHumiditySpots = [];
  List<FlSpot> temperatureSpots = [];
  List<String> timestamps = [];

  @override
  void initState() {
    super.initState();
    _prepareChartData();
  }

  @override
  void didUpdateWidget(IoTChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorData != widget.sensorData || oldWidget.isRefreshing != widget.isRefreshing) {
      _prepareChartData();
    }
  }

  void _prepareChartData() {
    soilMoistureSpots.clear();
    airHumiditySpots.clear();
    temperatureSpots.clear();
    timestamps.clear();

    final reversedData = widget.sensorData.reversed.toList();
    for (var i = 0; i < reversedData.length; i++) {
      final data = reversedData[i];
      soilMoistureSpots.add(FlSpot(i.toDouble(), (data['soil_moisture'] as num?)?.toDouble() ?? 0));
      airHumiditySpots.add(FlSpot(i.toDouble(), (data['humidity'] as num?)?.toDouble() ?? 0));
      temperatureSpots.add(FlSpot(i.toDouble(), (data['temperature'] as num?)?.toDouble() ?? 0));
      try {
        final createdAt = DateTime.parse(data['created_at'] as String).add(const Duration(hours: 7));
        timestamps.add(DateFormat('dd/MM HH:mm').format(createdAt));
      } catch (e) {
        debugPrint('Error parsing created_at: $e');
        timestamps.add('Không xác định');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allValues = [...soilMoistureSpots, ...airHumiditySpots, ...temperatureSpots].map((spot) => spot.y);
    final maxY = allValues.isNotEmpty ? allValues.reduce((a, b) => a > b ? a : b) * 1.1 : 100.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dữ liệu cảm biến nông nghiệp',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFF4A4A4A)),
              ),
              Row(
                children: [
                  widget.isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh, color: Color(0xFF4A4A4A), size: 20),
                          onPressed: widget.onRefresh,
                        ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: widget.selectedDays,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 ngày', style: TextStyle(fontSize: 16))),
                      DropdownMenuItem(value: 2, child: Text('2 ngày', style: TextStyle(fontSize: 16))),
                      DropdownMenuItem(value: 3, child: Text('3 ngày', style: TextStyle(fontSize: 16))),
                      DropdownMenuItem(value: 4, child: Text('4 ngày', style: TextStyle(fontSize: 16))),
                      DropdownMenuItem(value: 5, child: Text('5 ngày', style: TextStyle(fontSize: 16))),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        widget.onDaysChanged(value);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 350,
            width: double.infinity,
            child: widget.sensorData.isEmpty
                ? const Center(child: Text('Không có dữ liệu', style: TextStyle(fontSize: 16)))
                : LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: soilMoistureSpots,
                          isCurved: true,
                          color: const Color(0xFF4A90E2),
                          barWidth: 2,
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF4A90E2).withOpacity(0.2),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: airHumiditySpots,
                          isCurved: true,
                          color: const Color(0xFF50E3C2),
                          barWidth: 2,
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF50E3C2).withOpacity(0.2),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: temperatureSpots,
                          isCurved: true,
                          color: const Color(0xFFFF6B6B),
                          barWidth: 2,
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFFFF6B6B).withOpacity(0.2),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            if (touchedSpots.isEmpty || touchedSpots.first.x.toInt() >= timestamps.length) {
                              return [];
                            }
                            final index = touchedSpots.first.x.toInt();
                            final timestamp = timestamps[index];

                            // Sắp xếp touchedSpots theo giá trị y giảm dần
                            final sortedSpots = touchedSpots.toList()
                              ..sort((a, b) => b.y.compareTo(a.y));

                            // Tạo danh sách tooltip items
                            final tooltipItems = <LineTooltipItem>[];
                            for (var i = 0; i < sortedSpots.length; i++) {
                              final spot = sortedSpots[i];
                              String label;
                              Color textColor;

                              if (spot.barIndex == 0) {
                                label = i == 0
                                    ? '$timestamp\nĐộ ẩm đất: ${spot.y.toStringAsFixed(1)}%'
                                    : 'Độ ẩm đất: ${spot.y.toStringAsFixed(1)}%';
                                textColor = const Color(0xFF4A90E2);
                              } else if (spot.barIndex == 1) {
                                label = i == 0
                                    ? '$timestamp\nĐộ ẩm: ${spot.y.toStringAsFixed(1)}%'
                                    : 'Độ ẩm: ${spot.y.toStringAsFixed(1)}%';
                                textColor = const Color(0xFF50E3C2);
                              } else {
                                label = i == 0
                                    ? '$timestamp\nNhiệt độ: ${spot.y.toStringAsFixed(1)}°C'
                                    : 'Nhiệt độ: ${spot.y.toStringAsFixed(1)}°C';
                                textColor = const Color(0xFFFF6B6B);
                              }

                              tooltipItems.add(LineTooltipItem(
                                label,
                                TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                              ));
                            }

                            return tooltipItems;
                          },
                          getTooltipColor: (_) => Colors.black.withOpacity(0.8),
                          tooltipRoundedRadius: 5,
                        ),
                      ),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: _buildLeftTitle,
                          ),
                        ),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      minX: 0,
                      maxX: widget.sensorData.isNotEmpty ? (widget.sensorData.length - 1).toDouble() : 0,
                      minY: 0,
                      maxY: maxY,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Legend(color: Color(0xFF4A90E2), label: 'Độ ẩm đất (%)'),
              SizedBox(width: 20),
              _Legend(color: Color(0xFF50E3C2), label: 'Độ ẩm không khí (%)'),
              SizedBox(width: 20),
              _Legend(color: Color(0xFFFF6B6B), label: 'Nhiệt độ (°C)'),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildLeftTitle(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: const TextStyle(color: Colors.grey, fontSize: 14),
    );
  }
}


class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}