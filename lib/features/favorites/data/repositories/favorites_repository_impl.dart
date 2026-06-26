import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_helper.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../domain/repositories/favorites_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final DatabaseHelper _dbHelper;

  FavoritesRepositoryImpl(this._dbHelper);

  @override
  Future<List<Song>> getAllFavorites() async {
    final db = await _dbHelper.database;
    final rows = await db.query('favorite_songs', orderBy: 'addedAt DESC');
    return rows.map((r) => Song(
      id: r['id'] as String,
      title: r['title'] as String,
      artist: r['artist'] as String,
      filePath: r['filePath'] as String,
      duration: Duration(milliseconds: r['duration'] as int),
      thumbnailUrl: r['thumbnailUrl'] as String?,
      videoId: r['videoId'] as String?,
    )).toList();
  }

  @override
  Future<void> addFavorite(Song song) async {
    final db = await _dbHelper.database;
    await db.insert('favorite_songs', {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'filePath': song.filePath,
      'duration': song.duration.inMilliseconds,
      'thumbnailUrl': song.thumbnailUrl,
      'videoId': song.videoId,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> removeFavorite(String songId) async {
    final db = await _dbHelper.database;
    await db.delete('favorite_songs', where: 'id = ?', whereArgs: [songId]);
  }

  @override
  Future<bool> isFavorite(String songId) async {
    final db = await _dbHelper.database;
    final result = await db.query('favorite_songs',
      where: 'id = ?', whereArgs: [songId], limit: 1);
    return result.isNotEmpty;
  }
}
