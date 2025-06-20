import 'package:flutter/foundation.dart';
import '../services/tee_time_service.dart';

class TeeTimeProvider extends ChangeNotifier {
  final TeeTimeService _service = TeeTimeService();

  final Map<DateTime, List<Map<String, dynamic>>> _slots = {};
  List<Map<String, dynamic>> _bookings = [];

  Map<DateTime, List<Map<String, dynamic>>> get slots => _slots;
  List<Map<String, dynamic>> get bookings => _bookings;

  Future<void> fetchSlots(DateTime date) async {
    _slots[date] = await _service.getSlotsForDate(date);
    notifyListeners();
  }

  Future<void> fetchBookings(String uid) async {
    _bookings = await _service.getBookingsForUser(uid);
    notifyListeners();
  }

  Future<void> bookSlot(
    DateTime date,
    Map<String, dynamic> slot,
    String uid,
  ) async {
    await _service.bookSlot(date, slot, uid);
    await fetchSlots(date);
    await fetchBookings(uid);
  }

  Future<void> cancelBooking(String bookingId, String uid) async {
    await _service.cancelBooking(bookingId);
    await fetchBookings(uid);
  }
}
