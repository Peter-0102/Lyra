class Song {
  final String id;
  final String title;
  final String artist;
  final String filePath;
  final Duration duration;
  final String? thumbnailUrl;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.duration,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'filePath': filePath,
      'duration': duration.inMilliseconds,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}
