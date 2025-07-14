import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mgm_gc/models/booking_model.dart';
import 'package:mgm_gc/services/tee_time_service.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  _MyBookingsPageState createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_BookingsList(isPast: false), _BookingsList(isPast: true)],
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final bool isPast;

  const _BookingsList({required this.isPast});

  @override
  Widget build(BuildContext context) {
    final teeTimeService = Provider.of<TeeTimeService>(context);

    return StreamBuilder<List<BookingModel>>(
      stream: teeTimeService.getUserBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final bookings = snapshot.data ?? [];

        // Filter bookings based on upcoming or past
        final filteredBookings =
            bookings
                .where(
                  (booking) =>
                      isPast ? !booking.isUpcoming : booking.isUpcoming,
                )
                .toList();

        if (filteredBookings.isEmpty) {
          return Center(
            child: Text(isPast ? 'No past bookings' : 'No upcoming bookings'),
          );
        }

        // Sort by date (upcoming: soonest first, past: most recent first)
        filteredBookings.sort(
          (a, b) =>
              isPast
                  ? b.startTime.compareTo(a.startTime)
                  : a.startTime.compareTo(b.startTime),
        );

        return ListView.builder(
          itemCount: filteredBookings.length,
          itemBuilder: (context, index) {
            final booking = filteredBookings[index];
            return GestureDetector(
              onTap: () {
                // Navigate to scorecard page with booking data
                Navigator.of(
                  context,
                ).pushNamed('/scorecard', arguments: {'booking': booking});
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(booking.startTime),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (booking.isSharedBooking)
                            Tooltip(
                              message: 'Added by another player',
                              child: Icon(
                                Icons.people,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time: ${DateFormat('HH:mm').format(booking.startTime)} - ${DateFormat('HH:mm').format(booking.endTime)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      // Show booker information
                      if (booking.bookerName != null &&
                          booking.bookerName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.indigo,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Booked by: ${booking.bookerName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Players section
                      if (booking.players.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Players:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        ...booking.players.map((player) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  player.isRegistered
                                      ? Icons.account_circle
                                      : Icons.person_outline,
                                  size: 16,
                                  color:
                                      player.isRegistered
                                          ? Colors.blue
                                          : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    player.name,
                                    style: TextStyle(
                                      color:
                                          player.isRegistered
                                              ? Colors.blue
                                              : null,
                                      fontStyle:
                                          player.isRegistered
                                              ? FontStyle.normal
                                              : FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      // Action buttons and status row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                '/scorecard',
                                arguments: {'booking': booking},
                              );
                            },
                            icon: const Icon(Icons.sports_golf, size: 16),
                            label: const Text('Scorecard'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 2.0,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (!isPast)
                            Chip(
                              label: const Text('Upcoming'),
                              backgroundColor: Colors.green.shade100,
                              labelStyle: TextStyle(
                                color: Colors.green.shade800,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
