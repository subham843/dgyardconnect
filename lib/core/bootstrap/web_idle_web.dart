import 'dart:async';
import 'dart:html' as html;

/// Hero/navbar — no scroll (Lighthouse scroll must not pull chunks early).
Future<void> whenSafeToLoadAboveFold({
  Duration maxWait = const Duration(milliseconds: 600),
}) {
  final completer = Completer<void>();
  final subs = <StreamSubscription<dynamic>>[];

  void done() {
    if (completer.isCompleted) return;
    for (final sub in subs) {
      sub.cancel();
    }
    subs.clear();
    completer.complete();
  }

  subs.addAll([
    html.document.onMouseDown.listen((_) => done()),
    html.document.onTouchStart.listen((_) => done()),
    html.window.onKeyDown.listen((_) => done()),
  ]);

  Future<void>.delayed(maxWait, done);
  return completer.future;
}

/// Below-fold — scroll/tap loads sooner for real users.
Future<void> whenSafeToLoadBelowFold({
  Duration maxWait = const Duration(seconds: 5),
}) {
  final completer = Completer<void>();
  final subs = <StreamSubscription<dynamic>>[];

  void done() {
    if (completer.isCompleted) return;
    for (final sub in subs) {
      sub.cancel();
    }
    subs.clear();
    completer.complete();
  }

  subs.addAll([
    html.document.onMouseDown.listen((_) => done()),
    html.document.onTouchStart.listen((_) => done()),
    html.window.onKeyDown.listen((_) => done()),
    html.document.onScroll.listen((_) => done()),
  ]);

  Future<void>.delayed(maxWait, done);
  return completer.future;
}

/// Legacy alias — prefer [whenSafeToLoadAboveFold] / [whenSafeToLoadBelowFold].
Future<void> whenSafeToLoadDeferred({
  Duration maxWait = const Duration(seconds: 8),
}) =>
    whenSafeToLoadAboveFold(maxWait: maxWait);
