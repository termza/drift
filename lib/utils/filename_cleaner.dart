/// Heuristic cleanup of raw filenames into structured title / artist / album
/// triples. Used as a fallback when the file has no embedded metadata.
///
/// Patterns recognised (in order):
///   1. `Author - Album - Title.ext`  → {artist: Author, album: Album, title: Title}
///   2. `Author - Title.ext`          → {artist: Author, title: Title}
///   3. `NN - Title` / `NN. Title`    → {title: Title} (strips leading track number)
///   4. `[bracketed prefix] Title`    → {title: Title}
///   5. underscores → spaces; collapse whitespace
///
/// The pre-existing metadata (if any) wins — this only fills in blanks.
class CleanedNames {
  final String title;
  final String? artist;
  final String? album;
  const CleanedNames({required this.title, this.artist, this.album});
}

CleanedNames cleanFilename(String basenameWithoutExt) {
  var s = basenameWithoutExt;

  // 1. Normalise whitespace + underscores.
  s = s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  // 2. Strip leading "01 - ", "01. ", "01) " — common track-number prefixes.
  s = s.replaceFirst(
    RegExp(r'^\d{1,3}\s*[-.\)]\s*'),
    '',
  );

  // 3. Strip a leading bracketed prefix like "[2019]" or "(disc 2)".
  s = s.replaceFirst(
    RegExp(r'^[\[\(][^\]\)]+[\]\)]\s*'),
    '',
  );

  s = s.trim();
  if (s.isEmpty) {
    return CleanedNames(title: basenameWithoutExt);
  }

  // 4. Split on " - " separators.
  final parts = s
      .split(RegExp(r'\s+-\s+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.length >= 3) {
    // Author - Album - Title (audiobook chapter convention)
    return CleanedNames(
      artist: parts[0],
      album: parts[1],
      title: parts.sublist(2).join(' - '),
    );
  }
  if (parts.length == 2) {
    // Author - Title
    return CleanedNames(artist: parts[0], title: parts[1]);
  }

  return CleanedNames(title: s);
}
