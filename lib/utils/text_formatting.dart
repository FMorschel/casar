/// Capitalize the first letter of [text] and every word after a dot
/// followed by a space.
///
/// Example: "hello. world" -> "Hello. World"
String capitalizeAfterDots(String text) {
  if (text.isEmpty) return text;

  final result = StringBuffer();
  bool capitalizeNext = true;

  for (int i = 0; i < text.length; i++) {
    final char = text[i];

    if (capitalizeNext && char != ' ') {
      result.write(char.toUpperCase());
      capitalizeNext = false;
    } else if (char == '.' && i + 1 < text.length && text[i + 1] == ' ') {
      result.write(char);
      capitalizeNext = true;
    } else {
      result.write(char);
    }
  }

  return result.toString();
}

/// Formats [takenAt] as `dd/MM HH:mm:ss` for display, in the local time zone.
String formatPhotoTakenAt(DateTime takenAt) {
  final local = takenAt.toLocal();
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
      '${twoDigits(local.second)}';
}
