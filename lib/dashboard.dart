import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'app_loader.dart';
import 'ordershistory.dart';
import 'core/utils/constants/app_colors.dart';
import 'core/utils/size_utils.dart';
import 'dart:io';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> currentOrders = [];
  List<dynamic> completedOrders = [];
  List<dynamic> previousOrders = [];
  List<dynamic> pendingOrders = [];

  List<dynamic> todaysOrder = [];

  bool isLoading = true;
  bool firstLoad = true;
  bool notificationsInitialized = false;
  Timer? _refreshTimer;

  // Tab controller for switching between current and completed orders
  late TabController _tabController;

  // When updating a particular order
  bool _isSavingOrder = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeApp();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        fetchOrders(showLoading: false); // Silent refresh
      }
    });
  }

  Future<void> _initializeApp() async {
    await initNotifications();
    await fetchOrders(); // initial load
  }

  // Improved notification initialization
  Future<void> initNotifications() async {
    try {
      // Use proper resource reference
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Add iOS initialization (required even if not targeting iOS)
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {},
      );
      // Create notification channel (REQUIRED for Android 8.0+)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'orders_channel',
        'New Orders',
        description: 'Notifications for new orders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      // ✅ Request permission using the plugin's own method
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }

      // Request notification permission
      if (androidPlugin != null) {
        // Check if notifications are already enabled
        if (await androidPlugin.areNotificationsEnabled() == false) {
          final bool? granted =
              await androidPlugin.requestNotificationsPermission();
          if (granted != null && granted) {
            notificationsInitialized = true;
          } else {
            notificationsInitialized = false;
          }
        } else {
          notificationsInitialized = true;
        }
      } else {
        notificationsInitialized = false;
      }
    } catch (e) {
      notificationsInitialized = false;
    }
  }

  Future<void> fetchOrders({bool showLoading = true}) async {
    if (showLoading) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String sessionId = prefs.getString("session_id") ?? '';

      final response = await http.get(
        Uri.parse("https://app.zicbot.com/api/get_orders.php"),
        headers: {"Cookie": sessionId, "Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> orders = data["orders"] ?? [];

        // Detect new orders
        if (!firstLoad &&
            previousOrders.isNotEmpty &&
            notificationsInitialized) {
          await _detectAndNotifyNewOrders(orders);
        }

        // Snapshot
        previousOrders =
            orders.map((o) => Map<String, dynamic>.from(o)).toList();

        final now = DateTime.now();
        final todayStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        List<dynamic> todayOrders = [];
        List<dynamic> todayCompleted = [];
        List<dynamic> todayPending = [];

        for (var order in orders) {
          final status =
              (order["order_status"] ?? "").toString().toLowerCase().trim();
          final createdAt = order["created_at"]?.toString() ?? "";

          final isToday = createdAt.startsWith(todayStr);

          if (isToday) {
            todayOrders.add(order);

            if (["completed", "delivered", "handover", "served"]
                .contains(status)) {
              todayCompleted.add(order);
            } else if (["pending", "preparing", "ready"].contains(status)) {
              todayPending.add(order);
            }
          }
        }
        if (mounted) {
          setState(() {
            completedOrders = todayCompleted;
            pendingOrders = todayPending;
            todaysOrder = todayOrders;
            if (showLoading) isLoading = false;
            firstLoad = false;
          });
        }
      } else {
        throw Exception(
            "Failed to load orders (status ${response.statusCode})");
      }
    } on SocketException {
      if (showLoading && mounted) setState(() => isLoading = false);
      Fluttertoast.showToast(msg: "No internet connection");
    } catch (e) {
      if (showLoading && mounted) setState(() => isLoading = false);
      Fluttertoast.showToast(msg: "Error loading orders: $e");
    }
  }

  // Improved new order detection
  Future<void> _detectAndNotifyNewOrders(List<dynamic> newOrders) async {
    try {
      Set<String> previousOrderIds = previousOrders
          .map((order) => order["id"]?.toString() ?? "")
          .where((id) => id.isNotEmpty)
          .toSet();

      List<dynamic> detectedNewOrders = [];
      for (var order in newOrders) {
        String orderId = order["id"]?.toString() ?? "";
        if (orderId.isNotEmpty && !previousOrderIds.contains(orderId)) {
          detectedNewOrders.add(order);
        }
      }

      if (detectedNewOrders.isNotEmpty) {
        for (var order in detectedNewOrders) {
          await showNewOrderNotification(order);
        }
      }
    } catch (e) {}
  }

  // Improved notification display
  Future<void> showNewOrderNotification(Map<String, dynamic> order) async {
    if (!notificationsInitialized) return;

    try {
      final String orderDetails =
          order["order_details"]?.toString() ?? "No details";
      final String table = order["table_number"]?.toString() ?? "N/A";
      final String customerName = order["name"]?.toString() ?? "Customer";
      final String orderType = order["order_type"]?.toString() ?? "Order";

      String notificationBody =
          '$orderType from $customerName\nTable: $table\n$orderDetails';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'orders_channel',
        'New Orders',
        channelDescription: 'Notifications for new orders',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      int notificationId = int.tryParse(order["id"]?.toString() ?? "") ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        'New Order Received!',
        notificationBody,
        platformDetails,
        payload: 'order_${order["id"]}',
      );

      if (mounted) {
        _showInAppNotification(order);
      }
    } catch (e) {}
  }

  void _showInAppNotification(Map<String, dynamic> order) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.all(16.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12.fSize),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active,
                  color: Colors.white, size: 24.fSize),
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'New Order Received!',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${order["name"]} • Table ${order["table_number"]}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Call update_order.php to update the order on the server
  Future<bool> _sendUpdateToServer(Map<String, dynamic> payload) async {
    setState(() => _isSavingOrder = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString("session_id");

      final resp = await http.post(
        Uri.parse("https://app.zicbot.com/api/update_order.php"),
        headers: {
          "Content-Type": "application/json",
          "Cookie": sessionId ?? '',
          "Accept": "application/json"
        },
        body: json.encode(payload),
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data["success"] == true) {
          Fluttertoast.showToast(msg: "Order updated successfully!");
          await fetchOrders(showLoading: false);
          return true;
        } else {
          Fluttertoast.showToast(
              msg: "Update failed: ${data["message"] ?? 'Unknown error'}");
          return false;
        }
      } else {
        Fluttertoast.showToast(msg: "Update failed: HTTP ${resp.statusCode}");
        return false;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Update error: $e");
      return false;
    } finally {
      setState(() => _isSavingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AppLoader();
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: RefreshIndicator(
        onRefresh: () => fetchOrders(),
        color: AppColors.primary,
        child: Column(
          children: [
            // ✅ Summary Cards - fixed overflow
            Container(
              padding: EdgeInsets.all(12.h),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15.h,
                mainAxisSpacing: 15.v,
                childAspectRatio: 2.0, // slightly taller → no cut text
                children: [
                  _buildSummaryCard(
                    "Total Orders",
                    (previousOrders.length).toString(),
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                  _buildSummaryCard(
                    "Today's Orders",
                    todaysOrder.length.toString(),
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                  _buildSummaryCard(
                    "Completed",
                    completedOrders.length.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildSummaryCard(
                    "Pending",
                    pendingOrders.length.toString(),
                    Icons.autorenew,
                    AppColors.primary,
                  ),
                ],
              ),
            ),

            // ✅ Order History Button
            Container(
              width: double.infinity, // 👈 takes full width
              margin: EdgeInsets.symmetric(horizontal: 12.h, vertical: 4.v),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.h, vertical: 12.v),
                ),
                icon: Icon(Icons.history,
                    size: 18.fSize, color: const Color(0xFF9C27B0)),
                label: Text(
                  "View Order History",
                  style:
                      TextStyle(color: Color(0xFF9C27B0), fontSize: 14.fSize),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryPage(),
                    ),
                  );
                },
              ),
            ),

            // ✅ Tabs (separate line, square style)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.circular(4.fSize), // less rounded = square
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.circular(4.fSize), // square indicator
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pending_actions, size: 16.fSize),
                        Gap.h(6),
                        Text(
                          'Pending (${pendingOrders.length})',
                          style: TextStyle(fontSize: 12.fSize),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 16.fSize),
                        Gap.h(6),
                        Text(
                          'Completed (${completedOrders.length})',
                          style: TextStyle(fontSize: 12.fSize),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList(pendingOrders, true),
                  _buildOrdersList(completedOrders, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders, bool isCurrentOrders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCurrentOrders ? Icons.pending_actions : Icons.check_circle,
              size: 64.fSize,
              color: Colors.white24,
            ),
            Gap.v(16),
            Text(
              isCurrentOrders ? 'No current orders' : 'No completed orders',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18.fSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            Gap.v(8),
            Text(
              isCurrentOrders
                  ? 'New orders will appear here automatically'
                  : 'Completed orders will appear here',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14.fSize,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.h),
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _buildOrderCard(orders[index], isCurrentOrders),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
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
        padding: EdgeInsets.all(16.h), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.h), // Reduced padding
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.fSize),
                  ),
                  child:
                      Icon(icon, color: color, size: 18.fSize), // Reduced size
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 20.fSize, // Reduced font size
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Gap.v(8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.fSize, // Reduced font size
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isActive) {
    final status = order["order_status"]?.toString() ?? "";
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 12.v),
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
          color: isActive
              ? AppColors.primary.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order["name"] ?? "Unknown Customer",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.fSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Gap.v(4),
                      Text(
                        "Order #${order["id"]}",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14.fSize,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.h, vertical: 6.v),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.fSize),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12.fSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            Gap.v(16),

            // Order Details
            _buildDetailRow(Icons.restaurant_menu, "Details",
                order["order_details"] ?? "-"),
            _buildDetailRow(Icons.phone, "Phone", order["phone"] ?? "-"),
            _buildDetailRow(Icons.table_restaurant, "Table",
                order["table_number"]?.toString() ?? "-"),
            _buildDetailRow(
                Icons.delivery_dining, "Type", order["order_type"] ?? "-"),
            _buildDetailRow(
                Icons.access_time, "Time", order["created_at"] ?? "-"),

            Gap.v(16),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showOrderForm(order),
                icon: Icon(Icons.edit, size: 18.fSize),
                label: const Text("View & Edit Order"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.v),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.fSize),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.v),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 16.fSize),
          Gap.h(8),
          SizedBox(
            width: 60.h,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14.fSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Gap.h(8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.fSize,
              ),
            ),
          ),
        ],
      ),
    );
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
      case 'completed':
      case 'handover':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Update Form (keeping the same functionality but cleaner design)
  void showOrderForm(Map<String, dynamic> order) {
    final nameController = TextEditingController(text: order["name"]);
    final phoneController = TextEditingController(text: order["phone"]);
    final addressController = TextEditingController(text: order["address"]);
    final tableController =
        TextEditingController(text: order["table_number"]?.toString() ?? "");
    final noteController = TextEditingController(text: order["note"] ?? "");
    final detailsController =
        TextEditingController(text: order["order_details"] ?? "");

    String orderType = order["order_type"] ?? "Dine-in";
    String status = order["order_status"] ?? "Pending";
    String paymentStatus = order["payment_status"] ?? "Unpaid";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2A2A2A),
                Color(0xFF1E1E1E),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.fSize)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12.h),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.fSize),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: AppColors.primary,
                              size: 24.fSize,
                            ),
                          ),
                          Gap.h(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Edit Order",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.fSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Order #${order["id"]}",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14.fSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),

                      Gap.v(24),

                      // Form Fields
                      buildTextField(
                          "Customer Name", nameController, Icons.person),
                      buildTextField(
                          "Phone Number", phoneController, Icons.phone),
                      buildTextField(
                          "Address", addressController, Icons.location_on),
                      buildTextField("Table Number", tableController,
                          Icons.table_restaurant),
                      buildDropdown(
                        "Order Type",
                        orderType,
                        ["Dine-in", "Delivery", "Takeaway"],
                        Icons.delivery_dining,
                        (val) =>
                            setModalState(() => orderType = val ?? "Dine-in"),
                      ),
                      buildDropdown(
                        "Order Status",
                        status,
                        [
                          "Pending",
                          "Preparing",
                          "Ready",
                          "Served",
                          "Delivered",
                          "Handover",
                          "Cancelled"
                        ],
                        Icons.update,
                        (val) => setModalState(() => status = val ?? "Pending"),
                      ),
                      buildTextField("Order Details", detailsController,
                          Icons.restaurant_menu,
                          maxLines: 3),
                      buildTextField("Notes", noteController, Icons.note,
                          maxLines: 2),
                      buildDropdown(
                        "Payment Status",
                        paymentStatus,
                        ["Unpaid", "Paid", "Refunded"],
                        Icons.payment,
                        (val) => setModalState(
                            () => paymentStatus = val ?? "Unpaid"),
                      ),

                      Gap.v(32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 56.v,
                        child: ElevatedButton(
                          onPressed: _isSavingOrder
                              ? null
                              : () async {
                                  final payload = {
                                    "id": order["id"],
                                    "name": nameController.text.trim(),
                                    "phone": phoneController.text.trim(),
                                    "address": addressController.text.trim(),
                                    "table_number": tableController.text.trim(),
                                    "order_type": orderType,
                                    "order_status": status,
                                    "order_details":
                                        detailsController.text.trim(),
                                    "note": noteController.text.trim(),
                                    "payment_status": paymentStatus,
                                  };

                                  final success =
                                      await _sendUpdateToServer(payload);
                                  if (success && mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.fSize),
                            ),
                            elevation: 0,
                          ),
                          child: _isSavingOrder
                              ? SizedBox(
                                  height: 20.fSize,
                                  width: 20.fSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    fontSize: 16.fSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget buildTextField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.fSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          Gap.v(8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12.fSize),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: Colors.white60, size: 20.fSize),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.h),
                hintText: "Enter $label",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDropdown(String label, String value, List<String> items,
      IconData icon, Function(String?) onChange) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.fSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          Gap.v(8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12.fSize),
              border: Border.all(color: Colors.white12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.h),
            child: Row(
              children: [
                Icon(icon, color: Colors.white60, size: 20.fSize),
                Gap.h(12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: items.contains(value) ? value : items[0],
                      dropdownColor: const Color(0xFF2A2A2A),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      items: items
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: onChange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
