/// Utility functions for formatting values across the app.
class FormatUtils {
  const FormatUtils._();

  /// Formats an integer count into a clean, compact string.
  /// Examples:
  /// - 0 -> "0"
  /// - 99 -> "99"
  /// - 150 -> "150"
  /// - 1000 -> "1k"
  /// - 1200 -> "1.2k"
  /// - 10000 -> "10k"
  /// - 100000 -> "100k"
  /// - 1000000 -> "1m"
  static String formatCompactCount(int count) {
    if (count < 0) return '0';
    if (count < 1000) return count.toString();

    if (count < 1000000) {
      final value = count / 1000.0;
      if (value >= 999.95) return '1m';
      if (value >= 100) {
        return '${value.round()}k';
      }
      final formatted = value.toStringAsFixed(1);
      final clean = formatted.endsWith('.0')
          ? formatted.substring(0, formatted.length - 2)
          : formatted;
      return '${clean}k';
    }

    if (count < 1000000000) {
      final value = count / 1000000.0;
      if (value >= 999.95) return '1b';
      if (value >= 100) {
        return '${value.round()}m';
      }
      final formatted = value.toStringAsFixed(1);
      final clean = formatted.endsWith('.0')
          ? formatted.substring(0, formatted.length - 2)
          : formatted;
      return '${clean}m';
    }

    final value = count / 1000000000.0;
    final formatted = value.toStringAsFixed(1);
    final clean = formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
    return '${clean}b';
  }
}

