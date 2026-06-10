import 'package:get_it/get_it.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/download/domain/repositories/download_service.dart';
import '../../features/download/data/repositories/download_service_impl.dart';
import '../../features/audio_player/domain/repositories/audio_player_service.dart';
import '../../features/audio_player/data/repositories/audio_player_service_impl.dart';
import '../../features/audio_player/domain/repositories/audio_repository.dart';
import '../../features/audio_player/data/repositories/audio_repository_impl.dart';

final GetIt sl = GetIt.instance;

Future<void> initDI() async {
  sl.registerLazySingleton<YoutubeExplode>(() => YoutubeExplode());
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

  sl.registerLazySingleton<DownloadService>(
    () => DownloadServiceImpl(
      yt: sl<YoutubeExplode>(),
    ),
  );

  sl.registerLazySingleton<AudioPlayerService>(
    () => AudioPlayerServiceImpl(
      player: sl<AudioPlayer>(),
    ),
  );

  sl.registerLazySingleton<AudioRepository>(
    () => AudioRepositoryImpl(),
  );
}
