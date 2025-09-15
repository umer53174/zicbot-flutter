import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'memberships_page.dart';
import 'profile_page.dart';
import 'credit-page.dart';
import 'core/utils/constants/app_colors.dart';

class NavMenu extends StatefulWidget {
  const NavMenu({super.key});

  @override
  State<NavMenu> createState() => _NavMenuState();
}

class _NavMenuState extends State<NavMenu> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const DashboardPage(),
    const MembershipPlanScreen(),
    const MessageCreditsScreen(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Left-side icon that matches the tab

        forceMaterialTransparency: true,
        leading: Icon(
          selectedIndex == 0
              ? Icons.dashboard
              : selectedIndex == 1
                  ? Icons.card_membership
                  : selectedIndex == 2
                      ? Icons.credit_card
                      : Icons.person,
        ),

        // Title changes with tab
        title: Text(
          selectedIndex == 0
              ? "Dashboard" // changed here ✅
              : selectedIndex == 1
                  ? "Memberships"
                  : selectedIndex == 2
                      ? "Credits"
                      : "Profile",
        ),
        centerTitle: true,
      ),
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white70,
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() => selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_membership), label: "Memberships"),
          BottomNavigationBarItem(
              icon: Icon(Icons.credit_card), label: "Credits"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
