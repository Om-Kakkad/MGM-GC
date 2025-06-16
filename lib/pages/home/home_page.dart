import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_authService.currentUser != null) {
      UserModel userData = await _authService.getUserData(
        _authService.currentUser!.uid,
      );
      setState(() {
        _currentUser = userData;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _currentUser?.email ?? '',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            // Common menu items for all users
            ListTile(
              title: const Text('Home'),
              leading: const Icon(Icons.home),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            // Events menu item - available for all users
            ListTile(
              title: const Text('Events'),
              leading: const Icon(Icons.event),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/events');
              },
            ),
            // Sponsors menu item - available for all users
            ListTile(
              title: const Text('Sponsors'),
              leading: const Icon(Icons.business),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/sponsors');
              },
            ),
            // League Features for regular users
            if (_currentUser?.role != 'league_player' &&
                _currentUser?.role != 'admin') ...[
              ListTile(
                title: const Text('League Features'),
                leading: const Icon(Icons.sports_golf),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/user-league');
                },
              ),
            ],
            // Admin-specific menu items
            if (_currentUser?.role == 'admin') ...[
              ListTile(
                title: const Text('Admin Panel'),
                leading: const Icon(Icons.admin_panel_settings),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin');
                },
              ),
            ],
            // League player-specific menu items
            if (_currentUser?.role == 'league_player') ...[
              ListTile(
                title: const Text('League Features'),
                leading: const Icon(Icons.sports),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/league');
                },
              ),
            ],
          ],
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Welcome, ${_currentUser?.email}'),
                const SizedBox(height: 20),
                Text('Role: ${_currentUser?.role}'),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/events');
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('View Upcoming Events'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0D6EFD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
