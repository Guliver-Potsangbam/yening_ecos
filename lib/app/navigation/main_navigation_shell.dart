import 'package:flutter/material.dart';

import '../../features/alerts/alerts_page.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/devices/devices_page.dart';
import '../../features/home/home_page.dart';
import '../../features/profile/profile_page.dart';
import 'widgets/app_bottom_navigation_bar.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_top_bar.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    this.pages,
    this.profileBuilder,
    this.authService,
  }) : assert(pages == null || pages.length == 3);

  final List<Widget>? pages;
  final WidgetBuilder? profileBuilder;
  final AuthService? authService;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late final AuthService _authService = widget.authService ?? AuthService();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = 0;

  late final List<Widget> _pages =
      widget.pages ??
      [const HomePage(), const DevicesPage(), const AlertsPage()];

  String get _currentSectionTitle {
    return switch (_currentIndex) {
      0 => 'Home',
      1 => 'Devices',
      2 => 'Alerts',
      _ => 'Home',
    };
  }

  String get _currentSectionSubtitle {
    return switch (_currentIndex) {
      0 => 'Your connected environment',
      1 => 'Manage your devices',
      2 => 'Stay informed',
      _ => 'Your connected environment',
    };
  }

  void _onDestinationSelected(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _openDrawer() {
    final scaffoldState = _scaffoldKey.currentState;

    if (scaffoldState == null) {
      debugPrint('MainNavigationShell: ScaffoldState is not available.');
      return;
    }

    if (scaffoldState.isDrawerOpen) {
      return;
    }

    scaffoldState.openDrawer();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: widget.profileBuilder ?? (_) => ProfilePage()),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      drawer: AppDrawer(
        currentIndex: _currentIndex,
        onPrimaryDestinationSelected: _onDestinationSelected,
        onProfileSelected: _openProfile,
        onSignOut: _signOut,
      ),

      appBar: AppTopBar(
        title: _currentSectionTitle,
        subtitle: _currentSectionSubtitle,
        onMenuPressed: _openDrawer,
        onProfilePressed: _openProfile,
      ),

      body: IndexedStack(index: _currentIndex, children: _pages),

      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
