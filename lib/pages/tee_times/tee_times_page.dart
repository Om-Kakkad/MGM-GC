import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tee_time_provider.dart';
import 'booking_confirmation.dart';

class TeeTimesPage extends StatefulWidget {
  const TeeTimesPage({super.key});

  @override
  State<TeeTimesPage> createState() => _TeeTimesPageState();
}

class _TeeTimesPageState extends State<TeeTimesPage>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TeeTimeProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tee Times'),
          bottom: TabBar(
            controller: _controller,
            tabs: const [
              Tab(text: 'Available Slots'),
              Tab(text: 'My Bookings'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _controller,
          children: const [
            _AvailableSlotsTab(),
            _MyBookingsTab(),
          ],
        ),
      ),
    );
  }
}

class _AvailableSlotsTab extends StatelessWidget {
  const _AvailableSlotsTab();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TeeTimeProvider>(context);
    final today = DateTime.now();
    provider.fetchSlots(today);
    final slots = provider.slots[today] ?? [];

    return ListView.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return ListTile(
          title: Text(slot['time']?.toString() ?? ''),
          trailing: ElevatedButton(
            onPressed: () {
              provider.bookSlot(today, slot, 'guest');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BookingConfirmationPage(),
                  settings: RouteSettings(arguments: slot),
                ),
              );
            },
            child: const Text('Book'),
          ),
        );
      },
    );
  }
}

class _MyBookingsTab extends StatelessWidget {
  const _MyBookingsTab();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TeeTimeProvider>(context);
    provider.fetchBookings('guest');
    final bookings = provider.bookings;

    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return ListTile(
          title: Text(booking['slot']?['time']?.toString() ?? ''),
          subtitle: Text(booking['date']?.toString() ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              provider.cancelBooking(booking['id'], 'guest');
            },
          ),
        );
      },
    );
  }
}
