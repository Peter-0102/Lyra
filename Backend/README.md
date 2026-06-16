# Mispoti — Audio Backend

Backend para extraer y servir audio de YouTube a la app Flutter **Mispoti**.
Reemplaza el uso directo de `youtube_explode_dart` en el cliente por una API
propia con soporte de cola de trabajos, caché y descargas reanudables.

## Stack

| Componente | Tecnología |
|---|---|
| Runtime | Node.js 20 LTS + TypeScript |
| HTTP | Fastify 5 |
| Cola | BullMQ + Redis 7 |
| Extractor | yt-dlp + ffmpeg |
| Base de datos | SQLite (better-sqlite3) |
| Contenedor | Docker + docker-compose |

## API

| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/api/audio/request` | Encola extracción o devuelve audio cachead |
| `GET` | `/api/audio/status/:jobId` | Estado de un job (polling cada 2s) |
| `GET` | `/api/audio/file/:videoId` | Descarga del archivo (soporta `Range`) |
| `GET` | `/api/health` | Healthcheck (Redis + SQLite + yt-dlp) |

Ver `tests/api-examples.http` para ejemplos completos.

## Requisitos

- **Docker** + **Docker Compose** (recomendado)
- O bien: Node.js 20+, Redis 7+, yt-dlp, ffmpeg (desarrollo local)

## Deploy rápido con Docker

```bash
# 1. Clonar / ir al directorio
cd Backend

# 2. Copiar y configurar variables
cp .env.example .env
# Editar .env si es necesario (REDIS_URL, etc.)

# 3. Build e iniciar
docker compose up --build -d

# 4. Verificar health
curl http://localhost:3000/api/health

# 5. Ver logs
docker compose logs -f api worker
```

## Desarrollo local

```bash
# Instalar dependencias
npm install

# Asegurarse de tener Redis corriendo en localhost:6379
# Verificar yt-dlp y ffmpeg instalados
yt-dlp --version
ffmpeg -version

# Iniciar servidor API (hot reload)
npm run dev

# En otra terminal, iniciar worker
npm run worker:dev
```

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `PORT` | `3000` | Puerto del servidor HTTP |
| `HOST` | `0.0.0.0` | Host donde escuchar |
| `REDIS_URL` | `redis://localhost:6379` | URL de conexión a Redis |
| `DATABASE_PATH` | `./data/db.sqlite` | Ruta al archivo SQLite |
| `AUDIO_DIR` | `./data/audio` | Directorio de archivos de audio |
| `FILE_TTL_HOURS` | `168` | TTL en horas (7 días) antes de limpiar |
| `RATE_LIMIT_MAX` | `10` | Requests/minuto por IP a `/request` |
| `CORS_ORIGIN` | `*` | Origen CORS permitido |

## Mantenimiento

### Actualizar yt-dlp

YouTube cambia constantemente. Ejecutar semanalmente:

```bash
# Si corre con Docker
docker compose exec worker pip3 install --break-system-packages -U yt-dlp
docker compose restart worker

# O mediante el script incluido
chmod +x scripts/update-ytdlp.sh
./scripts/update-ytdlp.sh
```

Agregar al cron del host para automatizar:
```cron
0 3 * * 1 cd /ruta/al/proyecto/Backend && docker compose exec -T worker pip3 install --break-system-packages -U yt-dlp && docker compose restart worker
```

### Limpieza de archivos

El cleanup se ejecuta automáticamente cada hora vía `node-cron`.
Borra archivos cuyo `expires_at` haya vencido (default: 7 días).

## Arquitectura

```
Flutter App  ──POST /request──►  Fastify API  ──enqueue──►  BullMQ
                    │                                         │
                    ▼                                         ▼
              Poll /status ◄── worker procesa ──yt-dlp──► /data/audio/
                    │                              + ffmpeg    │
                    ▼                                         ▼
            GET /file/:videoId  ◄────── stream .m4a ──────────┘
                (Range support)
```

## Troubleshooting

| Problema | Causa posible | Solución |
|---|---|---|
| `yt-dlp not found` | No instalado en el contenedor | Verificar Dockerfile |
| `ECONNREFUSED redis` | Redis no inició | `docker compose up -d redis` |
| `Job stalled` | Redis no responde | Verificar `REDIS_URL` |
| `Video unavailable` | Video privado, age-restricted o live | Verificar con otro videoId |
| `403 Forbidden` | YouTube bloqueó la IP | Esperar o usar proxy residencial |

## Consideraciones legales

Este backend extrae audio de YouTube para uso dentro de una app personal.
Operar un servicio que extrae audio de YouTube para terceros puede violar
los Términos de Servicio de YouTube. Consultar asesoría legal antes de
distribuir públicamente.
