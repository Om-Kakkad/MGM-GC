import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'package:mgm_gc/pages/tee_times/my_bookings_page.dart';
import 'package:mgm_gc/pages/tee_times/tee_times_page.dart' as tee_times;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingEvents = [];
  int _upcomingBookingsCount = 0;

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
      _loadDashboardData();
    } else {
      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load upcoming events
      final eventsSnapshot =
          await _firestore
              .collection('events')
              .where('date', isGreaterThanOrEqualTo: DateTime.now())
              .orderBy('date')
              .limit(3)
              .get();

      final events =
          eventsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['eventName'] ?? 'Unnamed Event',
              'type': data['eventType'] ?? 'Unknown',
              'date': data['date']?.toDate() ?? DateTime.now(),
            };
          }).toList();

      // Get upcoming bookings count (simplified - you might want to implement proper booking service)
      // For now, we'll just set a placeholder
      final bookingsCount = 0; // TODO: Implement actual booking count

      setState(() {
        _upcomingEvents = events;
        _upcomingBookingsCount = bookingsCount;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MGM Golf Club',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeCard(),
              const SizedBox(height: 24),

              // Quick Actions Grid
              _buildQuickActionsSection(),
              const SizedBox(height: 24),

              // Dashboard Cards
              _buildDashboardCards(),
              const SizedBox(height: 24),

              // Upcoming Events Section
              if (_upcomingEvents.isNotEmpty) ...[
                _buildUpcomingEventsSection(),
                const SizedBox(height: 24),
              ],

              // Quick Stats (if league player)
              if (_currentUser?.role == 'league_player') ...[
                _buildQuickStatsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xff0D6EFD),
              const Color(0xff0D6EFD).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.waving_hand,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: GoogleFonts.raleway(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _getUserDisplayName(),
                        style: GoogleFonts.raleway(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ready for your next round? ${DateFormat('EEEE, MMMM d').format(DateTime.now())}',
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    // Quick stats for league players, or club news for regular users
    if (_currentUser?.role == 'league_player') {
      return _buildLeaguePlayerQuickStats();
    } else {
      return _buildClubNewsSection();
    }
  }

  Widget _buildLeaguePlayerQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your League Progress',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickStatCard(
                'Handicap',
                _currentUser?.golfDetails.handicap?.toStringAsFixed(1) ?? 'N/A',
                Icons.sports_golf,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickStatCard(
                'Team',
                _currentUser?.golfDetails.teamName ?? 'No Team',
                Icons.group,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickStatCard(
                'Bracket',
                _currentUser?.golfDetails.bracket ?? 'N/A',
                Icons.emoji_events,
                Colors.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickStatCard(
                'Status',
                _currentUser?.golfDetails.isMember == true ? 'Member' : 'Guest',
                Icons.card_membership,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClubNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Club News & Updates',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.announcement, color: Color(0xff0D6EFD)),
                    const SizedBox(width: 8),
                    Text(
                      'Welcome to MGM Golf Club!',
                      style: GoogleFonts.raleway(
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Use the sidebar menu to navigate through different sections including tee time booking, events, teams, and more. League players can access additional features through the League section.',
                  style: GoogleFonts.raleway(
                    textStyle: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              title,
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Upcoming Bookings',
            _upcomingBookingsCount.toString(),
            Icons.bookmark,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Events',
            _upcomingEvents.length.toString(),
            Icons.event_available,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: GoogleFonts.raleway(
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Events',
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/events'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    event['type'] == 'League'
                                        ? Colors.blue.shade100
                                        : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                event['type'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      event['type'] == 'League'
                                          ? Colors.blue.shade700
                                          : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event['name'],
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(event['date']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My League Info',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentUser?.golfDetails.teamName != null) ...[
                  _buildInfoRow('Team', _currentUser!.golfDetails.teamName!),
                  const SizedBox(height: 12),
                ],
                if (_currentUser?.golfDetails.handicap != null) ...[
                  _buildInfoRow(
                    'Handicap',
                    _currentUser!.golfDetails.handicap!.toStringAsFixed(1),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_currentUser?.golfDetails.bracket != null) ...[
                  _buildInfoRow('Bracket', _currentUser!.golfDetails.bracket!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/league'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0D6EFD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('View League Features'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xff0D6EFD)),
                ),
                const SizedBox(height: 12),
                Text(
                  _getUserDisplayName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getRoleDisplayName(_currentUser?.role ?? 'user'),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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
          ListTile(
            title: const Text('Profile'),
            leading: const Icon(Icons.person),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            title: const Text('Book Tee Time'),
            leading: const Icon(Icons.timer),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const tee_times.TeeTimesPage(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('My Bookings'),
            leading: const Icon(Icons.calendar_today),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyBookingsPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Events'),
            leading: const Icon(Icons.event),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/events');
            },
          ),
          ListTile(
            title: const Text('Teams'),
            leading: const Icon(Icons.group),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/teams');
            },
          ),
          ListTile(
            title: const Text('Sponsors'),
            leading: const Icon(Icons.business),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/sponsors');
            },
          ),
          const Divider(),
          // Role-specific menu items
          if (_currentUser?.role == 'league_player')
            ListTile(
              title: const Text('League Features'),
              leading: const Icon(Icons.sports),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/league');
              },
            ),
          if (_currentUser?.role != 'league_player' &&
              _currentUser?.role != 'admin')
            ListTile(
              title: const Text('Join League'),
              leading: const Icon(Icons.sports_golf),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/join-team');
              },
            ),
          if (_currentUser?.role == 'admin')
            ListTile(
              title: const Text('Admin Panel'),
              leading: const Icon(Icons.admin_panel_settings),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin');
              },
            ),
          const Divider(),
          ListTile(
            title: const Text('Logout'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () async {
              Navigator.pop(context);
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  String _getUserDisplayName() {
    if (_currentUser == null) return 'User';

    final fullName =
        '${_currentUser!.firstName ?? ''} ${_currentUser!.lastName ?? ''}'
            .trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    return _currentUser!.email.split('@').first;
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'league_player':
        return 'League Player';
      case 'user':
        return 'Member';
      default:
        return 'User';
    }
  }
}
