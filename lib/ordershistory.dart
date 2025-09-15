import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/utils/constants/app_colors.dart';
import 'core/utils/size_utils.dart';
import 'app_loader.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<dynamic> allOrders = [];
  List<dynamic> filteredOrders = [];
  bool isLoading = true;
  String errorMessage = '';

  // Filter variables
  DateTime? selectedDate;
  String selectedOrderType = 'All';
  String selectedOrderStatus = 'All';

  // Filter options
  final List<String> orderTypes = ['All', 'Dine-in', 'Delivery', 'Takeaway'];
  final List<String> orderStatuses = [
    'All',
    'Pending',
    'Preparing',
    'Ready',
    'Served',
    'Delivered',
    'Handover',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString("session_id");

      final response = await http.get(
        Uri.parse("https://app.zicbot.com/api/get_orders.php"),
        headers: {"Cookie": sessionId ?? '', "Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> orders = data["orders"] ?? [];

        setState(() {
          allOrders = orders;
          filteredOrders = List.from(orders);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  void applyFilters() {
    setState(() {
      filteredOrders = allOrders.where((order) {
        bool matchesDate = true;
        bool matchesType = true;
        bool matchesStatus = true;

        // Date filter
        if (selectedDate != null) {
          String orderDate = order['created_at']?.toString() ?? '';
          if (orderDate.isNotEmpty) {
            try {
              DateTime parsedDate = DateTime.parse(orderDate);
              matchesDate = DateFormat('yyyy-MM-dd').format(parsedDate) ==
                  DateFormat('yyyy-MM-dd').format(selectedDate!);
            } catch (e) {
              matchesDate = false;
            }
          }
        }

        // Order type filter
        if (selectedOrderType != 'All') {
          String orderType = order['order_type']?.toString() ?? '';
          matchesType =
              orderType.toLowerCase() == selectedOrderType.toLowerCase();
        }

        // Order status filter
        if (selectedOrderStatus != 'All') {
          String orderStatus = order['order_status']?.toString() ?? '';
          matchesStatus =
              orderStatus.toLowerCase() == selectedOrderStatus.toLowerCase();
        }

        return matchesDate && matchesType && matchesStatus;
      }).toList();
    });
  }

  void clearFilters() {
    setState(() {
      selectedDate = null;
      selectedOrderType = 'All';
      selectedOrderStatus = 'All';
      filteredOrders = List.from(allOrders);
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'served':
      case 'delivered':
      case 'handover':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget buildStatsCard(String title, int count, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E1E),
            Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(16.fSize),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.fSize),
                  ),
                  child: Icon(icon, color: color, size: 20.fSize),
                ),
                const Spacer(),
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 24.fSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Gap.v(12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.fSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(20.h),
      margin: EdgeInsets.all(16.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E1E),
            Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(16.fSize),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.fSize),
                ),
                child: Icon(Icons.filter_list,
                    color: AppColors.primary, size: 20.fSize),
              ),
              Gap.h(12),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18.fSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: clearFilters,
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          Gap.v(20),

          // Date Filter
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: Color(0xFF2A2A2A),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() {
                  selectedDate = date;
                });
                applyFilters();
              }
            },
            child: Container(
              padding: EdgeInsets.all(16.h),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12.fSize),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary),
                  Gap.h(12),
                  Text(
                    selectedDate != null
                        ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                        : 'Select Date',
                    style: TextStyle(color: Colors.white, fontSize: 16.fSize),
                  ),
                  const Spacer(),
                  if (selectedDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = null;
                        });
                        applyFilters();
                      },
                      child: Icon(Icons.clear,
                          color: Colors.white60, size: 20.fSize),
                    ),
                ],
              ),
            ),
          ),

          Gap.v(16),

          Row(
            children: [
              // Order Type Filter
              Expanded(
                child: buildDropdownFilter(
                  'Order Type',
                  selectedOrderType,
                  orderTypes,
                  Icons.restaurant_menu,
                  (value) {
                    setState(() {
                      selectedOrderType = value!;
                    });
                    applyFilters();
                  },
                ),
              ),

              Gap.h(16),

              // Order Status Filter
              Expanded(
                child: buildDropdownFilter(
                  'Order Status',
                  selectedOrderStatus,
                  orderStatuses,
                  Icons.info_outline,
                  (value) {
                    setState(() {
                      selectedOrderStatus = value!;
                    });
                    applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDropdownFilter(
    String label,
    String value,
    List<String> items,
    IconData icon,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.fSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap.v(8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12.fSize),
            border: Border.all(color: Colors.white12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.h),
          child: Row(
            children: [
              Icon(icon, color: Colors.white60, size: 18.fSize),
              Gap.h(8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    dropdownColor: const Color(0xFF2A2A2A),
                    isExpanded: true,
                    style: TextStyle(color: Colors.white, fontSize: 14.fSize),
                    items: items.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildOrdersTable() {
    if (filteredOrders.isEmpty) {
      return Container(
        margin: EdgeInsets.all(16.h),
        padding: EdgeInsets.all(40.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1E1E),
              Color(0xFF2A2A2A),
            ],
          ),
          borderRadius: BorderRadius.circular(16.fSize),
          border: Border.all(
            color: Colors.white12,
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 64.fSize, color: Colors.white24),
              Gap.v(16),
              Text(
                'No orders found',
                style: TextStyle(fontSize: 18.fSize, color: Colors.white70),
              ),
              Gap.v(8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(fontSize: 14.fSize, color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(16.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E1E),
            Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(16.fSize),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.fSize),
                  ),
                  child: Icon(Icons.receipt_long,
                      color: AppColors.primary, size: 20.fSize),
                ),
                Gap.h(12),
                Text(
                  'Orders (${filteredOrders.length})',
                  style: TextStyle(
                    fontSize: 18.fSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Table Header (for mobile)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 12.v),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              border: const Border(
                top: BorderSide(color: Colors.white12),
                bottom: BorderSide(color: Colors.white12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('Order Details',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.fSize))),
                Expanded(
                    flex: 1,
                    child: Text('Type',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.fSize))),
                Expanded(
                    flex: 1,
                    child: Text('Status',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.fSize))),
              ],
            ),
          ),

          // Orders List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredOrders.length,
            separatorBuilder: (context, index) => const Divider(
              color: Colors.white12,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final orderDate = order['created_at']?.toString() ?? '';
              String formattedDate = '';

              if (orderDate.isNotEmpty) {
                try {
                  final parsedDate = DateTime.parse(orderDate);
                  formattedDate =
                      DateFormat('MMM dd, yyyy HH:mm').format(parsedDate);
                } catch (e) {
                  formattedDate = orderDate;
                }
              }

              final status = order['order_status']?.toString() ?? 'Unknown';
              final statusColor = _getStatusColor(status);

              return Container(
                padding: EdgeInsets.all(16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${order['id']} - ${order['name'] ?? 'Unknown Customer'}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.fSize,
                                ),
                              ),
                              Gap.v(4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12.fSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.h, vertical: 4.v),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.fSize),
                            border:
                                Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11.fSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    Gap.v(12),

                    // Order Details Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['order_details'] ?? 'No details',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14.fSize),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (order['table_number']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true) ...[
                                Gap.v(4),
                                Text(
                                  'Table: ${order['table_number']}',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12.fSize),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.h, vertical: 3.v),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8.fSize),
                            ),
                            child: Text(
                              order['order_type'] ?? 'N/A',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.fSize,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          Gap.v(16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalOrders = allOrders.length;
    final completedOrders = allOrders
        .where((order) => ['served', 'delivered', 'handover']
            .contains(order['order_status']?.toString().toLowerCase()))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Order History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchOrders,
          ),
        ],
      ),
      body: isLoading
          ? const AppLoader()
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64.fSize,
                        color: Colors.red,
                      ),
                      Gap.v(16),
                      Text(
                        errorMessage,
                        style: TextStyle(
                            fontSize: 16.fSize, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      Gap.v(16),
                      ElevatedButton(
                        onPressed: fetchOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchOrders,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards
                        Container(
                          padding: EdgeInsets.all(16.h),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 12.h,
                            mainAxisSpacing: 12.v,
                            childAspectRatio: 1.5,
                            children: [
                              buildStatsCard(
                                'Total Orders',
                                totalOrders,
                                Colors.blue,
                                Icons.receipt_long,
                              ),
                              buildStatsCard(
                                'Completed Orders',
                                completedOrders,
                                Colors.green,
                                Icons.check_circle,
                              ),
                            ],
                          ),
                        ),

                        // Filters
                        buildFilterSection(),

                        // Orders Table
                        buildOrdersTable(),

                        Gap.v(20),
                      ],
                    ),
                  ),
                ),
    );
  }
}
