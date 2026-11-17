String _two(int n) => n.toString().padLeft(2, '0');

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatClock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Compact timestamp for chat lists.
String formatListTime(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return formatClock(t);
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  if (now.difference(t).inDays < 7) return _days[t.weekday - 1];
  return '${t.day} ${_months[t.month - 1]}';
}

/// Day separator label inside a conversation.
String formatDayHeader(DateTime t) {
  final now = DateTime.now();
  if (sameDay(t, now)) return 'Today';
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${_days[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]}${t.year == now.year ? '' : ' ${t.year}'}';
}
