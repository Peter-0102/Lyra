class Formatters {
  Formatters._();

  /// Formats a Duration into a human-readable string like "3:45" or "1:02:30".
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Formats a Duration as an elapsed time string starting from "0:00".
  static String formatElapsed(Duration duration) {
    return formatDuration(duration);
  }

  /// Formats a Duration as remaining time with a minus prefix like "-3:45".
  static String formatRemaining(Duration current, Duration total) {
    final remaining = total - current;
    if (remaining.isNegative) return '0:00';
    return '-${formatDuration(remaining)}';
  }

  /// Formats bytes into a human-readable size string like "1.2 MB" or "456 KB".
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(2)} GB';
    }
  }

  /// Formats a download progress ratio (0.0 - 1.0) as a percentage string.
  static String formatProgress(double progress) {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }
}
