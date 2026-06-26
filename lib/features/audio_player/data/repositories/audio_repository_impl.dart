import 'dart:io';
import 'package:path/path.dart' as p;
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
          final fileName = p.basename(file.path);
          final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
          final parts = nameWithoutExt.split('_');

          int offset = 0;
          if (parts.isNotEmpty &&
              parts.first.length == 11 &&
              RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(parts.first)) {
            offset = 1;
          }

          final remainingParts = parts.sublist(offset);

          String title;
          String artist;

          if (remainingParts.length >= 3) {
            final lastPart = remainingParts.last;
            final isTimestamp = int.tryParse(lastPart) != null;

            if (isTimestamp) {
              artist = _formatFileName(
                  remainingParts.sublist(0, remainingParts.length - 2).join('_'));
              title = _formatFileName(remainingParts[remainingParts.length - 2]);
            } else {
              artist = _formatFileName(remainingParts.first);
              title = _formatFileName(remainingParts.sublist(1).join('_'));
            }
          } else if (remainingParts.length == 2) {
            artist = _formatFileName(remainingParts[0]);
            title = _formatFileName(remainingParts[1]);
          } else {
            artist = 'Unknown Artist';
            title = _formatFileName(nameWithoutExt);
          }

          songs.add(Song(
            id: stableIdFromFileName(fileName),
            title: title,
            artist: artist,
            filePath: file.path,
            duration: Duration.zero,
            videoId: extractVideoIdFromFileName(fileName),
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
