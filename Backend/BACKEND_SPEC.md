# Especificación: Backend de extracción y descarga de audio de YouTube

## Objetivo

Construir un backend que reciba un `videoId` de YouTube, extraiga el audio
usando `yt-dlp`, lo cachee en disco/almacenamiento, y lo sirva a la app
Flutter vía un endpoint HTTP normal (descarga directa, sin firmas, sin 403,
soporta `Range` para reanudar descargas).

La app Flutter deja de hablar con YouTube directamente. Solo habla con este
backend.

---

## 1. Stack tecnológico elegido

| Componente | Elección | Justificación |
|---|---|---|
| Runtime | **Node.js 20 LTS + TypeScript** | Tipado fuerte, ecosistema maduro para APIs HTTP, fácil de mantener |
| Framework HTTP | **Fastify** | Más rápido que Express, soporte nativo de streams (clave para servir archivos grandes), schemas con TypeBox/JSON Schema |
| Extractor | **yt-dlp** (binario, vía `child_process`) | Es el extractor más mantenido y robusto que existe; se actualiza semanalmente; maneja firmas, throttling, parámetro `n`, etc. |
| Conversión audio | **ffmpeg** (vía yt-dlp `--extract-audio`) | Estándar de facto; yt-dlp lo invoca internamente |
| Cola de trabajos | **BullMQ + Redis** | Evita procesar el mismo video N veces en paralelo; permite reintentos, TTL, rate limiting |
| Almacenamiento de archivos | **Filesystem local con volumen persistente** (o S3/R2 si se quiere escalar horizontalmente) | Simplicidad inicial; migración a S3 es directa después |
| Base de datos metadata | **SQLite (better-sqlite3)** | Cero configuración, suficiente para registrar videoId → archivo, estado, expiración |
| Contenedor | **Docker** (imagen basada en `node:20-bookworm-slim` + `yt-dlp` + `ffmpeg`) | Reproducibilidad, fácil deploy en cualquier VPS |
| Reverse proxy / TLS | **Caddy** (o Nginx) | HTTPS automático con Let's Encrypt, config mínima |
| Hosting sugerido | **VPS de 2 vCPU / 4GB RAM** (Hetzner, DigitalOcean, etc.) | yt-dlp + ffmpeg necesitan CPU para extraer/transcodificar; 2GB es insuficiente bajo carga |

### Por qué NO usar servicios serverless (Lambda, Cloud Run con cold start agresivo)
yt-dlp + ffmpeg tienen tiempos de ejecución variables (5-60s) y requieren
binarios nativos. Un servidor persistente con cola de trabajos es más
predecible y barato que pagar por invocaciones largas en serverless.

---

## 2. Arquitectura del flujo

```
┌─────────────┐     1. POST /api/audio/request {videoId}      ┌──────────────┐
│  Flutter App │ ─────────────────────────────────────────────▶│   Fastify    │
│              │                                                 │   API        │
│              │◀──────────── 202 {jobId, status: "queued"} ────│              │
└──────────────┘                                                 └──────┬───────┘
       │                                                                 │ enqueue
       │ 2. GET /api/audio/status/:jobId  (polling cada 2s)             ▼
       │                                                          ┌──────────────┐
       │◀──── {status: "processing"|"ready"|"error", progress} ──│  BullMQ +    │
       │                                                          │  Redis       │
       │                                                          └──────┬───────┘
       │                                                                 │ worker consume
       │ 3. GET /api/audio/file/:videoId  (Range support)               ▼
       │◀════════════════ stream del archivo .m4a/.webm ════════│  yt-dlp +    │
       │                                                          │  ffmpeg      │
       └─────────────────────────────────────────────────────────│  worker      │
                                                                    └──────┬───────┘
                                                                           │ guarda
                                                                           ▼
                                                                    ┌──────────────┐
                                                                    │ /data/audio/ │
                                                                    │ {videoId}.m4a│
                                                                    │ + SQLite     │
                                                                    └──────────────┘
```

### Decisión clave: patrón asíncrono (job queue) en vez de síncrono

Un request síncrono que espera a que yt-dlp termine (5-60s) bloquearía
conexiones y dispararía timeouts del lado de Flutter. En su lugar:

1. Flutter pide el audio → backend responde inmediato con `jobId`
2. Flutter hace polling de estado (o usa WebSocket/SSE si se prefiere)
3. Cuando `status: "ready"`, Flutter descarga el archivo con un GET normal
   que soporta `Range` (para mostrar progreso real de descarga)

---

## 3. Estructura de directorios del proyecto

```
youtube-audio-backend/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── package.json
├── tsconfig.json
├── src/
│   ├── server.ts                 # entry point, registra plugins de Fastify
│   ├── config.ts                 # carga de variables de entorno
│   ├── db/
│   │   ├── client.ts              # conexión SQLite (better-sqlite3)
│   │   ├── migrations/
│   │   │   └── 001_init.sql       # tabla `audio_jobs`
│   │   └── repository.ts          # CRUD sobre audio_jobs
│   ├── queue/
│   │   ├── connection.ts          # conexión Redis para BullMQ
│   │   ├── audioQueue.ts          # definición de la cola "audio-extraction"
│   │   └── audioWorker.ts         # worker que ejecuta yt-dlp
│   ├── services/
│   │   ├── ytdlp.service.ts       # wrapper de child_process para yt-dlp
│   │   ├── audio.service.ts       # lógica de negocio (cache, validación)
│   │   └── cleanup.service.ts     # borra archivos viejos (cron)
│   ├── routes/
│   │   ├── audio.routes.ts        # POST /request, GET /status, GET /file
│   │   └── health.routes.ts       # GET /health
│   ├── plugins/
│   │   ├── errorHandler.ts        # manejo centralizado de errores
│   │   └── rateLimiter.ts         # @fastify/rate-limit
│   └── types/
│       └── audio.types.ts         # interfaces compartidas
├── data/
│   └── audio/                     # archivos .m4a/.webm cacheados (volumen)
├── scripts/
│   └── update-ytdlp.sh            # cron para `pip install -U yt-dlp`
└── tests/
    ├── audio.routes.test.ts
    └── ytdlp.service.test.ts
```

---

## 4. Esquema de base de datos (SQLite)

```sql
-- 001_init.sql
CREATE TABLE audio_jobs (
  id            TEXT PRIMARY KEY,        -- jobId (uuid)
  video_id      TEXT NOT NULL,
  status        TEXT NOT NULL CHECK(status IN ('queued','processing','ready','error')),
  file_path     TEXT,                    -- ruta relativa en /data/audio
  file_size     INTEGER,
  format        TEXT,                    -- 'm4a' | 'webm' | 'mp3'
  error_message TEXT,
  title         TEXT,
  artist        TEXT,
  duration_sec  INTEGER,
  created_at    INTEGER NOT NULL,        -- epoch millis
  updated_at    INTEGER NOT NULL,
  expires_at    INTEGER NOT NULL         -- created_at + TTL (para cleanup)
);

CREATE INDEX idx_audio_jobs_video_id ON audio_jobs(video_id);
CREATE INDEX idx_audio_jobs_expires_at ON audio_jobs(expires_at);
```

**Nota**: `video_id` no es PK porque puede haber múltiples jobs históricos
(ej. reintento tras error). El endpoint `/file/:videoId` busca el job
`ready` más reciente para ese `videoId`.

---

## 5. Contrato de API (OpenAPI resumido)

### `POST /api/audio/request`

Solicita la extracción de audio. Si ya existe un archivo cacheado y vigente
para ese `videoId`, responde inmediatamente con `status: "ready"`.

**Request:**
```json
{ "videoId": "lcoqOPaBe9M" }
```

**Response 202 (nuevo job encolado):**
```json
{ "jobId": "a1b2c3d4-...", "status": "queued", "videoId": "lcoqOPaBe9M" }
```

**Response 200 (ya cacheado):**
```json
{
  "jobId": "a1b2c3d4-...",
  "status": "ready",
  "videoId": "lcoqOPaBe9M",
  "title": "Mon Laferte - My One And Only Love",
  "artist": "Mon Laferte",
  "durationSec": 182,
  "fileSize": 2941021,
  "format": "m4a"
}
```

**Errores:**
- `400` — `videoId` inválido o vacío
- `422` — video privado/no disponible (yt-dlp falló al resolver)
- `429` — rate limit excedido

---

### `GET /api/audio/status/:jobId`

Polling de estado. Recomendado cada 2s desde Flutter.

**Response 200:**
```json
{
  "jobId": "a1b2c3d4-...",
  "status": "processing",
  "progress": 0.65
}
```

Cuando `status: "ready"`, incluye los mismos campos que el 200 de arriba
(`title`, `artist`, `durationSec`, `fileSize`, `format`).

Cuando `status: "error"`:
```json
{
  "jobId": "a1b2c3d4-...",
  "status": "error",
  "errorMessage": "Video unavailable: This video is private"
}
```

---

### `GET /api/audio/file/:videoId`

Sirve el archivo de audio. **Soporta `Range` headers** para descarga
parcial/reanudable — esto es lo que reemplaza el código de chunking de
Flutter.

**Headers de respuesta:**
```
Content-Type: audio/mp4   (o audio/webm)
Content-Length: 2941021
Accept-Ranges: bytes
Content-Disposition: attachment; filename="Mon Laferte - My One And Only Love.m4a"
```

Si el cliente envía `Range: bytes=0-1048575`, responde `206 Partial Content`
con `Content-Range`.

**Errores:**
- `404` — no hay archivo `ready` para ese `videoId` (el cliente debe llamar
  primero a `/request`)
- `410` — el archivo expiró y fue eliminado por el cleanup job (el cliente
  debe volver a llamar `/request`)

---

### `GET /health`

Healthcheck para Docker/orquestador. Verifica conexión a Redis, SQLite y que
el binario `yt-dlp` responde a `--version`.

---

## 6. Lógica del worker (núcleo del sistema)

```typescript
// src/queue/audioWorker.ts (pseudocódigo detallado para el agente)

worker.process(async (job) => {
  const { videoId, jobId } = job.data;

  await repository.updateStatus(jobId, 'processing');

  const outputTemplate = `/data/audio/${videoId}.%(ext)s`;

  // Comando yt-dlp clave:
  // -f bestaudio       → mejor stream de solo audio disponible
  // --no-playlist      → evita descargar playlists completas si la URL lo es
  // --no-warnings
  // --print-json       → para parsear metadata (title, artist, duration)
  // -o <template>       → ruta de salida
  // --extractor-args "youtube:player_client=ios"  → cliente menos restringido
  const args = [
    '-f', 'bestaudio[ext=m4a]/bestaudio',
    '--no-playlist',
    '--no-warnings',
    '--print-json',
    '--extractor-args', 'youtube:player_client=ios,android',
    '-o', outputTemplate,
    `https://www.youtube.com/watch?v=${videoId}`,
  ];

  const result = await runYtDlp(args, {
    onProgress: (pct) => {
      job.updateProgress(pct);
      repository.updateProgress(jobId, pct);
    },
    timeoutMs: 5 * 60 * 1000, // 5 min máx por extracción
  });

  if (result.exitCode !== 0) {
    await repository.updateStatus(jobId, 'error', {
      errorMessage: parseYtDlpError(result.stderr),
    });
    throw new Error(result.stderr);
  }

  const metadata = JSON.parse(result.stdout);
  const filePath = resolveOutputFile(videoId, metadata.ext);
  const fileSize = (await fs.stat(filePath)).size;

  await repository.updateStatus(jobId, 'ready', {
    filePath,
    fileSize,
    format: metadata.ext,
    title: metadata.title,
    artist: metadata.artist ?? metadata.uploader,
    durationSec: metadata.duration,
    expiresAt: Date.now() + TTL_MS, // ej. 7 días
  });
});
```

### Manejo de errores de yt-dlp → mensajes claros para el usuario

| stderr de yt-dlp contiene | `errorMessage` mapeado |
|---|---|
| `Video unavailable` | `"Este video ya no está disponible"` |
| `Private video` | `"Este video es privado"` |
| `Sign in to confirm your age` | `"Video con restricción de edad, no se puede descargar"` |
| `This live event` | `"No se pueden descargar transmisiones en vivo"` |
| (timeout) | `"La extracción tardó demasiado, intenta de nuevo"` |

---

## 7. Dockerfile

```dockerfile
FROM node:20-bookworm-slim

# Instalar Python (requerido por yt-dlp), ffmpeg y yt-dlp
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip ffmpeg curl ca-certificates \
    && pip3 install --no-cache-dir --break-system-packages -U yt-dlp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY dist ./dist

RUN mkdir -p /data/audio
VOLUME ["/data"]

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "dist/server.js"]
```

```yaml
# docker-compose.yml
version: "3.8"
services:
  api:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - audio_data:/data
    environment:
      - REDIS_URL=redis://redis:6379
      - DATABASE_PATH=/data/db.sqlite
      - AUDIO_DIR=/data/audio
      - FILE_TTL_HOURS=168
      - PORT=3000
    depends_on:
      - redis
    restart: unless-stopped

  worker:
    build: .
    command: ["node", "dist/queue/audioWorker.js"]
    volumes:
      - audio_data:/data
    environment:
      - REDIS_URL=redis://redis:6379
      - DATABASE_PATH=/data/db.sqlite
      - AUDIO_DIR=/data/audio
    depends_on:
      - redis
    restart: unless-stopped
    deploy:
      replicas: 2   # 2 extracciones en paralelo

  redis:
    image: redis:7-alpine
    restart: unless-stopped

volumes:
  audio_data:
```

---

## 8. Mantenimiento crítico: actualización automática de yt-dlp

YouTube cambia su sitio constantemente; yt-dlp se actualiza para seguirle el
paso. **Sin actualización automática, el backend volverá a romperse en
semanas.**

```bash
# scripts/update-ytdlp.sh — ejecutar vía cron diario
#!/bin/bash
pip3 install --no-cache-dir --break-system-packages -U yt-dlp
echo "$(date): yt-dlp updated to $(yt-dlp --version)" >> /var/log/ytdlp-update.log
```

Agregar a `docker-compose.yml` un servicio `cron` adicional o, más simple,
configurar un cron en el host que ejecute:
```bash
docker compose exec worker pip3 install --break-system-packages -U yt-dlp
docker compose restart worker
```

---

## 9. Limpieza de archivos (cleanup job)

```typescript
// src/services/cleanup.service.ts — ejecutar cada hora vía node-cron
export async function cleanupExpiredFiles() {
  const expired = repository.findExpired(Date.now());
  for (const job of expired) {
    await fs.unlink(job.filePath).catch(() => {});
    repository.markDeleted(job.id);
  }
}
```

TTL recomendado: **7 días** (`FILE_TTL_HOURS=168`). Balancea espacio en
disco vs. evitar re-extracciones para canciones populares repetidas por
varios usuarios.

---

## 10. Seguridad y rate limiting

- **Rate limit por IP**: `@fastify/rate-limit` — máx 10 requests/minuto a
  `/api/audio/request` por IP. Evita abuso y reduce riesgo de que la IP del
  servidor sea bloqueada por YouTube.
- **Validación de `videoId`**: regex `^[a-zA-Z0-9_-]{11}$` antes de pasarlo a
  yt-dlp (previene inyección de argumentos/URLs arbitrarias).
- **CORS**: restringir a los orígenes de la app si aplica (en apps móviles
  nativas no es crítico, pero documentarlo).
- **No exponer logs de yt-dlp crudos al cliente** — solo los mensajes
  mapeados de la tabla de errores.

---

## 11. Cambios requeridos en el lado de Flutter

El `DownloadRepositoryImpl` se simplifica drásticamente — ya no necesita
`youtube_explode_dart` para streams, retries con backoff, ni manejo de 403.

```dart
// Nuevo flujo simplificado
class DownloadRepositoryImpl implements DownloadRepository {
  // 1. POST /api/audio/request
  Future<String> requestExtraction(String videoId) async {
    final res = await dio.post('$baseUrl/api/audio/request',
        data: {'videoId': videoId});
    return res.data['jobId'];
  }

  // 2. Polling GET /api/audio/status/:jobId cada 2s
  Stream<DownloadState> pollStatus(String jobId) async* {
    while (true) {
      final res = await dio.get('$baseUrl/api/audio/status/$jobId');
      final status = res.data['status'];
      if (status == 'ready') {
        yield DownloadStateMetadataReady(res.data);
        return;
      }
      if (status == 'error') throw MetadataFailure(res.data['errorMessage']);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // 3. GET /api/audio/file/:videoId — Dio maneja Range/progreso nativamente
  Future<void> downloadFile(String videoId, String savePath,
      void Function(int, int) onProgress) async {
    await dio.download(
      '$baseUrl/api/audio/file/$videoId',
      savePath,
      onReceiveProgress: onProgress,
    );
  }
}
```

Este código **sí puede usar `dio` con headers normales** porque el backend
es tu propio servidor — no hay firmas, no hay 403, `dio.download` con
`Range` funciona out-of-the-box.

---

## 12. Plan de implementación paso a paso (para el agente de IA)

### Fase 1 — Setup del proyecto
1. Inicializar proyecto Node.js + TypeScript (`tsconfig.json` con target ES2022, module NodeNext)
2. Instalar dependencias: `fastify`, `@fastify/rate-limit`, `bullmq`, `ioredis`, `better-sqlite3`, `uuid`, `node-cron`, `zod` (validación)
3. Crear estructura de carpetas según sección 3
4. Configurar `.env.example` con todas las variables (`PORT`, `REDIS_URL`, `DATABASE_PATH`, `AUDIO_DIR`, `FILE_TTL_HOURS`)

### Fase 2 — Base de datos
5. Implementar `db/client.ts` con `better-sqlite3`, ejecutar migración `001_init.sql` al iniciar
6. Implementar `db/repository.ts` con funciones: `createJob`, `updateStatus`, `updateProgress`, `findByJobId`, `findLatestReadyByVideoId`, `findExpired`, `markDeleted`

### Fase 3 — Cola y worker
7. Configurar conexión Redis (`queue/connection.ts`)
8. Definir cola `audioQueue` con BullMQ (`queue/audioQueue.ts`)
9. Implementar `services/ytdlp.service.ts`: función `runYtDlp(args, options)` que spawneé el proceso, capture stdout/stderr, parsee progreso (yt-dlp imprime `[download] XX.X%` a stdout con `--progress`), y aplique timeout
10. Implementar `queue/audioWorker.ts` siguiendo el pseudocódigo de la sección 6
11. Implementar el mapeo de errores de la tabla en sección 6

### Fase 4 — API HTTP
12. Implementar `routes/audio.routes.ts`:
    - `POST /api/audio/request` — valida `videoId` con zod/regex, verifica cache (`findLatestReadyByVideoId`), si no existe crea job en SQLite + encola en BullMQ
    - `GET /api/audio/status/:jobId` — lee de SQLite
    - `GET /api/audio/file/:videoId` — implementa soporte completo de `Range` headers usando `fastify-static` o streaming manual con `fs.createReadStream(path, {start, end})`
13. Implementar `routes/health.routes.ts`
14. Implementar `plugins/errorHandler.ts` (respuestas JSON consistentes para 400/404/410/422/429/500)
15. Implementar `plugins/rateLimiter.ts`

### Fase 5 — Mantenimiento
16. Implementar `services/cleanup.service.ts` + registrar cron job cada hora con `node-cron`
17. Crear `scripts/update-ytdlp.sh`

### Fase 6 — Containerización
18. Escribir `Dockerfile` según sección 7 (verificar que `yt-dlp --version` y `ffmpeg -version` funcionen dentro del contenedor)
19. Escribir `docker-compose.yml` con servicios `api`, `worker` (2 réplicas), `redis`
20. Probar build completo: `docker compose up --build`

### Fase 7 — Pruebas end-to-end
21. Test manual: `POST /api/audio/request` con un `videoId` real de 3+ minutos → verificar que llega a `status: ready`
22. Test manual: `GET /api/audio/file/:videoId` con header `Range: bytes=0-1048575` → verificar `206 Partial Content`
23. Test manual: `videoId` de video privado → verificar `422` con mensaje claro
24. Test de carga: 5 requests simultáneos al mismo `videoId` → verificar que solo se ejecuta 1 extracción (deduplicación) y los demás reciben el mismo `jobId` o esperan el resultado cacheado
25. Verificar que `GET /health` refleja correctamente el estado de Redis/SQLite/yt-dlp

### Fase 8 — Documentación de entrega
26. Generar `README.md` con: instrucciones de deploy, variables de entorno, comandos de actualización de yt-dlp, troubleshooting común
27. Generar colección de Postman/Thunder Client o archivo `.http` con ejemplos de las 4 rutas

---

## 13. Entregables finales

1. **Repositorio de código fuente** completo según estructura de la sección 3
2. **`Dockerfile` + `docker-compose.yml`** funcionales, probados con `docker compose up`
3. **`README.md`** con instrucciones de despliegue en VPS (incluye apertura de puertos, configuración de Caddy/Nginx para HTTPS)
4. **Script de actualización de yt-dlp** (`scripts/update-ytdlp.sh`) + instrucciones de cron
5. **Colección de pruebas HTTP** (`.http` o Postman) cubriendo los 4 endpoints y casos de error
6. **Snippet de Dart actualizado** para `DownloadRepositoryImpl` (sección 11) que reemplace el código actual de `youtube_explode_dart`
7. **Documento de variables de entorno** (`.env.example`) completo y comentado

---

## 14. Riesgos y consideraciones legales (mencionar al usuario, no resolver técnicamente)

- Operar un backend que extrae audio de YouTube para terceros puede violar
  los Términos de Servicio de YouTube. Esto es distinto a hacerlo
  client-side para uso personal. Si la app va a producción/distribución
  pública, conviene revisar esto con criterio legal propio antes de lanzar.
- La IP del VPS puede ser bloqueada por YouTube si el volumen de requests es
  alto — considerar proxies residenciales o rotación de IP si se escala.
