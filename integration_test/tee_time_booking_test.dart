import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mgm_gc/services/tee_time_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('member vs guest booking flow', (tester) async {
    final service = TeeTimeService();
    service.seedSlots(['slot1', 'slot2']);

    // Member books first slot
    final memberResult = service.bookSlot('slot1', 'member1');
    expect(memberResult, isTrue);
    expect(service.getSlot('slot1').status, 'booked');

    // Guest attempts to book the same slot
    expect(() => service.bookSlot('slot1', 'guest1'), throwsException);
  });
}
