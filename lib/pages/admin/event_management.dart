import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mgm_gc/services/delete_service.dart';

class EventManagementPage extends StatefulWidget {
  const EventManagementPage({super.key});

  @override
  _EventManagementPageState createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeleteService _deleteService = DeleteService();
  bool _isLoading = false;
  List<DocumentSnapshot> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('events')
              .orderBy('eventDates', descending: true)
              .get();

      setState(() {
        _events = querySnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading events: $e')));
    }
  }

  Future<void> _deleteEvent(String eventId, String eventName) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Event'),
                content: Text(
                  'Are you sure you want to delete "$eventName"? This will also delete all teams and matches associated with this event.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _deleteService.deleteEventWithCascade(eventId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted successfully')),
      );

      _loadEvents();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting event: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Event Management',
          style: GoogleFonts.raleway(
            textStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Events',
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to event creation form
                            // Replace with your actual navigation
                            Navigator.pushNamed(
                              context,
                              '/create-event',
                            ).then((_) => _loadEvents());
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Event'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0D6EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child:
                        _events.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.event,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No events available',
                                    style: GoogleFonts.raleway(
                                      textStyle: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Click "Create Event" to add a new event',
                                    style: GoogleFonts.raleway(
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _events.length,
                              itemBuilder: (context, index) {
                                final eventDoc = _events[index];
                                final eventData =
                                    eventDoc.data() as Map<String, dynamic>;

                                final String eventName =
                                    eventData['eventName'] ?? 'Unnamed Event';
                                final String eventType =
                                    eventData['eventType'] ?? '';

                                // Format dates
                                String dateText = 'No dates';
                                if (eventData['eventDates'] != null) {
                                  final datesList =
                                      (eventData['eventDates'] as List)
                                          .map(
                                            (date) =>
                                                (date as Timestamp).toDate(),
                                          )
                                          .toList();

                                  if (datesList.isNotEmpty) {
                                    final formatter = DateFormat('MMM d, yyyy');
                                    if (datesList.length > 1) {
                                      dateText =
                                          '${formatter.format(datesList.first)} - ${formatter.format(datesList.last)}';
                                    } else {
                                      dateText = formatter.format(
                                        datesList.first,
                                      );
                                    }
                                  }
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                eventName,
                                                style: GoogleFonts.raleway(
                                                  textStyle: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Chip(
                                              label: Text(eventType),
                                              backgroundColor:
                                                  eventType == 'League'
                                                      ? Colors.blue.shade100
                                                      : Colors.orange.shade100,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Dates: $dateText',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (eventData['eventDescription'] !=
                                            null)
                                          Text(
                                            eventData['eventDescription'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // View Details button
                                            OutlinedButton(
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/event-details',
                                                  arguments: eventDoc.id,
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text('View Details'),
                                            ),
                                            const SizedBox(width: 8),
                                            // Delete button
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed:
                                                  () => _deleteEvent(
                                                    eventDoc.id,
                                                    eventName,
                                                  ),
                                            ),
                                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEvents,
        backgroundColor: const Color(0xff0D6EFD),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
