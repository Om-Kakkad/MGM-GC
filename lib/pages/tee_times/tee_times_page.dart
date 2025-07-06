import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mgm_gc/models/tee_time_model.dart';
import 'package:mgm_gc/services/tee_time_service.dart';
import 'package:mgm_gc/pages/tee_times/dummy_payment_page.dart';
import 'package:mgm_gc/models/booking_model.dart'; // Replace player_info import with booking_model
import 'package:mgm_gc/pages/tee_times/player_selection_dialog.dart';

class TeeTimesPage extends StatefulWidget {
  const TeeTimesPage({super.key});

  @override
  _TeeTimesPageState createState() => _TeeTimesPageState();
}

class _TeeTimesPageState extends State<TeeTimesPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _playerNamesController = TextEditingController();
  List<PlayerInfo> _selectedPlayers = [];

  @override
  Widget build(BuildContext context) {
    final teeTimeService = Provider.of<TeeTimeService>(context);
    String dateId = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Ensure slots exist for the selected date
    teeTimeService.ensureSlotsExistForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tee Times'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Tee Times for ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TeeTimeModel>>(
              stream: teeTimeService.getTeeTimes(dateId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final teeTimes = snapshot.data ?? [];
                if (teeTimes.isEmpty) {
                  return Center(
                    child: Text('No tee times available for this date'),
                  );
                }

                return ListView.builder(
                  itemCount: teeTimes.length,
                  itemBuilder: (context, index) {
                    final teeTime = teeTimes[index];
                    return TeeTimeCard(
                      teeTime: teeTime,
                      dateId: dateId,
                      onPlayerNames: (players) {
                        _playerNamesController.text = players.join(", ");
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectPlayers(BuildContext context) async {
    final List<PlayerInfo>? result = await showDialog<List<PlayerInfo>>(
      context: context,
      builder:
          (context) => PlayerSelectionDialog(
            initialPlayers:
                _playerNamesController.text.isNotEmpty
                    ? _playerNamesController.text
                        .split(',')
                        .map(
                          (name) => PlayerInfo(
                            name: name.trim(),
                            isRegistered: false,
                          ),
                        )
                        .toList()
                    : [],
          ),
    );

    if (result != null) {
      // Update the controller with the player names
      _playerNamesController.text = result
          .map((player) => player.name)
          .join(', ');

      // Store the full player info for use when booking
      setState(() {
        _selectedPlayers = result;
      });
    }
  }

  Future<void> _bookTeeTime(
    BuildContext context,
    String dateId,
    TeeTimeModel teeTime,
  ) async {
    final teeTimeService = Provider.of<TeeTimeService>(context, listen: false);

    // Determine if current user is a member for display purposes
    final isMember = await teeTimeService.isUserMember();

    // Show booking confirmation dialog
    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Booking'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time: ${DateFormat('HH:mm').format(teeTime.startTime)}',
                    ),
                    const SizedBox(height: 8),
                    Text('Price: ${isMember ? '\$15.00' : '\$25.00'}'),
                    const SizedBox(height: 8),
                    Text(
                      'Players: ${_selectedPlayers.isEmpty ? 'None' : _selectedPlayers.map((p) => p.name).join(", ")}',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Book Now'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    // For a real payment flow, navigate to payment page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DummyPaymentPage(
              dateId: dateId,
              teeTimeId: teeTime.id,
              players: _selectedPlayers,
              startTime: teeTime.startTime, // Add the startTime parameter
            ),
      ),
    );
  }
}

class TeeTimeCard extends StatelessWidget {
  final TeeTimeModel teeTime;
  final String dateId;
  final Function(List<String>) onPlayerNames;

  const TeeTimeCard({
    super.key,
    required this.teeTime,
    required this.dateId,
    required this.onPlayerNames,
  });

  @override
  Widget build(BuildContext context) {
    final teeTimeService = Provider.of<TeeTimeService>(context, listen: false);
    final statusColor = _getStatusColor(teeTime.status);
    final isAvailable = teeTime.status == TeeTimeStatus.open;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Text(
            DateFormat('HH:mm').format(teeTime.startTime),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          'Tee Time: ${DateFormat('HH:mm').format(teeTime.startTime)} - ${DateFormat('HH:mm').format(teeTime.endTime)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_getStatusText(teeTime)),
        trailing:
            isAvailable
                ? ElevatedButton(
                  onPressed: () => _showBookingDialog(context, teeTimeService),
                  child: const Text('Book'),
                )
                : null,
      ),
    );
  }

  Color _getStatusColor(TeeTimeStatus status) {
    switch (status) {
      case TeeTimeStatus.open:
        return Colors.green;
      case TeeTimeStatus.held:
        return Colors.orange;
      case TeeTimeStatus.booked:
        return Colors.red;
      case TeeTimeStatus.blocked:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(TeeTimeModel teeTime) {
    switch (teeTime.status) {
      case TeeTimeStatus.open:
        return 'Available';
      case TeeTimeStatus.held:
        return 'Temporarily Reserved';
      case TeeTimeStatus.booked:
        return 'Booked';
      case TeeTimeStatus.blocked:
        return 'Blocked${teeTime.reason != null ? ': ${teeTime.reason}' : ''}';
      default:
        return 'Unknown';
    }
  }

  Future<void> _showBookingDialog(
    BuildContext context,
    TeeTimeService teeTimeService,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool isMember = await teeTimeService.isUserMember();
    List<PlayerInfo> selectedPlayers = [];

    // For search UI
    final TextEditingController _searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    // For manual entry
    final TextEditingController _manualNameController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Function to handle search
            Future<void> searchUsers(String query) async {
              if (query.isEmpty) {
                setState(() {
                  searchResults = [];
                  isSearching = false;
                });
                return;
              }

              setState(() {
                isSearching = true;
              });

              final results = await teeTimeService.searchUsers(query);

              // Filter out users that are already selected
              final filteredResults =
                  results.where((user) {
                    return !selectedPlayers.any(
                      (player) =>
                          player.isRegistered && player.userId == user['id'],
                    );
                  }).toList();

              setState(() {
                searchResults = filteredResults;
                isSearching = false;
              });
            }

            // Function to add a registered user
            void addRegisteredPlayer(Map<String, dynamic> userData) {
              final newPlayer = PlayerInfo(
                name: userData['name'],
                userId: userData['id'],
                isRegistered: true,
              );

              // Only add if not already in the list
              if (!selectedPlayers.any(
                (player) =>
                    player.isRegistered && player.userId == userData['id'],
              )) {
                setState(() {
                  selectedPlayers.add(newPlayer);
                  _searchController.clear();
                  searchResults = [];
                });
              }
            }

            // Function to add a manually entered player
            void addManualPlayer() {
              final name = _manualNameController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  selectedPlayers.add(
                    PlayerInfo(name: name, isRegistered: false),
                  );
                  _manualNameController.clear();
                });
              }
            }

            // Function to remove a player
            void removePlayer(int index) {
              setState(() {
                selectedPlayers.removeAt(index);
              });
            }

            return Dialog(
              // Set maximum width and height constraints
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dialog header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Book Tee Time at ${DateFormat('HH:mm').format(teeTime.startTime)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Dialog content - scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search for registered users
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: 'Search for users',
                                  hintText: 'Enter email or name',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.length >= 3) {
                                    searchUsers(value);
                                  } else if (value.isEmpty) {
                                    setState(() {
                                      searchResults = [];
                                    });
                                  }
                                },
                              ),

                              // Search results with fixed height
                              if (isSearching)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (searchResults.isNotEmpty)
                                Container(
                                  height:
                                      150, // Fixed height prevents layout issues
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    // Remove shrinkWrap which was causing the issue
                                    itemCount: searchResults.length,
                                    itemBuilder: (context, index) {
                                      final user = searchResults[index];
                                      return ListTile(
                                        title: Text(user['name']),
                                        subtitle: Text(user['email']),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          onPressed:
                                              () => addRegisteredPlayer(user),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Add non-registered player
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _manualNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Add player by name',
                                        hintText: 'Enter player name',
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) => addManualPlayer(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle),
                                    onPressed: addManualPlayer,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Selected players list
                              const Text(
                                'Selected Players:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              if (selectedPlayers.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('No players selected'),
                                )
                              else
                                Container(
                                  height: 150, // Fixed height here too
                                  child: ListView.builder(
                                    // Remove shrinkWrap which was causing the issue
                                    itemCount: selectedPlayers.length,
                                    itemBuilder: (context, index) {
                                      final player = selectedPlayers[index];
                                      return ListTile(
                                        leading: Icon(
                                          player.isRegistered
                                              ? Icons.account_circle
                                              : Icons.person_outline,
                                          color:
                                              player.isRegistered
                                                  ? Colors.blue
                                                  : Colors.grey,
                                        ),
                                        title: Text(player.name),
                                        subtitle:
                                            player.isRegistered
                                                ? const Text(
                                                  'Registered User',
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                  ),
                                                )
                                                : const Text('Guest Player'),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => removePlayer(index),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 16),
                              Text(
                                isMember
                                    ? 'Member Status: Active (Free Booking)'
                                    : 'Guest Status: Payment Required',
                                style: TextStyle(
                                  color:
                                      isMember ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Dialog actions
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (selectedPlayers.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select at least one player',
                                    ),
                                  ),
                                );
                                return;
                              }

                              // Update to pass the player names to the onPlayerNames callback
                              onPlayerNames(
                                selectedPlayers.map((p) => p.name).toList(),
                              );

                              if (isMember) {
                                // Direct booking for members
                                bool success = await teeTimeService.bookTeeTime(
                                  dateId,
                                  teeTime.id,
                                  selectedPlayers, // Pass the list of PlayerInfo objects
                                );

                                Navigator.of(context).pop();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Tee time booked successfully!'
                                          : 'Failed to book tee time. Please try again.',
                                    ),
                                    backgroundColor:
                                        success ? Colors.green : Colors.red,
                                  ),
                                );
                              } else {
                                // Hold the slot and go to payment page for guests
                                bool success = await teeTimeService.holdTeeTime(
                                  dateId,
                                  teeTime.id,
                                );

                                if (success) {
                                  Navigator.of(context).pop();

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => DummyPaymentPage(
                                            dateId: dateId,
                                            teeTimeId: teeTime.id,
                                            startTime: teeTime.startTime,
                                            players: selectedPlayers,
                                          ),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).pop();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to reserve tee time. Please try again.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              isMember
                                  ? 'Book Now (Free)'
                                  : 'Proceed to Payment',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
