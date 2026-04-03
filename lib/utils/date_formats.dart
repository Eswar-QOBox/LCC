/// App-wide date/time format strings for consistent display.
class AppDateFormats {
  AppDateFormats._();

  /// Date only, e.g. 15 Mar 2025
  static const String dateOnly = 'dd MMM yyyy';

  /// Date and time, e.g. 15 Mar 2025, 02:30 PM
  static const String dateTime = 'dd MMM yyyy, hh:mm a';

  /// Time only, e.g. 02:30 PM
  static const String timeOnly = 'hh:mm a';

  /// Month and year for salary slips, e.g. Mar 2025
  static const String monthYear = 'MMM yyyy';

  /// Full month and year, e.g. March 2025
  static const String monthYearLong = 'MMMM yyyy';
}
