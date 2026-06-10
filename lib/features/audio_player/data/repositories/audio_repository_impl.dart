import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../../../core/errors/failures.dart';

class AudioRepositoryImpl implements AudioRepository {
  AudioRepositoryImpl();

  @override
  Future<List<Song>> getLocalSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = await dir.list().where((entity) {
        if (entity is! File) return false;
        final path = entity.path.toLowerCase();
        return path.endsWith('.webm') ||
            path.endsWith('.mp3') ||
            path.endsWith('.m4a') ||
            path.endsWith('.ogg') ||
            path.endsWith('.wav') ||
            path.endsWith('.flac');
      }).toList();

      final List<Song> songs = [];
      for (final file in files) {
        if (file is File) {
          final fileName = file.uri.pathSegments.last;
          final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
          final parts = nameWithoutExt.split('_');

          String title;
          String artist;

          if (parts.length >= 3) {
            final lastPart = parts.last;
            final isTimestamp = int.tryParse(lastPart) != null;

            if (isTimestamp && parts.length >= 3) {
              artist = _formatFileName(parts.sublist(0, parts.length - 2).join('_'));
              title = _formatFileName(parts[parts.length - 2]);
            } else {
              artist = _formatFileName(parts.first);
              title = _formatFileName(parts.sublist(1).join('_'));
            }
          } else if (parts.length == 2) {
            artist = _formatFileName(parts[0]);
            title = _formatFileName(parts[1]);
          } else {
            artist = 'Unknown Artist';
            title = _formatFileName(nameWithoutExt);
          }

          songs.add(Song(
            id: fileName.hashCode.toString(),
            title: title,
            artist: artist,
            filePath: file.path,
            duration: Duration.zero,
          ));
        }
      }

      return songs;
    } catch (e) {
      throw StorageFailure('Failed to read local songs: $e');
    }
  }

  @override
  Future<List<Song>> searchLocalSongs(String query) async {
    final allSongs = await getLocalSongs();
    final lowerQuery = query.toLowerCase();
    return allSongs.where((song) {
      return song.title.toLowerCase().contains(lowerQuery) ||
          song.artist.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Future<void> deleteSong(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw StorageFailure('Failed to delete song: $e');
    }
  }

  @override
  Future<bool> songExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  String _formatFileName(String rawName) {
    return rawName
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
