import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
        title: Text(
          'My Profile',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
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
                  children: [
                    // Profile Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    // User Name
                    Text(
                      '${_currentUser?.firstName ?? ''} ${_currentUser?.lastName ?? ''}'
                              .trim()
                              .isEmpty
                          ? _currentUser?.email ?? 'User'
                          : '${_currentUser?.firstName ?? ''} ${_currentUser?.lastName ?? ''}',
                      style: GoogleFonts.raleway(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getRoleDisplayName(_currentUser?.role ?? 'user'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Personal Information Card
            _buildInfoCard('Personal Information', Icons.person_outline, [
              _buildInfoRow('Email', _currentUser?.email ?? 'Not provided'),
              if (_currentUser?.phoneNumber != null &&
                  _currentUser!.phoneNumber!.isNotEmpty)
                _buildInfoRow('Phone', _currentUser!.phoneNumber!),
              if (_currentUser?.gender != null &&
                  _currentUser!.gender!.isNotEmpty)
                _buildInfoRow('Gender', _currentUser!.gender!),
              if (_currentUser?.dateOfBirth != null)
                _buildInfoRow(
                  'Date of Birth',
                  DateFormat('MMM d, yyyy').format(_currentUser!.dateOfBirth!),
                ),
            ]),

            const SizedBox(height: 16),

            // Golf Information Card
            _buildInfoCard('Golf Information', Icons.sports_golf, [
              _buildInfoRow(
                'Membership Status',
                _currentUser?.golfDetails.isMember == true
                    ? 'Member'
                    : 'Non-Member',
              ),
              if (_currentUser?.golfDetails.membershipId != null &&
                  _currentUser!.golfDetails.membershipId!.isNotEmpty)
                _buildInfoRow(
                  'Membership ID',
                  _currentUser!.golfDetails.membershipId!,
                ),
              if (_currentUser?.golfDetails.handicap != null)
                _buildInfoRow(
                  'Handicap',
                  _currentUser!.golfDetails.handicap!.toStringAsFixed(1),
                ),
              _buildInfoRow(
                'League Participation',
                _currentUser?.golfDetails.playingInLeague == true
                    ? 'Yes'
                    : 'No',
              ),
              if (_currentUser?.golfDetails.teamName != null &&
                  _currentUser!.golfDetails.teamName!.isNotEmpty)
                _buildInfoRow('Team', _currentUser!.golfDetails.teamName!),
              if (_currentUser?.golfDetails.bracket != null &&
                  _currentUser!.golfDetails.bracket!.isNotEmpty)
                _buildInfoRow('Bracket', _currentUser!.golfDetails.bracket!),
            ]),

            const SizedBox(height: 16),

            // Account Information Card
            _buildInfoCard('Account Information', Icons.info_outline, [
              if (_currentUser?.createdAt != null)
                _buildInfoRow(
                  'Member Since',
                  DateFormat('MMM d, yyyy').format(_currentUser!.createdAt!),
                ),
              if (_currentUser?.updatedAt != null)
                _buildInfoRow(
                  'Last Updated',
                  DateFormat('MMM d, yyyy').format(_currentUser!.updatedAt!),
                ),
            ]),

            const SizedBox(height: 24),

            // Action Buttons
            if (_currentUser?.role != 'admin')
              Column(
                children: [
                  // Edit Profile Button (placeholder for future implementation)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/edit-profile');
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0D6EFD),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _authService.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xff0D6EFD), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.raleway(
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.raleway(
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
