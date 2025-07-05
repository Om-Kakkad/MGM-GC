import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mgm_gc/models/tee_time_model.dart';
import 'package:mgm_gc/services/tee_time_service.dart';
import 'package:mgm_gc/utils/seed_slots.dart';

class SlotsManagementPage extends StatefulWidget {
  const SlotsManagementPage({super.key});

  @override
  _SlotsManagementPageState createState() => _SlotsManagementPageState();
}

class _SlotsManagementPageState extends State<SlotsManagementPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isGeneratingSlots = false;

  @override
  Widget build(BuildContext context) {
    final teeTimeService = Provider.of<TeeTimeService>(context);
    String dateId = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Ensure slots exist for the selected date
    teeTimeService.ensureSlotsExistForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tee Time Slots'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed:
                _isGeneratingSlots
                    ? null
                    : () => _showGenerateSlotsDialog(context, dateId),
          ),
          // Add delete all slots button
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed:
                () =>
                    _showDeleteAllSlotsDialog(context, teeTimeService, dateId),
            tooltip: 'Delete All Slots for This Date',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Slots for ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}',
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No slots available for this date'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed:
                              _isGeneratingSlots
                                  ? null
                                  : () =>
                                      _showGenerateSlotsDialog(context, dateId),
                          child:
                              _isGeneratingSlots
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text('Generate Slots'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: teeTimes.length,
                  itemBuilder: (context, index) {
                    final teeTime = teeTimes[index];
                    return AdminSlotCard(teeTime: teeTime, dateId: dateId);
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
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _showGenerateSlotsDialog(
    BuildContext context,
    String dateId,
  ) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Generate Tee Time Slots'),
          content: const Text(
            'This will create 15-minute tee time slots from 06:00 to 17:45 for the selected date. Continue?',
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
                Navigator.of(context).pop();
                setState(() {
                  _isGeneratingSlots = true;
                });

                try {
                  await SeedSlots.generateSlotsForDate(_selectedDate);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Slots generated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error generating slots: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() {
                    _isGeneratingSlots = false;
                  });
                }
              },
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );
  }

  // Add this method to show delete confirmation dialog
  Future<void> _showDeleteAllSlotsDialog(
    BuildContext context,
    TeeTimeService teeTimeService,
    String dateId,
  ) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Slots'),
          content: Text(
            'Are you sure you want to delete ALL slots for ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deleting slots...')),
                );

                // Delete all slots
                bool success = await teeTimeService.deleteAllSlotsForDate(
                  dateId,
                );

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All slots deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete slots'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }
}

class AdminSlotCard extends StatelessWidget {
  final TeeTimeModel teeTime;
  final String dateId;

  const AdminSlotCard({super.key, required this.teeTime, required this.dateId});

  @override
  Widget build(BuildContext context) {
    final teeTimeService = Provider.of<TeeTimeService>(context, listen: false);
    final isBlocked = teeTime.status == TeeTimeStatus.blocked;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(teeTime.status),
          child: Text(
            DateFormat('HH:mm').format(teeTime.startTime),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          'Tee Time: ${DateFormat('HH:mm').format(teeTime.startTime)} - ${DateFormat('HH:mm').format(teeTime.endTime)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getStatusText(teeTime)),
            if (teeTime.bookedByUid != null &&
                teeTime.status == TeeTimeStatus.booked)
              Text('Booked by: ${teeTime.bookedByUid}'),
            if (teeTime.players.isNotEmpty)
              Text('Players: ${teeTime.players.join(", ")}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Block/Unblock button
            isBlocked
                ? IconButton(
                  icon: const Icon(Icons.lock_open, color: Colors.green),
                  onPressed: () => _unblockSlot(context, teeTimeService),
                )
                : IconButton(
                  icon: const Icon(Icons.block, color: Colors.orange),
                  onPressed: () => _showBlockDialog(context, teeTimeService),
                ),
            // Add delete button
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteSlotDialog(context, teeTimeService),
              tooltip: 'Delete Slot',
            ),
          ],
        ),
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

  Future<void> _showBlockDialog(
    BuildContext context,
    TeeTimeService teeTimeService,
  ) async {
    final reasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Block Slot ${DateFormat('HH:mm').format(teeTime.startTime)}',
          ),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason for blocking',
              hintText: 'e.g., Maintenance, Tournament, etc.',
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
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a reason for blocking'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();

                try {
                  await teeTimeService.blockSlot(dateId, teeTime.id, reason);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Slot blocked successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error blocking slot: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unblockSlot(
    BuildContext context,
    TeeTimeService teeTimeService,
  ) async {
    try {
      await teeTimeService.unblockSlot(dateId, teeTime.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot unblocked successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error unblocking slot: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method to show delete confirmation dialog
  Future<void> _showDeleteSlotDialog(
    BuildContext context,
    TeeTimeService teeTimeService,
  ) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Slot'),
          content: Text(
            'Are you sure you want to delete this slot (${DateFormat('HH:mm').format(teeTime.startTime)})?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();

                bool success = await teeTimeService.deleteSlot(
                  dateId,
                  teeTime.id,
                );

                if (success && Navigator.canPop(context)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Slot deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (Navigator.canPop(context)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete slot'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
