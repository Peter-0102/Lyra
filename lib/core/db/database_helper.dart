import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/audio_player/domain/entities/song.dart';

class DatabaseHelper {
  Database? _db;

  static const int currentVersion = 3;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'mispoti.db');
    return openDatabase(
      path,
      version: currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createFavoriteSongsTable(db);
    await _createPlaylistsTable(db);
    await _createPlaylistSongsTable(db);
    await _addVideoIdColumns(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFavoriteSongsTable(db);
      await _createPlaylistsTable(db);
      await _createPlaylistSongsTable(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
  }

  Future<void> _migrateToV3(Database db) async {
    await _addVideoIdColumns(db);
    await _recomputeSongIds(db);
  }

  Future<void> _addVideoIdColumns(Database db) async {
    try {
      await db.execute('ALTER TABLE favorite_songs ADD COLUMN videoId TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE playlist_songs ADD COLUMN videoId TEXT');
    } catch (_) {}
  }

  Future<void> _recomputeSongIds(Database db) async {
    final favRows = await db.query('favorite_songs');
    for (final row in favRows) {
      final filePath = row['filePath'] as String;
      if (filePath.isEmpty) continue;
      final fileName = p.basename(filePath);
      final newId = stableIdFromFileName(fileName);
      await db.update(
        'favorite_songs',
        {'id': newId, 'videoId': extractVideoIdFromFileName(fileName)},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    final plRows = await db.query('playlist_songs');
    for (final row in plRows) {
      final filePath = row['filePath'] as String;
      if (filePath.isEmpty) continue;
      final fileName = p.basename(filePath);
      final newId = stableIdFromFileName(fileName);
      final oldPlaylistId = row['playlistId'] as String;
      final oldSongId = row['songId'] as String;
      await db.update(
        'playlist_songs',
        {'songId': newId, 'videoId': extractVideoIdFromFileName(fileName)},
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [oldPlaylistId, oldSongId],
      );
    }
    await db.execute('DELETE FROM favorite_songs WHERE id IS NULL OR id = \'\'');
    await db.execute('''
      DELETE FROM playlist_songs WHERE songId IS NULL OR songId = ''
    ''');
  }

  Future<void> _createFavoriteSongsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        filePath TEXT NOT NULL,
        duration INTEGER NOT NULL,
        thumbnailUrl TEXT,
        videoId TEXT,
        addedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createPlaylistsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createPlaylistSongsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_songs (
        playlistId TEXT NOT NULL,
        songId TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        filePath TEXT NOT NULL,
        duration INTEGER NOT NULL,
        thumbnailUrl TEXT,
        videoId TEXT,
        orderIndex INTEGER NOT NULL,
        addedAt INTEGER NOT NULL,
        PRIMARY KEY (playlistId, songId)
      )
    ''');
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
