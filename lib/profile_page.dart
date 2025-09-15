import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'app_loader.dart';
import 'core/utils/constants/app_colors.dart';
import 'core/utils/size_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  String email = '';
  String userId = '';
  String planName = '';
  String restaurantName = '';
  bool planActive = false;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        email = prefs.getString("email") ?? '';
        userId = prefs.getString("userId") ?? '';
        planName = prefs.getString("planName") ?? 'Free';
        planActive = prefs.getBool("planActive") ?? false;
        restaurantName =
            prefs.getString("restaurant_name") ?? 'Unknown Restaurant';
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading user data'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.fSize)),
          ),
        );
      }
    }
  }

  Future<void> _Profilepage() async {
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

  Future<void> _logout() async {
    if (!mounted) return;
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.fSize)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.h),
              decoration: BoxDecoration(
                color: Colors.red[100]?.withAlpha((0.2 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: Colors.red[400], size: 24.fSize),
            ),
            Gap.h(12),
            Text(
              'Confirm Logout',
              style: TextStyle(color: Colors.white, fontSize: 20.fSize),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout? You will need to sign in again.',
          style: TextStyle(color: Colors.white70, fontSize: 16.fSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Error during logout'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: AppLoader(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.h, 60.v, 24.h, 24.v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAccountInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20.fSize),
        border: Border.all(color: Colors.grey.withAlpha((0.1 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🔹 Account Info Heading
          Text(
            'Account Information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.fSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Gap.v(24),

          // Email
          if (email.isNotEmpty) ...[
            _buildInfoTile(
              icon: Icons.email,
              title: 'Email',
              value: email,
              valueColor: Colors.white,
            ),
            Gap.v(16),
          ],
          // Restaurant Name
          if (restaurantName.isNotEmpty) ...[
            _buildInfoTile(
              icon: Icons.restaurant,
              title: 'Restaurant',
              value: restaurantName,
              valueColor: Colors.white,
            ),
            Gap.v(16),
          ],

          // Member Plan
          _buildInfoTile(
            icon: Icons.card_membership,
            title: 'Member Plan',
            value: planName.isEmpty ? 'Free' : planName,
            valueColor: const Color(0xFF6C63FF),
          ),
          Gap.v(16),

          // Account Status
          _buildInfoTile(
            icon: planActive ? Icons.verified : Icons.info_outline,
            title: 'Account Status',
            value: planActive ? 'Active' : 'Inactive',
            valueColor:
                planActive ? const Color(0xFF00C851) : const Color(0xFFFF8A00),
            showBadge: true,
          ),
          Gap.v(20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _Profilepage,
              icon: const Icon(
                Icons.person, // Profile icon
                color: Colors.white,
              ),
              label: Text(
                "Update Profile",
                style: TextStyle(fontSize: 16.fSize, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 20.h, vertical: 16.v),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.fSize),
                ),
                elevation: 4,
              ),
            ),
          ),
          // 🔹 Logout Button (Outlined like Order History)
          Gap.v(25),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              side: const BorderSide(color: Colors.purple, width: 2.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.fSize),
              ),
              padding: EdgeInsets.symmetric(horizontal: 30.h, vertical: 12.v),
              backgroundColor: Colors.transparent,
            ),
            icon: Icon(Icons.logout, size: 20.fSize, color: Colors.white),
            label: Text(
              "Logout",
              style: TextStyle(color: Colors.white, fontSize: 14.fSize),
            ),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
    bool showBadge = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.h),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withAlpha((0.5 * 255).round()),
        borderRadius: BorderRadius.circular(12.fSize),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.h),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10.fSize),
            ),
            child: Icon(icon, color: Colors.white70, size: 20.fSize),
          ),
          Gap.h(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14.fSize,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500)),
                Gap.v(4),
                Row(
                  children: [
                    Flexible(
                      child: Text(value,
                          style: TextStyle(
                              fontSize: 16.fSize,
                              fontWeight: FontWeight.w600,
                              color: valueColor)),
                    ),
                    if (showBadge) ...[
                      Gap.h(8),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.h, vertical: 2.v),
                        decoration: BoxDecoration(
                          color: valueColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.fSize),
                        ),
                        child: Text(
                          planActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            fontSize: 10.fSize,
                            fontWeight: FontWeight.bold,
                            color: valueColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
