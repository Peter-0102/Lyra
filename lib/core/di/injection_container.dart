import 'dart:io' show Platform;

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../http/auth_interceptor.dart';
import '../../features/download/domain/repositories/download_service.dart';
import '../../features/download/data/repositories/download_service_impl.dart';
import '../../features/audio_player/domain/repositories/audio_player_service.dart';
import '../../features/audio_player/data/repositories/audio_player_service_impl.dart';
import '../../features/audio_player/domain/repositories/audio_repository.dart';
import '../../features/audio_player/data/repositories/audio_repository_impl.dart';
import '../../features/playlists/domain/repositories/playlist_repository.dart';
import '../../features/playlists/data/repositories/playlist_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/history/domain/repositories/history_repository.dart';
import '../../features/history/data/repositories/history_repository_impl.dart';

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
    baseUrl: backendUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));
  sl.registerLazySingleton<Dio>(() => dio);

  final ytHttpClient = YoutubeHttpClient(http.Client());
  sl.registerLazySingleton<YoutubeExplode>(() => YoutubeExplode(httpClient: ytHttpClient));
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());

  final dbHelper = sl<DatabaseHelper>();

  sl.registerLazySingleton<DownloadService>(
    () => DownloadServiceImpl(
      dio: sl<Dio>(),
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

  final playlistRepo = PlaylistRepositoryImpl(dbHelper);
  await playlistRepo.initialize();
  sl.registerSingleton<PlaylistRepository>(playlistRepo);

  sl.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(dbHelper),
  );

  final secureStorage = const FlutterSecureStorage();
  sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSource(secureStorage),
  );

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(sl<Dio>()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      sl<AuthRemoteDataSource>(),
      sl<AuthLocalDataSource>(),
    ),
  );

  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<Dio>()),
  );

  sl.registerLazySingleton<HistoryRepository>(
    () => HistoryRepositoryImpl(sl<Dio>()),
  );

  final authInterceptor = AuthInterceptor(
    sl<AuthLocalDataSource>(),
    sl<AuthRemoteDataSource>(),
  );
  final dioInstance = sl<Dio>();
  authInterceptor.setDio(dioInstance);
  dioInstance.interceptors.add(authInterceptor);
}
