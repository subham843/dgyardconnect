import 'dart:async';

Future<void> whenSafeToLoadAboveFold({
  Duration maxWait = const Duration(milliseconds: 600),
}) =>
    Future<void>.delayed(maxWait);

Future<void> whenSafeToLoadBelowFold({
  Duration maxWait = const Duration(seconds: 5),
}) =>
    Future<void>.delayed(maxWait);

Future<void> whenSafeToLoadDeferred({
  Duration maxWait = const Duration(seconds: 8),
}) =>
    whenSafeToLoadAboveFold(maxWait: maxWait);
