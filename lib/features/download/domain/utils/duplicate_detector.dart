import '../../../audio_player/domain/entities/song.dart';

const double _similarityThreshold = 0.6;

String _normalize(String text) {
  return text
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _tokens(String text) {
  return _normalize(text).split(' ');
}

double _tokenOverlap(String a, String b) {
  final tokensA = _tokens(a).toSet();
  final tokensB = _tokens(b).toSet();
  if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;
  final intersection = tokensA.intersection(tokensB).length;
  return intersection / (tokensA.length);
}

bool _artistMatches(String candidateArtist, String libraryArtist) {
  final a = _normalize(candidateArtist);
  final b = _normalize(libraryArtist);
  return a.contains(b) || b.contains(a) || _tokenOverlap(a, b) >= _similarityThreshold;
}

List<Song> findDuplicateSongs(
  List<Song> library,
  String title,
  String artist,
) {
  if (title.trim().isEmpty) return [];

  final normalizedTitle = _normalize(title);
  if (normalizedTitle.isEmpty) return [];

  return library.where((song) {
    final songTitle = _normalize(song.title);
    if (songTitle.isEmpty) return false;

    final overlap = _tokenOverlap(normalizedTitle, songTitle);
    if (overlap >= 1.0) return true;
    if (overlap >= _similarityThreshold && _artistMatches(artist, song.artist)) {
      return true;
    }
    return false;
    }).toList();
}
