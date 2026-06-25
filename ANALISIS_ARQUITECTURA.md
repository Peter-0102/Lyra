# Análisis Arquitectónico Completo — Mispoti

> Fecha: 2026-06-25
> Rol: Arquitecto de Software Senior
> Propósito: Documentación técnica para guiar decisiones de extensión

---

## 1. Diagrama Textual de Arquitectura General

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER APP (Dart)                              │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                        FEATURES (feature-first)                     │    │
│  │                                                                     │    │
│  │  ┌────────────────────┐  ┌──────────────────┐  ┌────────────────┐   │    │
│  │  │   audio_player     │  │    download       │  │   library      │   │    │
│  │  │  ┌──────────────┐  │  │  ┌────────────┐  │  │  ┌───────────┐ │   │    │
│  │  │  │ domain/      │  │  │  │ domain/    │  │  │  │ domain/   │ │   │    │
│  │  │  │  Song        │  │  │  │ Download   │  │  │  │ (reuses   │ │   │    │
│  │  │  │  AudioPlayer │  │  │  │ Service    │  │  │  │  Song)    │ │   │    │
│  │  │  │  Service     │  │  │  │ Duplicate  │  │  │  └───────────┘ │   │    │
│  │  │  │  AudioRepo   │  │  │  │ Detector   │  │  │  ┌───────────┐ │   │    │
│  │  │  └──────────────┘  │  │  └────────────┘  │  │  │ data/     │ │   │    │
│  │  │  ┌──────────────┐  │  │  ┌────────────┐  │  │  │ (reuses)  │ │   │    │
│  │  │  │ data/        │  │  │  │ data/      │  │  │  └───────────┘ │   │    │
│  │  │  │  Impls       │  │  │  │  Impl      │  │  │  ┌───────────┐ │   │    │
│  │  │  └──────────────┘  │  │  └────────────┘  │  │  │presentation│ │   │    │
│  │  │  ┌──────────────┐  │  │  ┌────────────┐  │  │  │ HomeScreen │ │   │    │
│  │  │  │presentation/ │  │  │  │presentation│  │  │  │SearchScreen│ │   │    │
│  │  │  │ PlayerNotifier│  │  │  │ Download   │  │  │  │SongListTile│ │   │    │
│  │  │  │ MiniPlayer   │  │  │  │ Notifier   │  │  │  └───────────┘ │   │    │
│  │  │  │ PlayerScreen │  │  │  │ Downloads  │  │  │                │   │    │
│  │  │  │ QueueScreen  │  │  │  │ Screen     │  │  │                │   │    │
│  │  │  └──────────────┘  │  │  └────────────┘  │  │                │   │    │
│  │  └────────────────────┘  └──────────────────┘  └────────────────┘   │    │
│  │                                                                     │    │
│  │  ┌────────────────────┐  ┌──────────────────┐                       │    │
│  │  │    favorites       │  │   playlists       │                       │    │
│  │  │  ┌──────────────┐  │  │  ┌────────────┐  │                       │    │
│  │  │  │ domain/      │  │  │  │ domain/    │  │                       │    │
│  │  │  │ FavoritesRepo│  │  │  │ Playlist   │  │                       │    │
│  │  │  └──────────────┘  │  │  │ Playlist   │  │                       │    │
│  │  │  ┌──────────────┐  │  │  │ Repository │  │                       │    │
│  │  │  │ data/        │  │  │  └────────────┘  │                       │    │
│  │  │  │ FavoritesImpl│  │  │  ┌────────────┐  │                       │    │
│  │  │  │ (sqflite)    │  │  │  │ data/      │  │                       │    │
│  │  │  └──────────────┘  │  │  │ PlaylistImpl│  │                       │    │
│  │  │  ┌──────────────┐  │  │  │ (sqflite)  │  │                       │    │
│  │  │  │presentation/ │  │  │  └────────────┘  │                       │    │
│  │  │  │ Favorites    │  │  │  ┌────────────┐  │                       │    │
│  │  │  │ Notifier     │  │  │  │presentation│  │                       │    │
│  │  │  │ Favorites    │  │  │  │ Playlist   │  │                       │    │
│  │  │  │ Screen       │  │  │  │ Notifier   │  │                       │    │
│  │  │  └──────────────┘  │  │  │ Playlist   │  │                       │    │
│  │  └────────────────────┘  │  │  Screens    │  │                       │    │
│  │                          │  └────────────┘  │                       │    │
│  │                          └──────────────────┘                       │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                         CORE                                        │    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────┐   │    │
│  │  │ DI (GetIt)  │  │ Errors       │  │ Theme      │  │ Utils    │   │    │
│  │  │ injection_  │  │ failures.dart │  │ AppColors  │  │formatters│   │    │
│  │  │ container   │  │              │  │ AppTheme   │  │          │   │    │
│  │  └─────────────┘  └──────────────┘  └────────────┘  └──────────┘   │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │              STATE MANAGEMENT (Riverpod + StateNotifier)            │    │
│  │                                                                     │    │
│  │  ┌────────────────┐  ┌──────────────────┐  ┌─────────────────────┐  │    │
│  │  │ playerProvider  │  │ downloadProvider  │  │ libraryProvider     │  │    │
│  │  │ (MusicPlayer    │  │ (DownloadQueue    │  │ (LibraryState)      │  │    │
│  │  │  State)         │  │  State)           │  │                     │  │    │
│  │  └────────────────┘  └──────────────────┘  └─────────────────────┘  │    │
│  │  ┌────────────────┐  ┌──────────────────┐                           │    │
│  │  │ favorites      │  │ playlistProvider  │                           │    │
│  │  │ Provider       │  │ (PlaylistsState)  │                           │    │
│  │  │ (FavoritesState)│  └──────────────────┘                           │    │
│  │  └────────────────┘                                                  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │             NAVEGACIÓN (Navigator.of + BottomNavigationBar)         │    │
│  │                                                                     │    │
│  │  HomeScreen (BottomNavigationBar)                                   │    │
│  │    ├── Tab 0: Library (inline)          → PlayerScreen (slide-up)   │    │
│  │    ├── Tab 1: SearchScreen              → (inicia download)         │    │
│  │    ├── Tab 2: FavoritesScreen           → PlayerScreen              │    │
│  │    ├── Tab 3: PlaylistListScreen        → PlaylistDetailScreen      │    │
│  │    └── Tab 4: DownloadsScreen           → (maneja descargas)        │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                          HTTP REST (polling)
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND (Node.js / TypeScript)                     │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                     FASTIFY SERVER (port 3000)                      │    │
│  │  ┌──────────────┐  ┌────────────────┐  ┌───────────────────────┐  │    │
│  │  │ CORS         │  │ Rate Limiter   │  │ Error Handler         │  │    │
│  │  └──────────────┘  └────────────────┘  └───────────────────────┘  │    │
│  │                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────┐  │    │
│  │  │                        ROUTES                                │  │    │
│  │  │  ┌─────────────────────────────────────────────────────┐    │  │    │
│  │  │  │  POST /api/audio/request    → Crea job + encola      │    │  │    │
│  │  │  │  GET  /api/audio/status/:id → Estado + progreso     │    │  │    │
│  │  │  │  GET  /api/audio/file/:vid  → Stream (Range supp.)  │    │  │    │
│  │  │  │  GET  /api/health           → Redis + SQLite + yt-dlp│    │  │    │
│  │  │  └─────────────────────────────────────────────────────┘    │  │    │
│  │  └──────────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                     BULLMQ QUEUE + REDIS                            │    │
│  │                                                                     │    │
│  │  ┌────────────────────────────────────────────────────────────┐    │    │
│  │  │  Queue: audio-extraction                                    │    │    │
│  │  │  ├── attempts: 2, backoff: exponential 5s                  │    │    │
│  │  │  └── Worker (concurrency: 2, lock: 5min)                   │    │    │
│  │  │       ├── 1. Update DB → 'processing'                      │    │    │
│  │  │       ├── 2. Spawn yt-dlp (timeout: 5min)                  │    │    │
│  │  │       ├── 3. Parse stdout → progreso + JSON metadata       │    │    │
│  │  │       ├── 4. On success: DB → 'ready' + metadata           │    │    │
│  │  │       └── 5. On error: DB → 'error' + parseYtDlpError()    │    │    │
│  │  └────────────────────────────────────────────────────────────┘    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                      PERSISTENCIA                                   │    │
│  │                                                                     │    │
│  │  ┌────────────────────────────┐  ┌──────────────────────────────┐  │    │
│  │  │  SQLite (better-sqlite3)   │  │  File System                │  │    │
│  │  │  Tabla: audio_jobs         │  │  ./data/audio/              │  │    │
│  │  │  ├── id (UUID)            │  │  {videoId}_{jobId}.{ext}    │  │    │
│  │  │  ├── video_id              │  │  TTL: 7 días (configurable) │  │    │
│  │  │  ├── status (CHECK)        │  │  Cleanup: cron cada hora    │  │    │
│  │  │  ├── file_path, file_size  │  └──────────────────────────────┘  │    │
│  │  │  ├── title, artist, dur    │                                    │    │
│  │  │  ├── progress, expires_at  │                                    │    │
│  │  │  └── created_at, updated_at│                                    │    │
│  │  └────────────────────────────┘                                    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                     SERVICIOS                                       │    │
│  │  ┌────────────────────────────┐  ┌──────────────────────────────┐  │    │
│  │  │  ytdlp.service.ts          │  │  cleanup.service.ts           │  │    │
│  │  │  ├── runYtDlp()            │  │  ├── cleanupExpiredFiles()    │  │    │
│  │  │  ├── parseYtDlpError()     │  │  └── startCleanupCron()      │  │    │
│  │  │  └── buildAudioExtractArgs │  │     (node-cron: cada hora)   │  │    │
│  │  └────────────────────────────┘  └──────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Flujo Actual de Descarga (End-to-End)

```
[Usuario] → Tapa botón descargar en SearchScreen
    ↓
[SearchScreen] → duplicate_detector.dart (token overlap, threshold 0.6)
    ↓
[DownloadNotifier.startDownload()] → pendingQueue si ya hay una activa
    ↓
[DownloadServiceImpl.downloadYoutubeSong()]
    ├── _extractVideoId() → 11 chars o extrae de URL
    ├── POST /api/audio/request { videoId }
    │     └── Backend: check cache (ready + file exists) → 200
    │                   check in-flight (queued/processing) → 202
    │                   create job in SQLite + bullmq.add() → 202
    ├── _pollStatus(videoId, jobId) → GET /api/audio/status/:id
    │     └── Polling cada 4s, timeout 10min
    │         Hasta "ready" o "error"
    ├── _buildFilePath(title, artist) → Artist_Title_timestamp.m4a
    ├── _assertDiskSpace() → mínimo 5MB libres
    ├── GET /api/audio/file/:videoId (Dio.download + onProgress)
    │     └── Backend: fs.createReadStream() con Range support
    ├── _validateFile() → existe, >0, ≥10KB
    └── Devuelve filePath
    ↓
[DownloadNotifier] → completedDownloads, espera 2s, _processNext()
    ↓
[LibraryNotifier] → ref.listen(downloadProvider) → loadSongs() (auto-refresh)
```

**Flujo Backend:**

```
POST /api/audio/request
    ↓
[router] → Zod validation → repository.createJob() → BullMQ queue.add('extract')
    ↓
[AUDIO WORKER] → DB→'processing' → spawn yt-dlp (5min timeout)
    ├── yt-dlp -f bestaudio[ext=m4a]/... --progress --print-json
    │   -o {audioDir}/{videoId}_{jobId}.%(ext)s
    │   https://www.youtube.com/watch?v={videoId}
    ├── Parse stdout → job.updateProgress(), DB progress
    ├── Parse JSON → title, artist, duration, ext
    ├── stat() → file_size
    └── DB→'ready' con metadata, expires_at = now + TTL
    ↓
[Cleanup Cron] (cada hora)
    └── findExpired() → unlink file → markDeleted()
```

---

## 3. Arquitectura Flutter

### 3.1 Feature Modules

Existen **5 feature modules**, cada uno siguiendo Clean Architecture (domain/data/presentation):

| Feature | Domain | Data | Presentation |
|---------|--------|------|-------------|
| **audio_player** | `Song`, `AudioPlayerService`, `AudioRepository` | `AudioPlayerServiceImpl`, `AudioRepositoryImpl` | `PlayerNotifier`, `PlayerScreen`, `MiniPlayer`, `QueueScreen` |
| **download** | `DownloadService`, `DuplicateDetector` | `DownloadServiceImpl` (HTTP + polling) | `DownloadNotifier`, `DownloadsScreen`, `DownloadTile` |
| **favorites** | `FavoritesRepository` | `FavoritesRepositoryImpl` (sqflite) | `FavoritesNotifier`, `FavoritesScreen` |
| **library** | (reusa `Song` y `AudioRepository`) | (reusa data layer) | `LibraryNotifier`, `HomeScreen`, `SearchScreen`, `SongListTile` |
| **playlists** | `Playlist`, `PlaylistRepository` | `PlaylistRepositoryImpl` (sqflite) | `PlaylistNotifier`, `PlaylistListScreen`, `PlaylistDetailScreen` |

### 3.2 State Management

- **Stack:** `flutter_riverpod` v2.5.1 + `StateNotifier` + `StateNotifierProvider`
- **Patrón:** Cada feature expone: (1) State class inmutable con `copyWith()`, (2) `StateNotifier` que lo gestiona, (3) `StateNotifierProvider` que lo provee
- **Providers existentes:** `playerProvider`, `downloadProvider`, `favoritesProvider`, `libraryProvider`, `playlistProvider`
- **Comunicación cross-feature:** `ref.listen()` (ej: `libraryProvider` escucha a `downloadProvider` para refrescar canciones)

### 3.3 DI

- **Herramienta:** `get_it` v8.0.3
- **Registros:** `Dio`, `YoutubeExplode`, `AudioPlayer`, `DownloadService`, `AudioPlayerService`, `AudioRepository`, `PlaylistRepository`, `FavoritesRepository`
- **URL backend:** Android emulator → `http://10.0.2.2:3000`, otros → `http://localhost:3000`; sobrescribible con `--dart-define=BACKEND_URL`

### 3.4 Navegación

- **Sin router declarativo:** no hay `go_router`, `Navigator 2.0`, ni `routes` map
- **Navegación imperativa:** `Navigator.of(context).push(MaterialPageRoute(...))`
- **BottomNavigationBar** con 5 tabs (Library, Search, Favorites, Playlists, Downloads)
- **MiniPlayer → PlayerScreen:** `PageRouteBuilder` con `SlideTransition` bottom-to-top
- **Modales:** Bottom sheets para volumen, velocidad, opciones de canción, selector de playlist

### 3.5 Player System

| Componente | Archivo | Rol |
|-----------|---------|-----|
| `AudioPlayerService` | `domain/repositories/audio_player_service.dart` | Abstracción sobre `just_audio.AudioPlayer` |
| `AudioPlayerServiceImpl` | `data/repositories/audio_player_service_impl.dart` | Wrapper: streams, play/pause/seek, queue, loop/shuffle |
| `Song` | `domain/entities/song.dart` | Entidad: id, title, artist, filePath, duration, thumbnailUrl |
| `AudioRepository` | `domain/repositories/audio_repository.dart` | Escaneo de filesystem local |
| `AudioRepositoryImpl` | `data/repositories/audio_repository_impl.dart` | Scanning de `getApplicationDocumentsDirectory()` |
| `PlayerNotifier` | `presentation/providers/player_provider.dart` | StateNotifier: suscribe a 5 streams, expone play/pause/seek/queue |
| `MusicPlayerState` | (en `player_provider.dart`) | Estado inmutable con 14 campos + computed getters |
| `MiniPlayer` | `presentation/widgets/mini_player.dart` | Barra persistente con progreso y controles |
| `PlayerScreen` | `presentation/screens/player_screen.dart` | Pantalla full con seekbar, metadata, controles |
| `QueueScreen` | `presentation/screens/queue_screen.dart` | Lista reordenable con swipe-to-delete |

**Flujo de reproducción:**
1. Usuario tapa `SongListTile` → `PlayerNotifier.playSong()` o `playQueue()`
2. Se crea `ConcatenatingAudioSource` con `AudioSource.file()` + `MediaItem` tags
3. `_service.setAudioSource()` → `skipToQueueItem()` → `play()`
4. `sequenceStateStream` actualiza `currentIndex` y `currentSong`

---

## 4. Arquitectura Backend

### 4.1 Fastify Server

| Componente | Archivo | Rol |
|-----------|---------|-----|
| Entry point | `src/server.ts` | Bootstrap: CORS, rate-limit, error handler, rutas, cleanup cron |
| Config | `src/config.ts` | Zod validación de env vars |
| Error handler | `src/plugins/errorHandler.ts` | Manejador global |
| Rate limiter | `src/plugins/rateLimiter.ts` | 10 req/min por IP |

### 4.2 Rutas

| Método | Path | Comportamiento |
|--------|------|---------------|
| `POST` | `/api/audio/request` | Valida videoId, check cache, check in-flight, crea job + encola → 200/202 |
| `GET` | `/api/audio/status/:jobId` | Retorna estado, progreso, metadatos → 200/404 |
| `GET` | `/api/audio/file/:videoId` | Stream con Range support → 200/206/404/410 |
| `GET` | `/api/health` | Chequea Redis + SQLite + yt-dlp → ok/degraded |

### 4.3 Workers (BullMQ)

| Componente | Archivo | Detalle |
|-----------|---------|---------|
| Queue | `src/queue/audioQueue.ts` | Nombre: `audio-extraction`, attempts: 2, backoff: exponential 5s |
| Worker | `src/queue/audioWorker.ts` | Concurrency: 2, lock: 5min |
| Redis | `src/queue/connection.ts` | IORedis singleton, `maxRetriesPerRequest: null` |

**Worker flow:**
1. DB → `processing`
2. Spawn `yt-dlp` con args: `-f bestaudio[ext=m4a]/... --progress --print-json`
3. Parse stdout → progreso → `job.updateProgress()` + DB
4. Parse JSON metadata → title, artist, duration, ext
5. `stat()` → file_size
6. DB → `ready` con metadata

### 4.4 Servicios

| Servicio | Archivo | Funciones |
|----------|---------|-----------|
| yt-dlp | `src/services/ytdlp.service.ts` | `runYtDlp()` (spawn + timeout 5min), `parseYtDlpError()` (errores en español), `buildAudioExtractionArgs()` |
| Cleanup | `src/services/cleanup.service.ts` | `cleanupExpiredFiles()` (find + unlink + markDeleted), `startCleanupCron()` (cada hora) |

---

## 5. Persistencia Actual

### 5.1 SQLite — Flutter (`sqflite`)

**Archivo:** `getApplicationDocumentsDirectory() / mispoti.db`

**Tabla: `favorite_songs`**

| Columna | Tipo | Constraint |
|---------|------|-----------|
| id | TEXT | PRIMARY KEY |
| title | TEXT | NOT NULL |
| artist | TEXT | NOT NULL |
| filePath | TEXT | NOT NULL |
| duration | INTEGER | NOT NULL (millis) |
| thumbnailUrl | TEXT | nullable |
| addedAt | INTEGER | NOT NULL |

**Tabla: `playlists`**

| Columna | Tipo | Constraint |
|---------|------|-----------|
| id | TEXT | PRIMARY KEY |
| name | TEXT | NOT NULL |
| description | TEXT | nullable |
| createdAt | INTEGER | NOT NULL |
| updatedAt | INTEGER | NOT NULL |

**Tabla: `playlist_songs`**

| Columna | Tipo | Constraint |
|---------|------|-----------|
| playlistId | TEXT | PK (compuesta) |
| songId | TEXT | PK (compuesta) |
| title | TEXT | NOT NULL |
| artist | TEXT | NOT NULL |
| filePath | TEXT | NOT NULL |
| duration | INTEGER | NOT NULL |
| thumbnailUrl | TEXT | nullable |
| orderIndex | INTEGER | NOT NULL |
| addedAt | INTEGER | NOT NULL |

**Problemas detectados:**
- `FavoritesRepositoryImpl` tiene `onCreate` vacío, usa `_ensureTable()` con `CREATE TABLE IF NOT EXISTS` como parche
- Dos conexiones separadas a `mispoti.db` (favorites y playlists) sin singleton
- Sin migraciones reales (`onUpgrade` vacío en ambos)

### 5.2 SQLite — Backend (`better-sqlite3`)

**Archivo:** `./data/db.sqlite`

**Tabla: `audio_jobs`**

| Columna | Tipo | Constraint |
|---------|------|-----------|
| id | TEXT | PRIMARY KEY (UUID) |
| video_id | TEXT | NOT NULL |
| status | TEXT | NOT NULL, CHECK('queued','processing','ready','error') |
| file_path | TEXT | nullable |
| file_size | INTEGER | nullable |
| format | TEXT | nullable |
| error_message | TEXT | nullable |
| title | TEXT | nullable |
| artist | TEXT | nullable |
| duration_sec | INTEGER | nullable |
| progress | REAL | nullable |
| created_at | INTEGER | NOT NULL |
| updated_at | INTEGER | NOT NULL |
| expires_at | INTEGER | NOT NULL |

**Índices:** `video_id`, `expires_at`, `status`
**Migraciones:** Archivos secuenciales en `src/db/migrations/`. Actualmente solo `001_init.sql`.
**TTL:** 168 horas (7 días), configurable via `FILE_TTL_HOURS`.

### 5.3 File Storage

| Ubicación | Propósito | Naming |
|-----------|-----------|--------|
| Backend: `./data/audio/` | Cache server-side | `{videoId}_{jobId}.{ext}` |
| Flutter: `getApplicationDocumentsDirectory()` | Almacenamiento local | `{Artist}_{Title}_{timestamp}.m4a` |

---

## 6. Dependencias Externas

### 6.1 Flutter (`pubspec.yaml`)

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `flutter_riverpod` | ^2.5.1 | State management |
| `get_it` | ^8.0.3 | Dependency injection |
| `dio` | ^5.4.0 | HTTP client |
| `just_audio` | ^0.9.41 | Audio playback |
| `just_audio_background` | ^0.0.1-beta.15 | Lock screen + notificaciones |
| `sqflite` | ^2.3.0 | SQLite local |
| `path_provider` | ^2.1.1 | Directorio de documentos |
| `disk_usage` | ^0.1.0 | Espacio en disco |
| `youtube_explode_flutter` | ^3.0.3 | Metadatos YouTube |
| `intl` | ^0.19.0 | Formateo |

### 6.2 Backend (`package.json`)

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `fastify` | ^5.2.1 | HTTP server |
| `@fastify/cors` | ^10.0.2 | CORS |
| `@fastify/rate-limit` | ^10.2.1 | Rate limiting |
| `bullmq` | ^5.40.0 | Job queue |
| `ioredis` | ^5.5.0 | Redis client |
| `better-sqlite3` | ^11.7.0 | SQLite driver |
| `node-cron` | ^3.0.3 | Cron scheduler |
| `uuid` | ^11.1.0 | UUID generation |
| `zod` | ^3.24.3 | Schema validation |

### 6.3 Sistema

| Dependencia | Propósito |
|-------------|-----------|
| `yt-dlp` (Python) | Extracción de audio de YouTube |
| `ffmpeg` | Procesamiento de audio |
| `redis:7-alpine` | Backend BullMQ |

---

## 7. Riesgos Técnicos

### Riesgo 1: Persistencia Fragmentada en Flutter
**Problema:** `FavoritesRepositoryImpl` y `PlaylistRepositoryImpl` abren conexiones separadas a `mispoti.db` sin singleton compartido. `FavoritesRepositoryImpl` usa `_ensureTable()` con `CREATE TABLE IF NOT EXISTS` como parche, y su `onCreate` está vacío.
**Impacto:** Potencial race condition, esquemas inconsistentes, migraciones difíciles de coordinar.

### Riesgo 2: Sin Mecanismo de Migraciones en Flutter
**Problema:** No hay sistema centralizado de migraciones. `onUpgrade` vacío en ambos repositorios.
**Impacto:** Alto riesgo al extender el schema. Podría forzar borrado de datos.

### Riesgo 3: Polling como Único Mecanismo de Comunicación Backend → Frontend
**Problema:** `GET /api/audio/status/:id` cada 4 segundos con timeout de 10 minutos. Sin WebSockets, SSE, o Webhooks.
**Impacto:** Ineficiente, latencia de hasta 4s, no escala.

### Riesgo 4: Single-Point Player con just_audio
**Problema:** `AudioPlayerServiceImpl` envuelve una única instancia `AudioPlayer` singleton.
**Impacto:** Un archivo corrupto puede romper toda la sesión de reproducción.

### Riesgo 5: Sin Router / Navegación Declarativa
**Problema:** Uso de `Navigator.of(context).push(MaterialPageRoute(...))` sin go_router ni Navigator 2.0.
**Impacto:** Dificultad para notificaciones push, deep linking, restauración de estado, y testing.

### Riesgo 6: Backend Sin Autenticación
**Problema:** API abierta, protegida solo por rate limiting por IP.
**Impacto:** En despliegue real, cualquier cliente con acceso a la red consume recursos.

### Riesgo 7: yt-dlp como Dependencia Externa Frágil
**Problema:** YouTube cambia su estructura frecuentemente. Timeout fijo de 5 minutos.
**Impacto:** Roturas periódicas no detectables en CI.

### Riesgo 8: Sin Code Generation
**Problema:** Modelos y estados escritos a mano con `copyWith()`, `toJson()`, `fromJson()` manuales.
**Impacto:** Alto costo de mantenimiento, propenso a errores humanos.

### Riesgo 9: ID de Songs Basado en Hash de Nombre de Archivo
**Problema:** `fileName.hashCode.toString()` como ID de canción.
**Impacto:** Colisiones de hash, IDs inestables si el archivo se renombra.

### Riesgo 10: Nuevos Features Requieren Backend de Usuarios
**Problema:** No existe concepto de usuario/autenticación. Perfil musical, historial, recomendaciones y chat requieren identidad persistente.
**Impacto:** La arquitectura actual no contempla multi-usuario. Se necesita auth + posible migración a PostgreSQL.

### Riesgo 11: Duplicate Detector Solo Opera en Frontend
**Problema:** `duplicate_detector.dart` compara solo canciones ya descargadas localmente. Sin deduplicación server-side.
**Impacto:** Mismo contenido descargable múltiples veces entre dispositivos.

---

## 8. Puntos de Extensión

### 8.1 Historial de Reproducción

| Aspecto | Propuesta |
|---------|-----------|
| **Modelo** | Nueva tabla `play_history` en Flutter SQLite |
| **Capa** | Nuevo feature `history/` con domain/data/presentation |
| **Integración** | Listener en `positionStream` del `PlayerNotifier` que registre al alcanzar threshold (>30s o >80%) |
| **Sin riesgo** | Append-only, no modifica flujo existente |
| **Backend** | No requiere cambios |

### 8.2 Favoritos (mejora)

| Aspecto | Propuesta |
|---------|-----------|
| **Estado actual** | Feature `favorites/` ya completo con tabla `favorite_songs` |
| **Mejora** | Sincronización con backend para persistencia cross-device |
| **Pre-requisito** | Migrar IDs de hash a UUIDs estables |

### 8.3 Perfil Musical

| Aspecto | Propuesta |
|---------|-----------|
| **Backend** | Sistema de usuarios (JWT + bcrypt). Migrar SQLite → PostgreSQL |
| **Modelo** | `user_music_profile`: topGenres, totalListeningTime, favoriteArtist |
| **Cálculo** | Alimentado por `play_history` + `favorites` |
| **Integración** | Nuevo feature `profile/`. Ningún feature existente se modifica |

### 8.4 Recomendaciones

| Aspecto | Propuesta |
|---------|-----------|
| **Backend** | Worker periódico: matriz de similitud → cosine similarity sobre metadatos |
| **Modelo** | Tabla `recommendations` o endpoint on-the-fly |
| **Frontend** | Nueva sección en `HomeScreen` |
| **Sin riesgo** | Solo agrega endpoint + provider |

### 8.5 Chat

| Aspecto | Propuesta |
|---------|-----------|
| **Backend** | WebSocket (Socket.IO) + tabla `messages` |
| **Modelo** | `(id, fromUserId, toUserId, songId?, message, createdAt)` |
| **Frontend** | Nuevo feature `chat/`. Deep linking para compartir canciones |
| **Pre-requisito** | Auth (usuarios) |

---

## 9. Propuesta de Integración Sin Romper Funcionalidad

### Principios

1. **Nunca modificar código existente que funcione** — siempre añadir, nunca editar.
2. **Toda nueva tabla en SQLite Flutter debe usar `CREATE TABLE IF NOT EXISTS`** y versionar `onUpgrade`.
3. **Centralizar conexión de BD Flutter** — mover a `core/database/app_database.dart` con singleton `Database` y migraciones centralizadas.
4. **Nuevas rutas en backend** — no modificar `/api/audio/*`. Agregar `/api/profile/*`, `/api/recommendations/*`, `/api/chat/*`.
5. **Feature flagging** — cada nuevo feature debe poder deshabilitarse con flag de compilación o runtime.

### Roadmap

```
Fase 1 (Sin riesgo, solo aditivo)
  ├── Centralizar DB en Flutter (app_database.dart)
  ├── Agregar tabla play_history
  ├── Integrar historial en PlayerNotifier
  └── Feature completo: history/

Fase 2 (Sin riesgo, solo aditivo)
  ├── Nuevo endpoint backend: GET /api/recommendations
  ├── Nuevo provider Flutter: recommendations_provider.dart
  ├── Nueva sección en HomeScreen: "Recomendado para ti"
  └── Feature completo: recommendations/

Fase 3 (Riesgo medio, requiere cambios backend)
  ├── Migrar backend SQLite → PostgreSQL
  ├── Agregar auth (JWT + bcrypt)
  ├── Actualizar docker-compose para PostgreSQL
  └── Feature completo: auth/

Fase 4 (Depende de Fase 3)
  ├── Sincronizar favoritos con backend
  ├── Feature: profile/ (top artistas, total tiempo, géneros)
  └── Feature: chat/ (WebSocket + mensajes + compartir canciones)

Fase 5 (Mejora continua)
  ├── Reemplazar polling por WebSockets o SSE
  ├── Migrar a go_router
  ├── Agregar freezed/json_serializable
  ├── Migrar IDs de hash a UUIDs
  └── Tests unitarios + de integración
```

---

## 10. Lista de Carpetas Relevantes

### Flutter (`lib/`)

```
lib/
├── main.dart
├── core/
│   ├── di/injection_container.dart
│   ├── errors/failures.dart
│   ├── http/dio_http_client_adapter.dart
│   ├── theme/app_colors.dart, app_theme.dart
│   └── utils/formatters.dart
└── features/
    ├── audio_player/
    │   ├── domain/entities/song.dart
    │   ├── domain/repositories/audio_player_service.dart
    │   ├── domain/repositories/audio_repository.dart
    │   ├── data/repositories/audio_player_service_impl.dart
    │   ├── data/repositories/audio_repository_impl.dart
    │   └── presentation/
    │       ├── providers/player_provider.dart
    │       ├── screens/player_screen.dart, queue_screen.dart
    │       └── widgets/mini_player.dart
    ├── download/
    │   ├── domain/repositories/download_service.dart
    │   ├── domain/utils/duplicate_detector.dart
    │   ├── data/repositories/download_service_impl.dart
    │   └── presentation/
    │       ├── providers/download_provider.dart
    │       ├── screens/downloads_screen.dart
    │       └── widgets/download_tile.dart
    ├── favorites/
    │   ├── domain/repositories/favorites_repository.dart
    │   ├── data/repositories/favorites_repository_impl.dart
    │   └── presentation/
    │       ├── providers/favorites_provider.dart
    │       └── screens/favorites_screen.dart
    ├── library/
    │   └── presentation/
    │       ├── providers/library_provider.dart
    │       ├── screens/home_screen.dart, search_screen.dart
    │       └── widgets/song_list_tile.dart
    └── playlists/
        ├── domain/entities/playlist.dart
        ├── domain/repositories/playlist_repository.dart
        ├── data/repositories/playlist_repository_impl.dart
        └── presentation/
            ├── providers/playlist_provider.dart
            ├── screens/playlist_list_screen.dart, playlist_detail_screen.dart
            └── widgets/create_playlist_dialog.dart, add_to_playlist_sheet.dart
```

### Backend (`Backend/`)

```
Backend/
├── package.json, tsconfig.json
├── .env, .env.example
├── docker-compose.yml, Dockerfile
├── data/
│   ├── audio/           ← Archivos .m4a/.webm cacheados
│   └── db.sqlite        ← Base SQLite (audio_jobs)
├── scripts/update-ytdlp.sh
└── src/
    ├── server.ts                     ← Entry point Fastify
    ├── config.ts                     ← Zod env validation
    ├── types/audio.types.ts          ← Interfaces compartidas
    ├── db/
    │   ├── client.ts                 ← better-sqlite3 + migrator
    │   ├── migrations/001_init.sql   ← DDL audio_jobs
    │   └── repository.ts             ← CRUD audio_jobs
    ├── queue/
    │   ├── connection.ts             ← IORedis singleton
    │   ├── audioQueue.ts             ← BullMQ Queue
    │   └── audioWorker.ts            ← BullMQ Worker
    ├── routes/
    │   ├── audio.routes.ts           ← 3 endpoints de audio
    │   └── health.routes.ts          ← GET /api/health
    ├── services/
    │   ├── ytdlp.service.ts          ← yt-dlp wrapper
    │   └── cleanup.service.ts        ← Cron expiración
    └── plugins/
        ├── errorHandler.ts           ← Error handler global
        └── rateLimiter.ts            ← @fastify/rate-limit
```
