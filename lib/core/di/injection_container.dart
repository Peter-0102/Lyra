import 'dart:io' show Platform;

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/download/domain/repositories/download_service.dart';
import '../../features/download/data/repositories/download_service_impl.dart';
import '../../features/audio_player/domain/repositories/audio_player_service.dart';
import '../../features/audio_player/data/repositories/audio_player_service_impl.dart';
import '../../features/audio_player/domain/repositories/audio_repository.dart';
import '../../features/audio_player/data/repositories/audio_repository_impl.dart';

final GetIt sl = GetIt.instance;

final String _defaultBackendUrl =
    Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

String resolveBackendUrl() {
  if (const bool.hasEnvironment('BACKEND_URL')) {
    return const String.fromEnvironment('BACKEND_URL');
  }
  return _defaultBackendUrl;
}

Future<void> initDI() async {
  final backendUrl = resolveBackendUrl();
  print('[DI] Backend URL: $backendUrl');

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));
  sl.registerLazySingleton<Dio>(() => dio);

  final ytHttpClient = YoutubeHttpClient(http.Client());
  sl.registerLazySingleton<YoutubeExplode>(() => YoutubeExplode(httpClient: ytHttpClient));
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

  sl.registerLazySingleton<DownloadService>(
    () => DownloadServiceImpl(
      dio: sl<Dio>(),
      baseUrl: backendUrl,
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
