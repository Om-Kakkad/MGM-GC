import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mgm_gc/models/tee_time_model.dart';
import 'package:mgm_gc/services/tee_time_service.dart';
import 'package:mgm_gc/pages/tee_times/dummy_payment_page.dart';

class TeeTimesPage extends StatefulWidget {
  const TeeTimesPage({super.key});

  @override
  _TeeTimesPageState createState() => _TeeTimesPageState();
}

class _TeeTimesPageState extends State<TeeTimesPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _playerNamesController = TextEditingController();

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
    final playerNamesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isMember = await teeTimeService.isUserMember();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Book Tee Time at ${DateFormat('HH:mm').format(teeTime.startTime)}',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: playerNamesController,
                  decoration: const InputDecoration(
                    labelText: 'Player Names (comma separated)',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter player names';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  isMember
                      ? 'Member Status: Active (Free Booking)'
                      : 'Guest Status: Payment Required',
                  style: TextStyle(
                    color: isMember ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  List<String> players =
                      playerNamesController.text
                          .split(',')
                          .map((name) => name.trim())
                          .where((name) => name.isNotEmpty)
                          .toList();

                  onPlayerNames(players);

                  if (isMember) {
                    // Direct booking for members
                    bool success = await teeTimeService.bookTeeTime(
                      dateId,
                      teeTime.id,
                      players,
                    );

                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Tee time booked successfully!'
                              : 'Failed to book tee time. Please try again.',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
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
                                players: players,
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
                }
              },
              child: Text(isMember ? 'Book Now (Free)' : 'Proceed to Payment'),
            ),
          ],
        );
      },
    );
  }
}
