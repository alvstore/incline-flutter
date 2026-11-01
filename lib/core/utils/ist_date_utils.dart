import 'package:intl/intl.dart';

/// Centralized Date & Time Utility for Incline App
/// Enforces Indian Standard Time (IST = UTC+05:30) across all turnstile attendance,
/// bookings, schedules, and club telemetry.
class ISTDateUtils {
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Converts any [DateTime] instance to Indian Standard Time (IST, UTC+05:30)
  static DateTime toIST(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    return utc.add(istOffset);
  }

  /// Parses an incoming server timestamp (ISO string, Postgres timestamp)
  /// and guarantees conversion to Indian Standard Time (IST).
  static DateTime parseServerTimeToIST(dynamic val) {
    if (val == null) return toIST(DateTime.now().toUtc());
    if (val is DateTime) return toIST(val);

    final str = val.toString().trim();
    if (str.isEmpty) return toIST(DateTime.now().toUtc());

    try {
      DateTime dt = DateTime.parse(str);
      // If the string does not have an explicit timezone offset (e.g., standard Postgres 'YYYY-MM-DD HH:MM:SS')
      // Supabase PostgreSQL stores in UTC, so treat it as UTC before applying IST offset.
      final hasExplicitOffset = str.contains('+') || str.endsWith('Z') || str.endsWith('z');
      if (!hasExplicitOffset) {
        dt = DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
      }
      return toIST(dt);
    } catch (_) {
      return toIST(DateTime.now().toUtc());
    }
  }

  /// Formats an IST [DateTime] to a standard 12-hour time string: '07:15 AM'
  /// If [withSuffix] is true, appends ' IST': '07:15 AM IST'
  static String formatTime(DateTime? dt, {bool withSuffix = true}) {
    if (dt == null) return '--:--';
    final ist = toIST(dt);
    final formatted = DateFormat('hh:mm a').format(ist);
    return withSuffix ? '$formatted IST' : formatted;
  }

  /// Formats an IST [DateTime] to date string: 'yyyy-MM-dd' for grouping
  static String formatDateKey(DateTime? dt) {
    if (dt == null) return '';
    final ist = toIST(dt);
    return DateFormat('yyyy-MM-dd').format(ist);
  }

  /// Formats an IST [DateTime] to human-readable header: 'Today • Monday, 19 Oct'
  static String formatDateHeader(DateTime? dt) {
    if (dt == null) return '';
    final ist = toIST(dt);
    final nowIst = toIST(DateTime.now().toUtc());

    final today = DateTime(nowIst.year, nowIst.month, nowIst.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordDate = DateTime(ist.year, ist.month, ist.day);

    if (recordDate == today) {
      return 'Today • ${DateFormat('EEEE, dd MMM').format(ist)} (IST)';
    } else if (recordDate == yesterday) {
      return 'Yesterday • ${DateFormat('EEEE, dd MMM').format(ist)} (IST)';
    } else {
      return '${DateFormat('EEEE, dd MMM yyyy').format(ist)} (IST)';
    }
  }

  /// Calculates human-readable duration between check-in and check-out
  static String formatDuration(DateTime checkIn, DateTime? checkOut) {
    if (checkOut == null) return 'Active in Club';
    final inIst = toIST(checkIn);
    final outIst = toIST(checkOut);
    final diff = outIst.difference(inIst);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '$mins mins';
  }
}
