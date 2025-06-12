import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mgm_gc/models/event.dart';
import 'package:mgm_gc/services/event_service.dart';

class EventDetailsPage extends StatefulWidget {
  const EventDetailsPage({super.key});

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final EventService _eventService = EventService();
  late Future<Event> _eventFuture;
  late String eventId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    eventId = ModalRoute.of(context)!.settings.arguments as String;
    _eventFuture = _eventService.getEventById(eventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: FutureBuilder<Event>(
        future: _eventFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Error loading event details',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _eventFuture = _eventService.getEventById(eventId);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Text('Event not found', style: TextStyle(fontSize: 18)),
            );
          } else {
            final event = snapshot.data!;
            return _buildEventDetails(event);
          }
        },
      ),
    );
  }

  Widget _buildEventDetails(Event event) {
    final DateFormat formatter = DateFormat('EEEE, MMMM d, yyyy');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.eventName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Chip(
                  label: Text(event.eventType),
                  backgroundColor:
                      event.eventType == 'League'
                          ? Colors.blue.shade100
                          : Colors.orange.shade100,
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Dates:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: event.eventDates.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    formatter.format(event.eventDates[index]),
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            const Text(
              'Description:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(event.eventDescription, style: const TextStyle(fontSize: 16)),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Event-specific details
            if (event is LeagueEvent) _buildLeagueEventDetails(event),
            if (event is TournamentEvent) _buildTournamentEventDetails(event),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueEventDetails(LeagueEvent event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'League Details:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Remove scoring type reference as it no longer exists
        // _buildDetailRow('Scoring Type', event.scoringType),

        // Display information about the league instead
        const Text(
          'This is a league event where teams compete against each other in matches.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),

        // You could add code here to fetch and display bracket information
        // For example:
        // FutureBuilder<Map<String, dynamic>>(
        //   future: _eventService.getEventBrackets(event.id),
        //   builder: (context, snapshot) {
        //     if (snapshot.hasData) {
        //       // Display bracket information
        //     }
        //     return const SizedBox();
        //   }
        // ),
      ],
    );
  }

  Widget _buildTournamentEventDetails(TournamentEvent event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tournament Details:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Tournament Format', event.tournamentFormat),
        const SizedBox(height: 8),
        _buildDetailRow('Bracket Type', event.bracketType),
        const SizedBox(height: 8),
        _buildDetailRow('Prize Details', event.prizeDetails),
        const SizedBox(height: 8),
        _buildDetailRow('Custom Rules', event.customRules),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}
