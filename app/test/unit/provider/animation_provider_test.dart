import 'package:dropit_app/provider/animation_provider.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../mocks.mocks.dart';

void main() {
  tearDown(() => timeDilation = 1.0);

  test('mobile animations run at real time and pause while sleeping', () async {
    final persistence = MockPersistenceService();
    when(persistence.getEnableAnimations()).thenReturn(true);
    final ref = RefenaContainer(
      overrides: [persistenceProvider.overrideWithValue(persistence)],
    );
    addTearDown(ref.disposeContainer);

    expect(ref.read(animationProvider), isTrue);
    expect(timeDilation, 1.0);

    ref.notifier(sleepProvider).setState((_) => true);
    await Future<void>.delayed(Duration.zero);

    expect(ref.read(animationProvider), isFalse);
    expect(timeDilation, lessThan(0.001));
  });
}
