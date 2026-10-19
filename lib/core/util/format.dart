String formatDuration(Duration d) {
  final total = d.inSeconds;
  if (total <= 0) return '--:--';
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

String formatBytes(num bytes) {
  if (bytes < 1024) return '${bytes.toInt()} B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// 32-bit FNV-1a, used for deterministic artwork and stable ids.
int fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Lower-case, accent- and punctuation-free form used to match duplicates
/// across sources ("On God (Remastered)" ~ "on god remastered").
String normalizeForMatch(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// "1 song", "4 songs".
String songCount(int n) => '$n ${n == 1 ? 'song' : 'songs'}';
