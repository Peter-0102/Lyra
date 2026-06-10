import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
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
  // 1. External dependencies — configured Dio with timeouts and interceptors
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept-Encoding': 'gzip, deflate',
        },
      ),
    );

    // Logging interceptor for debug builds (no-op in release)
    dio.interceptors.add(
      LogInterceptor(
        request: false,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (obj) {
          // Only log errors in production; verbose logging is noisy.
        },
      ),
    );

    return dio;
  });

  sl.registerLazySingleton<YoutubeExplode>(() => YoutubeExplode());
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

  // 2. Services — concrete implementations bound to their domain contracts
  sl.registerLazySingleton<DownloadService>(
    () => DownloadServiceImpl(
      dio: sl<Dio>(),
      yt: sl<YoutubeExplode>(),
    ),
  );

  sl.registerLazySingleton<AudioPlayerService>(
    () => AudioPlayerServiceImpl(
      player: sl<AudioPlayer>(),
    ),
  );

  // 3. Repositories — local storage operations
  sl.registerLazySingleton<AudioRepository>(
    () => AudioRepositoryImpl(),
  );
}
