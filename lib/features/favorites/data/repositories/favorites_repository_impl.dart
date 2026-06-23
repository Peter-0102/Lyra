import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../audio_player/domain/entities/song.dart';
import '../../domain/repositories/favorites_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'mispoti.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {},
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS favorite_songs (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              filePath TEXT NOT NULL,
              duration INTEGER NOT NULL,
              thumbnailUrl TEXT,
              addedAt INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<void> _ensureTable() async {
    final db = await _database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        filePath TEXT NOT NULL,
        duration INTEGER NOT NULL,
        thumbnailUrl TEXT,
        addedAt INTEGER NOT NULL
      )
    ''');
  }

  @override
  Future<List<Song>> getAllFavorites() async {
    final db = await _database;
    await _ensureTable();
    final rows = await db.query('favorite_songs', orderBy: 'addedAt DESC');
    return rows.map((r) => Song(
      id: r['id'] as String,
      title: r['title'] as String,
      artist: r['artist'] as String,
      filePath: r['filePath'] as String,
      duration: Duration(milliseconds: r['duration'] as int),
      thumbnailUrl: r['thumbnailUrl'] as String?,
    )).toList();
  }

  @override
  Future<void> addFavorite(Song song) async {
    final db = await _database;
    await _ensureTable();
    await db.insert('favorite_songs', {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'filePath': song.filePath,
      'duration': song.duration.inMilliseconds,
      'thumbnailUrl': song.thumbnailUrl,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> removeFavorite(String songId) async {
    final db = await _database;
    await _ensureTable();
    await db.delete('favorite_songs', where: 'id = ?', whereArgs: [songId]);
  }

  @override
  Future<bool> isFavorite(String songId) async {
    final db = await _database;
    await _ensureTable();
    final result = await db.query('favorite_songs',
      where: 'id = ?', whereArgs: [songId], limit: 1);
    return result.isNotEmpty;
  }
}
