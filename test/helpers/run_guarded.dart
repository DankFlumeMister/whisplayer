import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Runs [body] in a guarded zone that shields tests from the delayed
/// platform-channel errors audio_service emits when its bootstrap is
/// touched in a test environment.
///
/// Assertion failures ([TestFailure]) raised *during* [body] are forwarded
/// to the returned future so the test still fails; anything else is plugin
/// noise the controller already guards against and is ignored.
Future<void> runGuarded(Future<void> Function() body) {
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      await body();
      if (!done.isCompleted) {
        done.complete();
      }
    },
    (error, stackTrace) {
      if (done.isCompleted) {
        return;
      }
      if (error is TestFailure) {
        done.completeError(error, stackTrace);
      }
    },
  );
  return done.future;
}
