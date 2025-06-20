import 'dart:collection';

class TeeTimeSlot {
  final String id;
  String status;
  String? bookedBy;

  TeeTimeSlot({required this.id, this.status = 'available', this.bookedBy});
}

class TeeTimeService {
  final Map<String, TeeTimeSlot> _slots = HashMap();

  void seedSlots(Iterable<String> ids) {
    for (final id in ids) {
      _slots[id] = TeeTimeSlot(id: id);
    }
  }

  TeeTimeSlot addSlot(String id) {
    final slot = TeeTimeSlot(id: id);
    _slots[id] = slot;
    return slot;
  }

  TeeTimeSlot getSlot(String id) {
    final slot = _slots[id];
    if (slot == null) {
      throw Exception('Slot not found');
    }
    return slot;
  }

  bool bookSlot(String slotId, String userId) {
    final slot = getSlot(slotId);
    if (slot.status == 'booked') {
      throw Exception('Slot already booked');
    }
    slot.status = 'booked';
    slot.bookedBy = userId;
    return true;
  }
}
