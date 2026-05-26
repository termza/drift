import '../models/track.dart';

/// Outcome of a multi-file import. Failures carry user-readable reasons so the
/// UI can surface them instead of silently dropping bad files.
class ImportResult {
  final List<Track> added;
  final int skipped;
  final List<ImportFailure> failed;

  const ImportResult({
    this.added = const [],
    this.skipped = 0,
    this.failed = const [],
  });

  bool get isEmpty =>
      added.isEmpty && skipped == 0 && failed.isEmpty;
  int get totalAttempted => added.length + skipped + failed.length;
}

class ImportFailure {
  final String fileName;
  final String reason;
  const ImportFailure({required this.fileName, required this.reason});
}
