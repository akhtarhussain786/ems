import 'package:geolocator/geolocator.dart';

/// Position acquisition for check in and check out.
///
/// The attendance screen used to await a single high-accuracy fix with a 15
/// second limit. Indoors, or on a cold start, that is close to the worst case:
/// GPS cannot see the sky, so it runs the whole window down before failing,
/// and the screen sits on "Getting location..." the entire time.
///
/// Three sources, cheapest first:
///
///   1. A cached fix, but only if it is recent enough to still describe where
///      the employee is standing. A stale one would record the wrong place and
///      defeat the point of geo-tagging attendance.
///   2. A coarse fix from wifi and cell towers — usually about a second indoors,
///      which is where people actually clock in.
///   3. A precise GPS fix, started at the same time as the coarse one rather
///      than after it, so it costs no extra waiting and silently upgrades the
///      coordinates if it lands while the employee is still taking their selfie.
///
/// [onProvisional] fires as soon as anything usable exists, so the screen can
/// stop showing a spinner. Worst case the recorded position is accurate to
/// ~100m instead of ~10m, which is a fair trade against a 15 second wait.
class LocationService {
  /// Older than this and a cached fix is no longer "where you are now".
  static const Duration _maxCacheAge = Duration(minutes: 2);

  /// Wifi/cell triangulation. Usually sub-second, and works indoors.
  static const Duration _coarseTimeout = Duration(seconds: 8);

  /// GPS. Generous, because it runs in the background behind a position the
  /// employee can already submit.
  static const Duration _preciseTimeout = Duration(seconds: 15);

  /// Quietly asks the OS for a position so a fresh one is already cached by the
  /// time the attendance screen opens.
  ///
  /// Call it when the home screen loads. Deliberately passive: it never asks
  /// for permission and never shows anything, so if permission has not been
  /// granted or location is switched off it simply does nothing rather than
  /// surprising someone with a prompt they did not ask for.
  static Future<void> prewarm() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return;

      final existing = await Geolocator.getLastKnownPosition();
      if (existing != null &&
          DateTime.now().difference(existing.timestamp).abs() < _maxCacheAge) {
        return; // still fresh, no need to spend radio time
      }

      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      // Best effort. If it fails, the attendance screen does the work instead.
    }
  }

  /// The best position available, or null if every source failed.
  ///
  /// Assumes permission is granted and location services are on — the caller
  /// handles those checks and their prompts.
  static Future<Position?> acquire({
    void Function(Position provisional)? onProvisional,
  }) async {
    Position? best;

    // 1. A recent cached fix costs nothing and is instant when it exists.
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null &&
          DateTime.now().difference(cached.timestamp).abs() <= _maxCacheAge) {
        best = cached;
        onProvisional?.call(cached);
      }
    } catch (_) {
      // No cached fix available; fall through to the live attempts.
    }

    // 2 and 3 start together. Errors are caught per-future: leaving one
    // unhandled while awaiting the other surfaces as an unhandled async error.
    Future<Position?> attempt(LocationAccuracy accuracy, Duration limit) {
      return Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: limit),
      ).then<Position?>((p) => p).catchError((_) => null);
    }

    final coarseFuture = attempt(LocationAccuracy.medium, _coarseTimeout);
    final preciseFuture = attempt(LocationAccuracy.high, _preciseTimeout);

    final coarse = await coarseFuture;
    if (coarse != null && best == null) {
      best = coarse;
      onProvisional?.call(coarse);
    }

    // Already in flight, so this adds nothing beyond what is left of its window.
    final precise = await preciseFuture;
    return precise ?? best;
  }
}
