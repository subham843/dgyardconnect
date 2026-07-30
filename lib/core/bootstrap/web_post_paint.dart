import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Schedules work after the first Flutter frame (post-paint).
void scheduleAfterFirstFrame(VoidCallback action) {
  SchedulerBinding.instance.scheduleFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  });
}

/// Schedules async work after first paint — use for Firebase/Supabase warm-up
/// on routes that need them (never on public home cold start).
Future<void> scheduleAfterFirstFrameAsync(Future<void> Function() action) async {
  final completer = Completer<void>();
  scheduleAfterFirstFrame(() {
    action().then(completer.complete).catchError(completer.completeError);
  });
  return completer.future;
}
