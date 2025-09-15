import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'nav_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/utils/constants/app_colors.dart';
import 'core/utils/size_utils.dart';
import 'dart:math' as math;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _keepMeLoggedIn = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    ));

    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _loadingController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Check if user should be auto-logged in
  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
    final sessionId = prefs.getString("session_id");
    final savedEmail = prefs.getString("email");
    final savedPassword = prefs.getString("password");

    if (isLoggedIn && sessionId != null && sessionId.isNotEmpty) {
      // Auto login - navigate directly to main app
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const NavMenu(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
      return;
    }

    // Load saved credentials for form
    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }
    if (savedPassword != null) {
      _passwordController.text = savedPassword;
      setState(() {
        _keepMeLoggedIn = true;
      });
    }
  }

  Future<void> _launchSignup() async {
    final Uri url = Uri.parse("https://app.zicbot.com/signup.php");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showErrorSnackBar("Could not open signup page");
    }
  }

  Future<void> _launchForgotPassword() async {
    final Uri url = Uri.parse("https://app.zicbot.com/forgot_password.php");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showErrorSnackBar("Could not open forgot password page");
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.h)),
        margin: EdgeInsets.all(16.h),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            Gap.h(12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.h)),
        margin: EdgeInsets.all(16.h),
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar("Please enter both email and password");
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorSnackBar("Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);
    _loadingController.repeat(); // Start loading animation

    try {
      final response = await http
          .post(
            Uri.parse("https://app.zicbot.com/api/login_api.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        // Get PHP session ID from headers
        String? sessionId = response.headers['set-cookie']?.split(';')[0];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("session_id", sessionId ?? '');
        await prefs.setString("email", email);
        await prefs.setString("userId", data["user"]["id"].toString());
        if (data["user"]["restaurant_name"] != null) {
          await prefs.setString(
              "restaurant_name", data["user"]["restaurant_name"]);
        }
        // Save login state and credentials based on checkbox
        if (_keepMeLoggedIn) {
          await prefs.setBool("isLoggedIn", true);
          await prefs.setString("password", password);
        } else {
          await prefs.setBool("isLoggedIn", false);
          await prefs.remove("password");
        }

        _showSuccessSnackBar("Welcome back! Login successful");

        // Add a small delay for better UX
        await Future.delayed(const Duration(milliseconds: 500));
// 🔑 Ask permissions before navigating
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const NavMenu(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      } else {
        _showErrorSnackBar(
            data["message"] ?? "Login failed. Please check your credentials.");
      }
    } catch (e) {
      String errorMessage =
          "Connection error. Please check your internet connection.";
      if (e.toString().contains("TimeoutException")) {
        errorMessage = "Request timed out. Please try again.";
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _loadingController.stop();
        _loadingController.reset();
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F0F),
              const Color(0xFF1A1A1A),
              AppColors.primary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.h),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth > 600 ? 400.h : double.infinity,
                        ),
                        child: Card(
                          elevation: 24,
                          shadowColor: AppColors.primary.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.h),
                          ),
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1E1E1E),
                                  Color(0xFF2A2A2A),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24.h),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            padding: EdgeInsets.all(32.h),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo and Title Section
                                _buildHeader(),

                                Gap.v(40),

                                // Form Section
                                _buildLoginForm(),

                                Gap.v(32),

                                // Login Button
                                _buildLoginButton(),

                                Gap.v(24),

                                // Footer Links
                                _buildFooterLinks(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo Container
        Container(
          width: 80.h,
          height: 80.h,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              "assets/zicboticon.png",
              width: 70.h,
              height: 70.h,
              fit: BoxFit.contain,
            ),
          ),
        ),

        Gap.v(10),

        // App Name
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          ).createShader(bounds),
          child: Text(
            "Zicbot",
            style: TextStyle(
              fontSize: 36.fSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),

        Gap.v(8),

        // Subtitle
        Text(
          "AI Waiter For Restaurants",
          style: TextStyle(
            fontSize: 16.fSize,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        // Email Field
        _buildTextField(
          controller: _emailController,
          label: "Email Address",
          hint: "Enter your email",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),

        Gap.v(20),

        // Password Field
        _buildTextField(
          controller: _passwordController,
          label: "Password",
          hint: "Enter your password",
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.white.withOpacity(0.6),
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),

        Gap.v(20),

        // Keep me logged in & Forgot password
        _buildOptionsRow(),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool? obscureText,
    Widget? suffixIcon,
  }) {
    return Column(
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
            borderRadius: BorderRadius.circular(16.h),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText ?? false,
            style: TextStyle(color: Colors.white, fontSize: 16.fSize),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.6)),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(20.h),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Keep me logged in row
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _keepMeLoggedIn = !_keepMeLoggedIn),
              child: Container(
                width: 20.h,
                height: 20.h,
                decoration: BoxDecoration(
                  color:
                      _keepMeLoggedIn ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: _keepMeLoggedIn
                        ? AppColors.primary
                        : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4.h),
                ),
                child: _keepMeLoggedIn
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ),
            Gap.h(8),
            GestureDetector(
              onTap: () => setState(() => _keepMeLoggedIn = !_keepMeLoggedIn),
              child: Text(
                "Keep me logged in",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14.fSize,
                ),
              ),
            ),
          ],
        ),

        Gap.v(8),

        // Forgot password aligned to the right
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _launchForgotPassword,
              child: Text(
                "Forgot Password?",
                style: TextStyle(
                  fontSize: 14.fSize,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLoading
              ? [Colors.grey.shade600, Colors.grey.shade700]
              : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16.h),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.h),
          ),
        ),
        child: _isLoading
            ? _buildLoadingAnimation()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Sign In",
                    style: TextStyle(
                      fontSize: 18.fSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Gap.h(8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated dots
            for (int i = 0; i < 3; i++)
              AnimatedContainer(
                duration: Duration(milliseconds: 300 + (i * 100)),
                margin: EdgeInsets.symmetric(horizontal: 3.h),
                height: 8.h,
                width: 8.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3 +
                      0.7 *
                          (0.5 +
                              0.5 *
                                  math.sin(
                                      _loadingAnimation.value * 2 * math.pi +
                                          i * 0.5))),
                  shape: BoxShape.circle,
                ),
              ),
            Gap.h(12),
            // Loading text
            Text(
              "Signing In...",
              style: TextStyle(
                fontSize: 16.fSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.h),
              child: Text(
                "New to Zicbot?",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14.fSize,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
          ],
        ),

        Gap.v(20),

        // Signup link
        Container(
          width: double.infinity,
          height: 48.h,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12.h),
          ),
          child: TextButton(
            onPressed: _launchSignup,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.h),
              ),
            ),
            child: Text(
              "Create New Account",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16.fSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
