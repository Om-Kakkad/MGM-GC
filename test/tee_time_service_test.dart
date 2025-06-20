import 'package:flutter_test/flutter_test.dart';
import 'package:mgm_gc/services/tee_time_service.dart';

void main() {
  group('TeeTimeService', () {
    late TeeTimeService service;

    setUp(() {
      service = TeeTimeService();
      service.addSlot('slot1');
    });

    test('booking a slot sets status to booked', () {
      final result = service.bookSlot('slot1', 'user1');
      expect(result, isTrue);
      expect(service.getSlot('slot1').status, 'booked');
    });

    test('double booking throws exception', () {
      service.bookSlot('slot1', 'user1');
      expect(() => service.bookSlot('slot1', 'user2'), throwsException);
    });
  });
}
