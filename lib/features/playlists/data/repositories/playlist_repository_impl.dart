import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../../audio_player/domain/entities/song.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  Database? _db;

  @override
  Future<void> initialize() async {
    await _database;
  }

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
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_songs (
            playlistId TEXT NOT NULL,
            songId TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            filePath TEXT NOT NULL,
            duration INTEGER NOT NULL,
            thumbnailUrl TEXT,
            orderIndex INTEGER NOT NULL,
            addedAt INTEGER NOT NULL,
            PRIMARY KEY (playlistId, songId)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {},
    );
  }

  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(99999);
    return 'pl_${ts}_$r';
  }

  @override
  Future<List<Playlist>> getAllPlaylists() async {
    final db = await _database;
    final rows = await db.query('playlists', orderBy: 'updatedAt DESC');
    final playlists = <Playlist>[];
    for (final row in rows) {
      final songs = await _getSongsForPlaylist(row['id'] as String, db);
      playlists.add(Playlist(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String?,
        songs: songs,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updatedAt'] as int),
      ));
    }
    return playlists;
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    final db = await _database;
    final rows = await db.query('playlists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final songs = await _getSongsForPlaylist(id, db);
    return Playlist(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      songs: songs,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row['updatedAt'] as int),
    );
  }

  Future<List<Song>> _getSongsForPlaylist(
      String playlistId, Database db) async {
    final rows = await db.query('playlist_songs',
        where: 'playlistId = ?',
        whereArgs: [playlistId],
        orderBy: 'orderIndex ASC');
    return rows
        .map((r) => Song(
              id: r['songId'] as String,
              title: r['title'] as String,
              artist: r['artist'] as String,
              filePath: r['filePath'] as String,
              duration: Duration(milliseconds: r['duration'] as int),
              thumbnailUrl: r['thumbnailUrl'] as String?,
            ))
        .toList();
  }

  @override
  Future<String> createPlaylist(Playlist playlist) async {
    final db = await _database;
    final id = playlist.id.isEmpty ? _generateId() : playlist.id;
    final now = DateTime.now();
    await db.insert('playlists', {
      'id': id,
      'name': playlist.name,
      'description': playlist.description,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    return id;
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    final db = await _database;
    await db.update(
      'playlists',
      {
        'name': playlist.name,
        'description': playlist.description,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final db = await _database;
    await db.delete('playlist_songs',
        where: 'playlistId = ?', whereArgs: [id]);
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final db = await _database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
          'SELECT COUNT(*) FROM playlist_songs WHERE playlistId = ?',
          [playlistId]),
    );
    await db.insert('playlist_songs', {
      'playlistId': playlistId,
      'songId': song.id,
      'title': song.title,
      'artist': song.artist,
      'filePath': song.filePath,
      'duration': song.duration.inMilliseconds,
      'thumbnailUrl': song.thumbnailUrl,
      'orderIndex': (count ?? 0),
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await db.update(
      'playlists',
      {'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  @override
  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    final db = await _database;
    await db.delete('playlist_songs', where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, songId]);
    await _reindexSongs(playlistId, db);
    await db.update(
      'playlists',
      {'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  @override
  Future<void> reorderSongs(
      String playlistId, int oldIndex, int newIndex) async {
    final db = await _database;
    if (oldIndex == newIndex) return;

    final rows = await db.query('playlist_songs',
        where: 'playlistId = ?',
        whereArgs: [playlistId],
        orderBy: 'orderIndex ASC');

    final items = rows.toList();
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex >= items.length) return;

    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    final batch = db.batch();
    for (var i = 0; i < items.length; i++) {
      batch.update(
        'playlist_songs',
        {'orderIndex': i},
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, items[i]['songId']],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _reindexSongs(String playlistId, Database db) async {
    final rows = await db.query('playlist_songs',
        where: 'playlistId = ?',
        whereArgs: [playlistId],
        orderBy: 'orderIndex ASC');
    final batch = db.batch();
    for (var i = 0; i < rows.length; i++) {
      batch.update(
        'playlist_songs',
        {'orderIndex': i},
        where: 'playlistId = ? AND songId = ?',
        whereArgs: [playlistId, rows[i]['songId']],
      );
    }
    await batch.commit(noResult: true);
  }
}
