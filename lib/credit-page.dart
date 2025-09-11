import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'app_colors.dart';
import 'app_loader.dart';
import 'dart:async';

class MessageCreditsScreen extends StatefulWidget {
  const MessageCreditsScreen({super.key});

  @override
  State<MessageCreditsScreen> createState() => _MessageCreditsScreenState();
}

class _MessageCreditsScreenState extends State<MessageCreditsScreen>
    with TickerProviderStateMixin {
  // Data variables
  Map<String, dynamic>? creditsData;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadCredits();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeController.stop();
    _slideController.stop();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Future<void> _loadCredits() async {
  //   try {
  //     // ✅ Check if widget is still mounted before setting state
  //     if (!mounted) return;

  //     setState(() {
  //       isLoading = true;
  //       hasError = false;
  //     });

  //     final prefs = await SharedPreferences.getInstance();
  //     final userId = prefs.getString("userId");

  //     if (userId == null) {
  //       throw Exception('User not logged in');
  //     }

  //     final response = await http.get(
  //       Uri.parse('https://app.zicbot.com/api/credits.php?user_id=$userId'),
  //       headers: {'Content-Type': 'application/json'},
  //     ).timeout(const Duration(seconds: 10));

  //     // ✅ Check if widget is still mounted before setting state
  //     if (!mounted) return;

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       setState(() {
  //         creditsData = data;
  //         isLoading = false;
  //       });
  //       _fadeController.forward();
  //       _slideController.forward();
  //     } else {
  //       throw Exception('Failed to load credits: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     if (!mounted) return;

  //     setState(() {
  //       isLoading = false;
  //       hasError = true;
  //       errorMessage = e.toString().replaceAll('Exception: ', '');
  //     });
  //   }
  // }
  Future<void> _loadCredits() async {
    try {
      if (!mounted) return;

      setState(() {
        isLoading = true;
        hasError = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId");

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.get(
        Uri.parse('https://app.zicbot.com/api/credits.php?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          creditsData = data;
          isLoading = false;
        });
        _fadeController.forward();
        _slideController.forward();
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e, stacktrace) {
      // 🔹 Log actual error internally (debug only)
      debugPrint("Credits API error: $e");
      debugPrint("Stacktrace: $stacktrace");

      if (!mounted) return;

      setState(() {
        isLoading = false;
        hasError = true;

        // 🔹 Show only user-friendly message
        if (e is TimeoutException) {
          errorMessage =
              "Request timed out. Please check your internet connection.";
        } else if (e.toString().contains("User not logged in")) {
          errorMessage = "Please log in to view credits.";
        } else {
          errorMessage = "Something went wrong. Please try again later.";
        }
      });
    }
  }

  // Getters for credits data
  int get totalCredits => creditsData?['credits_limit'] ?? 100;
  int get usedCredits => creditsData?['credits_used'] ?? 6;
  int get remainingCredits => totalCredits - usedCredits;
  double get usagePercentage =>
      totalCredits > 0 ? (usedCredits / totalCredits * 100) : 0;
  String get lastReset => creditsData?['last_reset'] ?? 'N/A';
  int get periodDays => creditsData?['period_days'] ?? 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBarBackground,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (hasError) {
      return _buildErrorState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: _loadCredits,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 250,
                  child: _buildPieChart(),
                ),
                const SizedBox(height: 25),
                _buildCreditsOverview(),
                const SizedBox(height: 25),
                _buildDetailsCard(),
                const SizedBox(height: 25),
                _buildUsageGuide(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const AppLoader();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load credits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadCredits,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsOverview() {
    return Card(
      color: AppColors.cardBackground,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  "Total",
                  totalCredits.toString(),
                  Icons.credit_card,
                  Colors.blue,
                ),
                _buildStatItem(
                  "Used",
                  usedCredits.toString(),
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildStatItem(
                  "Left",
                  remainingCredits.toString(),
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: usagePercentage / 100,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercentage > 80
                    ? Colors.red
                    : usagePercentage > 50
                        ? Colors.orange
                        : Colors.green,
              ),
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            Text(
              "${usagePercentage.toStringAsFixed(1)}% used this period",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 250,
      child: Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 50,
              sections: [
                PieChartSectionData(
                  color: const Color.fromARGB(255, 107, 106, 106),
                  value: usedCredits.toDouble(),
                  title: "$usedCredits\nUsed",
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PieChartSectionData(
                  color: AppColors.primary,
                  value: remainingCredits.toDouble(),
                  title: "$remainingCredits\nLeft",
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      color: AppColors.cardBackground,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Credit Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow("Total Credits", "$totalCredits credits",
                Icons.credit_card, Colors.blue),
            _buildDetailRow("Used Credits", "$usedCredits credits",
                Icons.remove_circle_outline, Colors.red),
            _buildDetailRow("Remaining Credits", "$remainingCredits credits",
                Icons.account_balance_wallet, Colors.green),
            _buildDetailRow("Reset Period", "$periodDays days", Icons.schedule,
                Colors.orange),
            _buildDetailRow("Last Reset", _formatDate(lastReset), Icons.update,
                Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageGuide() {
    return Card(
      color: AppColors.cardBackground,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "How Credits Work",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "What are message credits?\n\n"
              "Message credits are used when your system processes messages. "
              "Each message consumes 1 credit.\n\n"
              "Credit Usage (example):\n"
              "• 1 Message = 1 Credit\n\n"
              "Credit Renewal:\n"
              "Your credits reset on a rolling period (default 30 days) "
              "based on your membership plan. "
              "Unused credits do not carry over.",
              style:
                  TextStyle(fontSize: 15, height: 1.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return "${months[date.month - 1]} ${date.day}";
    } catch (e) {
      return dateStr;
    }
  }
}
