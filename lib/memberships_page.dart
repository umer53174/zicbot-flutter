import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/utils/constants/app_colors.dart';
import 'core/utils/size_utils.dart';
import 'app_loader.dart';

class MembershipPlanScreen extends StatefulWidget {
  const MembershipPlanScreen({super.key});

  @override
  State<MembershipPlanScreen> createState() => _MembershipPlanScreenState();
}

class _MembershipPlanScreenState extends State<MembershipPlanScreen> {
  bool isLoading = true;
  UserMembership? membership;
  int? userId;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadUserIdAndFetchMembership();
  }

  Future<void> loadUserIdAndFetchMembership() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString("userId");

      if (storedUserId == null) {
        if (!mounted) return;
        setState(() {
          hasError = true;
          errorMessage = "User not logged in. Please log in again.";
          isLoading = false;
        });
        return;
      }

      userId = int.tryParse(storedUserId);
      if (userId != null) {
        await fetchMembership(userId!);
      } else {
        if (!mounted) return;
        setState(() {
          hasError = true;
          errorMessage = "Invalid user ID. Please log in again.";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage = "Failed to load user data. Please try again.";
        isLoading = false;
      });
    }
  }

  Future<void> fetchMembership(int userId) async {
    const String baseUrl = "https://app.zicbot.com/api/user_memberplans.php";
    final url = Uri.parse("$baseUrl?user_id=$userId");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final plan = UserMembership.fromJson(body['data']);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("planName", plan.currentPlan?.name ?? "");
          await prefs.setBool(
              "planActive", plan.currentPlan?.isActive ?? false);

          if (!mounted) return;
          setState(() {
            membership = plan;
            hasError = false;
            errorMessage = '';
            isLoading = false;
          });
          return;
        } else {
          // API returned success: false or no data
          if (!mounted) return;
          setState(() {
            hasError = true;
            errorMessage = "No membership plan found. Please contact support.";
            isLoading = false;
          });
          return;
        }
      } else {
        // HTTP error status codes
        if (!mounted) return;
        setState(() {
          hasError = true;
          errorMessage = "Server error. Please try again later.";
          isLoading = false;
        });
        return;
      }
    } on SocketException {
      // Network connection error
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage =
            "No internet connection. Please check your network and try again.";
        isLoading = false;
      });
    } on TimeoutException {
      // Request timeout
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage =
            "Request timed out. Please check your internet connection and try again.";
        isLoading = false;
      });
    } on FormatException {
      // JSON parsing error
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage = "Invalid response from server. Please try again later.";
        isLoading = false;
      });
    } catch (e) {
      // Any other unexpected error
      debugPrint("Unexpected API Error: $e");
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage = "Something went wrong. Please try again later.";
        isLoading = false;
      });
    }
  }

  Future<void> _launchMembershipPage() async {
    final Uri url = Uri.parse("https://app.zicbot.com/memberships.php");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showErrorSnackBar("Could not open Membership page..!");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            Gap.h(12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.fSize)),
        margin: EdgeInsets.all(16.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const AppLoader()
          : hasError
              ? _buildErrorState()
              : membership == null
                  ? _buildNoMembershipState()
                  : _buildMembershipContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.fSize,
              color: Colors.red[300],
            ),
            Gap.v(16),
            Text(
              'Failed to load membership',
              style: TextStyle(
                fontSize: 18.fSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Gap.v(8),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 14.fSize,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            Gap.v(24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  hasError = false;
                  errorMessage = '';
                });
                loadUserIdAndFetchMembership();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.h, vertical: 12.v),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.fSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMembershipState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_membership,
              size: 64.fSize,
              color: Colors.orange[300],
            ),
            Gap.v(16),
            Text(
              'No Membership Plan',
              style: TextStyle(
                fontSize: 18.fSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Gap.v(8),
            Text(
              'You don\'t have an active membership plan.',
              style: TextStyle(
                fontSize: 14.fSize,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            Gap.v(24),
            ElevatedButton.icon(
              onPressed: _launchMembershipPage,
              icon: const Icon(Icons.add),
              label: const Text('Get Membership'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.h, vertical: 12.v),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25.fSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.h),
      child: Column(
        children: [
          if (membership!.currentPlan != null)
            buildCard("Current Plan", [
              buildRow("Plan Name", membership!.currentPlan!.name),
              buildRow("Price", "\$${membership!.currentPlan!.price}"),
              buildRow(
                  "Credits Limit", "${membership!.currentPlan!.creditsLimit}"),
              buildRow("Duration (Days)",
                  "${membership!.currentPlan!.durationDays}"),
              buildRow(
                  "Active", membership!.currentPlan!.isActive ? "Yes" : "No"),
              const Divider(),
              Text("Features",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16.fSize)),
              Gap.v(6),
              ...membership!.currentPlan!.featuresArray.map((f) => Row(
                    children: [
                      Icon(Icons.check, size: 18.fSize, color: Colors.green),
                      Gap.h(6),
                      Expanded(child: Text(f)),
                    ],
                  )),
            ])
          else
            _buildNoMembershipState(),

          Gap.v(24),

          Gap.v(32),
          // Update Membership button
          Center(
            child: ElevatedButton(
              onPressed: _launchMembershipPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 40.h, vertical: 16.v),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.fSize)),
                elevation: 4,
              ),
              child: Text(
                "Update Membership",
                style: TextStyle(fontSize: 16.fSize, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 5,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.fSize)),
      shadowColor: Colors.black26,
      child: Padding(
        padding: EdgeInsets.all(18.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    TextStyle(fontSize: 18.fSize, fontWeight: FontWeight.bold)),
            Gap.v(12),
            ...children
          ],
        ),
      ),
    );
  }

  Widget buildRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.v),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 15.fSize, color: Colors.white70)),
          Text(value,
              style: TextStyle(
                  fontSize: 15.fSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70)),
        ],
      ),
    );
  }
}

// Models
class UserMembership {
  final int userId;
  final String userName;
  final String userEmail;
  final MembershipPlan? currentPlan;

  UserMembership({
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.currentPlan,
  });

  factory UserMembership.fromJson(Map<String, dynamic> json) {
    return UserMembership(
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      currentPlan: json['current_plan'] != null
          ? MembershipPlan.fromJson(json['current_plan'])
          : null,
    );
  }
}

class MembershipPlan {
  final int id;
  final String name;
  final double price;
  final int creditsLimit;
  final int durationDays;
  final List<String> featuresArray;
  final bool isActive;
  final double pricePerCredit;

  MembershipPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.creditsLimit,
    required this.durationDays,
    required this.featuresArray,
    required this.isActive,
    required this.pricePerCredit,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      creditsLimit: json['credits_limit'] ?? 0,
      durationDays: json['duration_days'] ?? 0,
      featuresArray: (json['features_array'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: (json['is_active'] ?? 0) == 1,
      pricePerCredit: (json['price_per_credit'] ?? 0).toDouble(),
    );
  }
}
