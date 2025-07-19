import 'package:flutter/material.dart';
import '../../services/stats_service.dart';
import '../../services/match_service.dart';
import '../../services/auth_service.dart';
import '../../models/award_model.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final StatsService _statsService = StatsService();
  final MatchService _matchService = MatchService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _events = [];
  String? _selectedEventId;
  List<AwardCategory> _awards = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      final events = await _matchService.getLeagueEvents();
      setState(() {
        _events = events;
        if (events.isNotEmpty) {
          _selectedEventId = events.first['id'];
          _loadAwards(_selectedEventId!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
      }
    }
  }

  Future<void> _loadAwards(String eventId) async {
    setState(() => _isLoading = true);

    try {
      final awards = await _statsService.getEventAwards(eventId);
      setState(() {
        _awards = awards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load awards: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stats & Awards',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_selectedEventId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadAwards(_selectedEventId!),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header section with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Welcome message
                if (_currentUserId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'See how you rank among your fellow golfers!',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Event selector
                if (_events.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Event',
                        prefixIcon: const Icon(Icons.event),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedEventId,
                      items:
                          _events.map((event) {
                            return DropdownMenuItem<String>(
                              value: event['id'],
                              child: Text(
                                event['eventName'] ?? 'Unnamed Event',
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedEventId = value);
                          _loadAwards(value);
                        }
                      },
                    ),
                  ),

                // Stats summary
                if (_awards.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Awards',
                            '${_awards.length}',
                            Icons.emoji_events,
                            Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Active Categories',
                            '${_awards.where((a) => a.stats.isNotEmpty).length}',
                            Icons.leaderboard,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Awards list
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading amazing stats...'),
                        ],
                      ),
                    )
                    : _selectedEventId == null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Please select an event',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose an event to view awards and statistics',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                    : _awards.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No awards data available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Play some matches to see awards here!',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _awards.length,
                      itemBuilder: (context, index) {
                        final award = _awards[index];
                        return _buildAwardCard(award);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAwardCard(AwardCategory awardCategory) {
    final award = awardCategory.award;
    final hasStats = awardCategory.stats.isNotEmpty;
    final topPerformer = hasStats ? awardCategory.stats.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasStats ? () => _showAwardDetails(awardCategory) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient:
                hasStats
                    ? LinearGradient(
                      colors: [
                        _getAwardColor(award.color).withOpacity(0.05),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Award icon with animation
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _getAwardColor(award.color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: _getAwardColor(award.color).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getAwardIcon(award.iconName),
                        color: _getAwardColor(award.color),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Award info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  award.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (award.isPositive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    '🏆',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    '😅',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            award.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow or status
                    Icon(
                      hasStats
                          ? Icons.arrow_forward_ios
                          : Icons.hourglass_empty,
                      color:
                          hasStats
                              ? _getAwardColor(award.color)
                              : Colors.grey[300],
                      size: 16,
                    ),
                  ],
                ),

                // Top performer preview
                if (hasStats && topPerformer != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getAwardColor(award.color).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getAwardColor(award.color).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: _getAwardColor(award.color),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Leader: ${topPerformer.playerName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _getAwardColor(award.color),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          topPerformer.displayValue,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getAwardColor(award.color),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!hasStats) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No data available yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (hasStats) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap to view all ${awardCategory.stats.length} entries',
                    style: TextStyle(
                      color: _getAwardColor(award.color),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAwardDetails(AwardCategory awardCategory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) =>
                    _buildAwardDetailsSheet(awardCategory, scrollController),
          ),
    );
  }

  Widget _buildAwardDetailsSheet(
    AwardCategory awardCategory,
    ScrollController scrollController,
  ) {
    final award = awardCategory.award;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with gradient background
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getAwardColor(award.color).withOpacity(0.1),
                          _getAwardColor(award.color).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _getAwardColor(award.color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: _getAwardColor(
                                  award.color,
                                ).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getAwardIcon(award.iconName),
                            color: _getAwardColor(award.color),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      award.title,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          award.isPositive
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            award.isPositive
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.orange.withOpacity(
                                                  0.3,
                                                ),
                                      ),
                                    ),
                                    child: Text(
                                      award.isPositive
                                          ? '🏆 Achievement'
                                          : '😅 Fun Stats',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                award.description,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats count header
                  Row(
                    children: [
                      Icon(
                        Icons.leaderboard,
                        color: _getAwardColor(award.color),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Rankings (${awardCategory.stats.length} entries)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getAwardColor(award.color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats list
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: awardCategory.stats.length,
                      itemBuilder: (context, index) {
                        final stat = awardCategory.stats[index];
                        final isCurrentUser =
                            stat.playerId == _currentUserId ||
                            (stat.additionalData['playerIds'] as List<String>?)
                                    ?.contains(_currentUserId) ==
                                true;
                        final isTopThree = index < 3;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color:
                                isCurrentUser
                                    ? Colors.amber.withOpacity(0.1)
                                    : isTopThree
                                    ? _getAwardColor(
                                      award.color,
                                    ).withOpacity(0.05)
                                    : null,
                            border:
                                isCurrentUser
                                    ? Border.all(color: Colors.amber, width: 2)
                                    : isTopThree
                                    ? Border.all(
                                      color: _getAwardColor(
                                        award.color,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    )
                                    : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow:
                                isCurrentUser || isTopThree
                                    ? [
                                      BoxShadow(
                                        color: (isCurrentUser
                                                ? Colors.amber
                                                : _getAwardColor(award.color))
                                            .withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    isTopThree
                                        ? _getTopThreeColor(index)
                                        : _getAwardColor(
                                          award.color,
                                        ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    isTopThree
                                        ? Border.all(
                                          color: _getTopThreeColor(index),
                                          width: 2,
                                        )
                                        : null,
                              ),
                              child: Center(
                                child:
                                    isTopThree
                                        ? Text(
                                          _getTopThreeEmoji(index),
                                          style: const TextStyle(fontSize: 18),
                                        )
                                        : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: _getAwardColor(award.color),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    stat.playerName,
                                    style: TextStyle(
                                      fontWeight:
                                          isTopThree
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                      fontSize: isTopThree ? 16 : 15,
                                    ),
                                  ),
                                ),
                                if (isCurrentUser)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (stat.teamName != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.group,
                                          size: 12,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          stat.teamName!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getAwardColor(
                                        award.color,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      stat.displayValue,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getAwardColor(award.color),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTopThreeEmoji(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '';
    }
  }

  Color _getTopThreeColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  IconData _getAwardIcon(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'group':
        return Icons.group;
      case 'golf_course':
        return Icons.golf_course;
      case 'flutter_dash':
        return Icons.flash_on; // Better than flight_takeoff for birdies
      case 'sentiment_dissatisfied':
        return Icons.sentiment_dissatisfied;
      case 'sentiment_very_dissatisfied':
        return Icons.sentiment_very_dissatisfied;
      case 'trending_up':
        return Icons.trending_up;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getAwardColor(String colorName) {
    switch (colorName) {
      case 'gold':
        return Colors.amber;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'grey':
        return Colors.grey;
      case 'purple':
        return Colors.purple;
      case 'cyan':
        return Colors.cyan;
      default:
        return Colors.blue;
    }
  }
}
