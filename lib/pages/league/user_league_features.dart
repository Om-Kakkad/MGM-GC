import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class UserLeagueFeatures extends StatefulWidget {
  const UserLeagueFeatures({super.key});

  @override
  _UserLeagueFeaturesState createState() => _UserLeagueFeaturesState();
}

class _UserLeagueFeaturesState extends State<UserLeagueFeatures> {
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
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('League Features')),
      body: DefaultTabController(
        length: 3, // Updated to include Stats tab
        child: Column(
          children: [
            TabBar(
              labelColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.scoreboard), text: 'Live Scores'),
                Tab(icon: Icon(Icons.business), text: 'Sponsors'),
                Tab(icon: Icon(Icons.emoji_events), text: 'Stats'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLiveScoresTab(),
                  _buildSponsorsTab(),
                  _buildStatsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Live Scores Tab
  Widget _buildLiveScoresTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.scoreboard, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'View Live Match Scores',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check ongoing match scores in real-time',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('View Live Scores'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0D6EFD),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/live-scores');
            },
          ),
        ],
      ),
    );
  }

  // Sponsors Tab
  Widget _buildSponsorsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'View Our Sponsors',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check out the sponsors supporting our events',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('View Sponsors'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0D6EFD),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/sponsors');
            },
          ),
        ],
      ),
    );
  }

  // Stats Tab
  Widget _buildStatsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'Awards & Statistics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'View player awards, achievements and fun statistics',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('View Stats & Awards'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0D6EFD),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/stats');
            },
          ),
        ],
      ),
    );
  }
}
