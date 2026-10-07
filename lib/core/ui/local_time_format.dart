/// Sensor timestamps are stored in UTC and displayed in the phone's timezone.
String formatLocalTime12(DateTime instant) {
  final local = instant.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '$hour:${twoDigits(local.minute)}:${twoDigits(local.second)} '
      '${local.hour < 12 ? 'AM' : 'PM'}';
}

String formatLocalDateTime12(DateTime instant) {
  final local = instant.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${formatLocalTime12(local)}';
}
