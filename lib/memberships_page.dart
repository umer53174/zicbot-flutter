import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    loadUserIdAndFetchMembership();
  }

  Future<void> loadUserIdAndFetchMembership() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString("userId");

    if (storedUserId == null) {
      if (!mounted) return; // ✅ prevent crash
      setState(() {
        isLoading = false;
      });
      return;
    }

    userId = int.tryParse(storedUserId);
    if (userId != null) {
      await fetchMembership(userId!);
    } else {
      if (!mounted) return; // ✅
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchMembership(int userId) async {
    const String baseUrl = "https://app.zicbot.com/api/user_memberplans.php";
    final url = Uri.parse("$baseUrl?user_id=$userId");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final plan = UserMembership.fromJson(body['data']);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("planName", plan.currentPlan?.name ?? "");
          await prefs.setBool(
              "planActive", plan.currentPlan?.isActive ?? false);

          if (!mounted) return; // ✅
          setState(() {
            membership = plan;
            isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }

    if (!mounted) return; // ✅
    setState(() {
      membership = null;
      isLoading = false;
    });
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
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const AppLoader()
          : membership == null
              ? const Center(child: Text("Failed to load membership"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (membership!.currentPlan != null)
                        buildCard("Current Plan", [
                          buildRow("Plan Name", membership!.currentPlan!.name),
                          buildRow(
                              "Price", "\$${membership!.currentPlan!.price}"),
                          buildRow("Credits Limit",
                              "${membership!.currentPlan!.creditsLimit}"),
                          buildRow("Duration (Days)",
                              "${membership!.currentPlan!.durationDays}"),
                          buildRow("Active",
                              membership!.currentPlan!.isActive ? "Yes" : "No"),
                          const Divider(),
                          const Text("Features",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          ...membership!.currentPlan!.featuresArray
                              .map((f) => Row(
                                    children: [
                                      const Icon(Icons.check,
                                          size: 18, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(f)),
                                    ],
                                  )),
                        ])
                      else
                        const Center(child: Text("No active membership plan.")),

                      const SizedBox(height: 24),

                      const SizedBox(height: 32),
                      // Update Membership button
                      Center(
                        child: ElevatedButton(
                          onPressed: _launchMembershipPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            elevation: 4,
                          ),
                          child: const Text(
                            "Update Membership",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children
          ],
        ),
      ),
    );
  }

  Widget buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 15, color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
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
