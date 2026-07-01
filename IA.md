# Plan de Implementación: Compañero Musical Conversacional con IA
### Documento de Arquitectura — mispoti

**Autor:** Software Architect Senior (análisis técnico)
**Alcance:** Diseño puro de arquitectura. Sin código, sin diagramas UML, sin implementación.
**Principio rector:** Reutilizar al máximo la infraestructura existente (Flutter + Clean Architecture + Riverpod + GetIt + SQLite + Fastify + BullMQ + Redis). Ninguna reescritura de módulos existentes salvo lo estrictamente necesario.

---

## Índice

1. Visión general de la solución
2. Nuevas features
3. Cambios en la arquitectura
4. Modelo de datos
5. Persistencia
6. Sistema de clasificación musical
7. Perfil musical
8. Motor de recomendaciones
9. IA conversacional
10. Backend
11. Flutter
12. Flujo completo
13. Aprendizaje continuo
14. Escalabilidad
15. Roadmap
16. Riesgos técnicos
17. Mejoras futuras

---

## 1. Visión general de la solución

### 1.1 Idea central

La app pasa de ser un reproductor con biblioteca a ser un **compañero musical conversacional**. La conversación no reemplaza la navegación manual: es una **capa adicional** que interpreta lenguaje natural, contexto y comportamiento histórico para generar playlists. La biblioteca, favoritos, historial y playlists actuales **no desaparecen**; se convierten en fuentes de señal para un nuevo "cerebro" de recomendación.

Es clave separar dos cosas que hoy suenan como una sola "IA":

- **Capa de lenguaje (NLU/Chat):** interpreta lo que el usuario escribe ("estoy triste", "algo parecido a Arctic Monkeys") y lo traduce a una **intención estructurada** (mood, actividad, artista de referencia, nivel de energía, etc.).
- **Motor de recomendación:** un sistema determinista/basado en reglas y puntuaciones (no un LLM) que, dada una intención estructurada + el perfil musical + el catálogo clasificado, arma la playlist.

Esta separación es la decisión arquitectónica más importante del documento: **el LLM interpreta, no decide qué canciones suenan**. Esto reduce costos de IA, hace el sistema depurable, evita alucinaciones de canciones inexistentes, y permite que el motor de recomendación evolucione independientemente del proveedor de IA que se use.

### 1.2 Responsabilidades por capa

| Capa | Responsabilidad |
|---|---|
| **Flutter (presentation)** | Mostrar el chat, los chips rápidos, renderizar la playlist resultante, capturar feedback implícito (skip, replay, tiempo escuchado) y explícito (like/dislike de la recomendación), mantener estado de la conversación en memoria/local. |
| **Flutter (domain/data)** | Definir contratos (repositorios abstractos) para conversación, recomendación y perfil musical; orquestar llamadas a backend; cachear localmente resultados recientes. |
| **Backend (Fastify)** | Exponer endpoints de conversación y recomendación, orquestar la llamada al proveedor de IA (vía un servicio dedicado), ejecutar el motor de recomendación, persistir perfil musical agregado, encolar trabajos de clasificación musical (BullMQ), servir como fuente de verdad sincronizada. |
| **IA (LLM externo, vía servicio backend)** | Solo NLU: clasificar intención, extraer entidades (mood, artista, actividad, energía), generar mensajes conversacionales de respuesta. Nunca decide el catálogo final. |
| **SQLite (cliente)** | Persistir localmente: historial de conversación reciente, cache de recomendaciones, catálogo local clasificado (tabla central de canciones — hoy inexistente), preferencias offline, cola de eventos de feedback pendientes de sincronizar. |
| **Nube (Backend + Redis + Postgres/SQLite backend)** | Persistir perfil musical de largo plazo, clasificación musical del catálogo global, historial completo, agregaciones para recomendaciones, y todo lo que deba sobrevivir a un reinstall o sincronizar entre dispositivos. |
| **Perfil de usuario** | Es el "resumen" derivado — no una fuente primaria. Se recalcula periódicamente (job asíncrono) a partir de eventos crudos (plays, skips, favoritos, feedback de conversación). Nunca se edita a mano ni se escribe directamente desde el chat. |

### 1.3 Principio de reutilización

- El **AudioPlayerService**, **PlayerNotifier**, **AudioRepository** y el sistema de reproducción **no cambian**. La nueva funcionalidad únicamente **alimenta la cola de reproducción** (`playerProvider`) con una lista de `Song`, exactamente como hoy lo hacen `library` o `playlists`.
- **Favorites, History y Playlists existentes se mantienen intactos** como repositorios independientes; se usan como *fuentes de señal* de lectura para el motor de recomendación, no se fusionan ni se migran.
- El **AuthRepository / perfil de sesión** existente se reutiliza para asociar el `MusicProfile` y las `Conversation` a un `userId` (o a un `guestId` en modo invitado).
- Los principios de **domain/data/presentation** y la regla de que `domain/` no importa de `data/` ni `presentation/` se aplican a cada feature nueva sin excepción.

---

## 2. Nuevas features

Siguiendo el patrón *feature-first* ya usado (`favorites/`, `history/`, `playlists/`...), se proponen 5 features nuevas, cada una con su trío `domain/data/presentation`:

### 2.1 `conversation/`
Gestiona el chat: mensajes del usuario, respuestas del asistente, estado de la sesión conversacional. Es puramente de interacción — no calcula recomendaciones, solo orquesta el intercambio y delega.

**Por qué separada:** el chat es UI + estado conversacional; mezclarla con recomendación violaría separación de responsabilidades (SRP) y haría el StateNotifier gigante e inmanejable.

### 2.2 `recommendation/`
Contiene el contrato (`RecommendationRepository`) para pedir una playlist dado un `RecommendationRequest` (que puede originarse en un chip rápido o en una intención extraída del chat). Devuelve una lista de `Song` (reutilizando la entidad existente) más metadata de la recomendación (`Recommendation`).

**Por qué separada:** una recomendación puede pedirse sin pasar por el chat (chips rápidos), así que no debe depender de `conversation/`. `conversation/` depende de `recommendation/`, nunca al revés.

### 2.3 `music_profile/`
Expone el perfil musical del usuario (lectura principalmente) para mostrarlo en UI (p.ej. "Tu música" o insights) y para que `recommendation/` lo consuma.

**Por qué separada:** el perfil se recalcula del lado del servidor de forma asíncrona; el cliente solo lo lee/cachea. Aislarlo evita que otras features asuman que pueden escribirlo directamente.

### 2.4 `discovery/`
Encapsula específicamente el modo "sorpréndeme" / exploración de catálogo nuevo, con su propia lógica de balance exploración/explotación. Podría vivir dentro de `recommendation/`, pero se separa porque su UX (feedback de descubrimiento, "me gustó lo nuevo") y sus métricas de éxito son distintas de una recomendación contextual normal.

### 2.5 `context_engine/`
Determina el **contexto ambiental** en el momento de la solicitud: hora del día, día de la semana, actividad reciente (inferida de patrones, no de sensores obligatoriamente), y lo empaqueta en un `ListeningContext`. Es consumido tanto por `conversation/` (para enriquecer el prompt del LLM) como por `recommendation/` (para pesos).

**Por qué separada:** el contexto se recalcula en cada solicitud y es transversal — evita que cada feature reimplemente "qué hora es" o "qué esté haciendo el usuario ahora".

> Nota: `music_profile` y `context_engine` son las dos features "de soporte" que no tienen pantalla propia obligatoria; son mayormente domain/data, consumidas por las demás.

---

## 3. Cambios en la arquitectura

### 3.1 Qué se modifica (mínimo indispensable)

| Elemento actual | Cambio | Motivo |
|---|---|---|
| `HomeScreen` | Se añade una nueva pestaña/vista inicial de chat (o se convierte en la vista por defecto configurable), sin eliminar el `BottomNavigationBar` actual. | Requisito de UX: chat visible al abrir, pero navegación manual sigue disponible. |
| `injection_container.dart` (GetIt) | Se registran los nuevos repositorios/servicios (`ConversationRepository`, `RecommendationRepository`, `MusicProfileRepository`, `ContextEngine`) siguiendo el mismo patrón `registerLazySingleton`. | Consistencia con el patrón de DI existente. |
| `app_router.dart` (go_router) | Se agregan rutas nuevas: `/chat`, `/discovery`, opcionalmente `/profile/music-insights`. | Extensión aditiva, no reemplaza rutas existentes. |
| `database_helper.dart` | Se añade una **nueva migración** (versión 4) que crea las tablas nuevas (ver sección 5) y, opcionalmente, la tabla central `songs`. | La migración ya es un mecanismo soportado (hoy en versión 3). |
| `PlayerNotifier` | Se le agrega (opcional, no obligatorio) un hook para reportar eventos de reproducción también al pipeline de aprendizaje continuo (además de a `HistoryRepository`, como ya hace). | Reutiliza el punto de integración existente (`_recordPlay`), solo añade un segundo listener. |
| `libraryProvider` | Ningún cambio funcional obligatorio; opcionalmente se beneficia de la tabla central `songs` para enriquecer metadata (género, mood) al mostrar la biblioteca. | La clasificación es aditiva sobre `Song`. |

### 3.2 Qué se reutiliza sin tocar

- `AudioPlayerService`, `AudioPlayerServiceImpl`, todo `audio_player/` (motor de reproducción).
- `FavoritesRepository`, `PlaylistRepository`, `HistoryRepository` (se leen, no se modifican sus contratos).
- `AuthRepository` / `AuthNotifier` (se usa `userId`/modo invitado ya existente).
- `Dio` + `AuthInterceptor` + `sse_client.dart` (el SSE existente es ideal para *streaming* de respuestas del chat, ver 9.5).
- `Song` como entidad de intercambio final entre `recommendation/` y `player`.
- BullMQ + Redis del backend (se añade una nueva cola, no se reemplaza el patrón).

### 3.3 Providers nuevos y quién escucha a quién

- `conversationProvider` (StateNotifier) → escucha nada externo; expone `sendMessage()`.
- `conversationProvider` **usa internamente** `RecommendationRepository` y `ContextEngine` (vía DI), no mediante `ref.listen`, sino por inyección de dependencia directa en el notifier — igual que `PlayerNotifier` usa `HistoryRepository` hoy (`sl<HistoryRepository>()`).
- `recommendationProvider` (StateNotifier) → expone el resultado de la última recomendación (lista de `Song` + metadata) para que la UI la muestre y para que, al confirmar el usuario, se empuje a `playerProvider.playQueue(songs)` (método ya existente, tipo "reproducir esta playlist").
- `musicProfileProvider` → provider de solo lectura (`FutureProvider`/`StateNotifierProvider` simple), consumido por `recommendationProvider` para ponderar resultados y por una futura pantalla de insights.
- **Cross-feature listening nuevo:** `recommendationProvider` puede usar `ref.listen(playerProvider)` para capturar eventos de skip/replay en tiempo real y alimentar el feedback implícito (sección 13), replicando el patrón ya usado por `libraryProvider` con `downloadProvider`.

### 3.4 Repositorios nuevos (contratos `domain/`)

- `ConversationRepository`: enviar mensaje, obtener historial de sesión, cerrar/resetear sesión.
- `RecommendationRepository`: solicitar recomendación por intención estructurada o por chip rápido; enviar feedback de una recomendación.
- `MusicProfileRepository`: obtener perfil actual (cacheado localmente, refrescado del backend).
- `ContextEngine` (no es un repositorio tradicional, es un *domain service* sin estado persistente propio): calcula `ListeningContext` bajo demanda.
- `SongClassificationRepository` (opcional, si se decide exponer clasificación al cliente): consulta metadata de clasificación de una canción.

### 3.5 Servicios nuevos

- **`ConversationalAIService`** (vive en el backend, no en Flutter): encapsula la llamada al proveedor de LLM. Es el único punto que "sabe" qué proveedor de IA se usa, permitiendo cambiarlo sin tocar el resto del sistema (principio de inversión de dependencias aplicado también en el backend).
- **`RecommendationEngineService`** (backend): implementa el algoritmo conceptual de la sección 8.
- **`ClassificationWorker`** (backend, BullMQ): clasifica canciones de forma asíncrona (sección 6).
- **`ProfileAggregationWorker`** (backend, BullMQ): recalcula `MusicProfile` periódicamente a partir de eventos crudos.

---

## 4. Modelo de datos

Todas las entidades nuevas siguen el mismo patrón que las existentes: clases inmutables (equivalente a `Freezed` en el cliente), con contraparte de tabla en el backend. Se describen campo a campo, sin código.

### 4.1 `Conversation`
Representa una sesión de chat.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | String (UUID) | Identificador de la sesión. |
| `userId` | String? | Nulo en modo invitado; referencia al usuario autenticado. |
| `startedAt` | DateTime | Inicio de la sesión. |
| `lastMessageAt` | DateTime | Última actividad, usada para expirar sesiones inactivas. |
| `summary` | String? | Resumen generado (ver 9.4) cuando la conversación crece demasiado. |
| `status` | Enum (`active`, `archived`) | Estado de la sesión. |

### 4.2 `ConversationMessage`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | String | Identificador del mensaje. |
| `conversationId` | String | FK a `Conversation`. |
| `role` | Enum (`user`, `assistant`, `system`) | Emisor. |
| `content` | String | Texto del mensaje (lo que el usuario escribió o lo que respondió la IA). |
| `extractedIntent` | `ConversationIntent`? | Solo en mensajes de usuario; intención estructurada extraída por el NLU. |
| `createdAt` | DateTime | Marca temporal. |

### 4.3 `ConversationIntent` (estructura interna, no necesariamente tabla propia)
| Campo | Tipo | Descripción |
|---|---|---|
| `mood` | Mood? | Estado de ánimo detectado. |
| `activity` | Activity? | Actividad detectada. |
| `referenceArtist` | String? | Artista mencionado como referencia ("parecido a X"). |
| `energyLevel` | Int? (0–10) | Nivel de energía deseado. |
| `explorationRequested` | bool | Si el usuario pidió sorpresa/descubrimiento explícitamente. |
| `rawText` | String | Texto original, para auditoría/depuración. |

### 4.4 `Recommendation`
Representa el resultado de una solicitud de playlist (por chat o por chip).

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | String | Identificador. |
| `userId` | String? | Usuario o invitado. |
| `sourceType` | Enum (`chat`, `quickChip`, `autoplay`) | Origen de la solicitud. |
| `intentSnapshot` | `ConversationIntent`? | Intención usada para generarla (si vino de chat). |
| `contextSnapshot` | `ListeningContext` | Contexto en el momento de generación. |
| `songIds` | List\<String\> | Canciones resultantes, en orden. |
| `explanation` | String? | Texto breve mostrable al usuario ("Basado en tu historial reciente y que es de noche"). |
| `createdAt` | DateTime | Marca temporal. |

### 4.5 `RecommendationFeedback`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | String | Identificador. |
| `recommendationId` | String | FK a `Recommendation`. |
| `songId` | String | Canción específica sobre la que hay feedback (una recomendación tiene N feedbacks, uno por canción reproducida). |
| `signal` | Enum (`completed`, `skippedEarly`, `skippedLate`, `replayed`, `liked`, `disliked`, `addedToFavorites`) | Tipo de señal. |
| `positionMs` | int? | En qué punto de la canción ocurrió el skip, si aplica. |
| `createdAt` | DateTime | Marca temporal. |

### 4.6 `MusicProfile`
Perfil agregado y dinámico del usuario (recalculado, no editado a mano).

| Campo | Tipo | Descripción |
|---|---|---|
| `userId` | String | FK a usuario (o `guestId`). |
| `topArtists` | List\<ArtistAffinity\> | Artistas con mayor afinidad. |
| `topGenres` | List\<GenreAffinity\> | Géneros con mayor afinidad. |
| `avoidedGenres` | List\<String\> | Géneros con afinidad negativa persistente (muchos skips). |
| `contextualPreferences` | Map\<Activity, List\<GenreAffinity\>\> | Preferencias por actividad (mañana, estudio, trabajo...). |
| `explorationScore` | double (0–1) | Qué tan receptivo es el usuario a descubrir música nueva (derivado de tasa de aceptación de recomendaciones de exploración). |
| `completionRate` | double | % de canciones que termina vs. abandona. |
| `lastRecalculatedAt` | DateTime | Última vez que el worker de agregación lo recalculó. |
| `version` | int | Para invalidar caches del cliente cuando cambia el esquema. |

### 4.7 `MusicPreference` (granular, insumo del perfil)
Representa una preferencia puntual detectada, antes de agregarse al perfil.

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | String | Identificador. |
| `userId` | String | FK a usuario. |
| `type` | Enum (`artist`, `genre`, `tag`) | Tipo de preferencia. |
| `value` | String | Valor (nombre del artista/género/tag). |
| `weight` | double | Peso acumulado (aumenta con señales positivas, decae con negativas). |
| `updatedAt` | DateTime | Última actualización. |

### 4.8 `ListeningContext`
Contexto calculado en el momento (no necesariamente persistido, salvo como snapshot dentro de `Recommendation`).

| Campo | Tipo | Descripción |
|---|---|---|
| `timeOfDay` | Enum (`morning`, `afternoon`, `evening`, `night`) | Derivado de la hora local. |
| `dayOfWeek` | Enum | Día de la semana. |
| `inferredActivity` | Activity? | Inferida por patrones históricos (p.ej. "a esta hora normalmente estudias"), nunca por sensores intrusivos. |
| `recentSkipRate` | double? | Señal de la sesión actual, si ya hubo reproducción. |
| `isNewSession` | bool | Si es la primera interacción del día. |

### 4.9 `Mood` (enum/catálogo controlado)
Valores fijos: `happy`, `relaxed`, `sad`, `motivated`, `nostalgic` (extensible), cada uno mapeado internamente a rangos de atributos musicales (ver sección 6).

### 4.10 `Activity` (enum/catálogo controlado)
Valores fijos: `studying`, `training`, `working`, `sleeping`, `driving` (extensible).

### 4.11 `ArtistAffinity` / `GenreAffinity`
| Campo | Tipo | Descripción |
|---|---|---|
| `name` | String | Nombre del artista o género. |
| `score` | double | Afinidad normalizada (0–1). |
| `sampleSize` | int | Cuántas señales sustentan el score (para no confiar en scores con poca data). |

### 4.12 `SongClassification` (clasificación musical, ver sección 6)
| Campo | Tipo | Descripción |
|---|---|---|
| `songId` | String | FK a `Song`. |
| `genre` | String? | Género principal. |
| `subgenres` | List\<String\> | Subgéneros. |
| `mood` | List\<Mood\> | Moods asociados (puede tener varios). |
| `energy` | double (0–1) | Nivel de energía. |
| `tempo` | int? (BPM) | Tempo estimado. |
| `danceability` | double? (0–1) | Bailabilidad. |
| `instrumentalness` | double? (0–1) | Qué tan instrumental es. |
| `suggestedActivities` | List\<Activity\> | Actividades para las que encaja. |
| `era` | String? | Década/época. |
| `language` | String? | Idioma detectado. |
| `popularity` | double? (0–1) | Popularidad relativa (si hay dato disponible). |
| `classificationSource` | Enum (`externalApi`, `heuristic`, `userDerived`) | De dónde vino el dato (sección 6.3). |
| `classifiedAt` | DateTime | Marca temporal. |

### 4.13 `Session` (sesión de escucha, distinta de `Conversation`)
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | String | Identificador. |
| `userId` | String? | Usuario o invitado. |
| `startedAt` | DateTime | Inicio. |
| `endedAt` | DateTime? | Fin (si terminó). |
| `originRecommendationId` | String? | Si la sesión empezó a partir de una recomendación. |
| `songsPlayed` | List\<String\> | Canciones reproducidas en orden. |

---

## 5. Persistencia

### 5.1 Regla general

- **SQLite local:** todo lo que el usuario necesita ver instantáneamente sin red (chat reciente, última recomendación, cache del perfil, catálogo local clasificado) + una **cola de eventos pendientes de sincronizar** (outbox pattern), para que el feedback nunca se pierda si no hay conexión.
- **Backend (nube):** fuente de verdad de todo lo que debe persistir entre dispositivos y a largo plazo: `MusicProfile`, `SongClassification` del catálogo global, historial completo de `RecommendationFeedback`, conversaciones archivadas.
- **Solo memoria:** el estado de la conversación *en curso* (antes de persistir cada mensaje), el `ListeningContext` calculado al vuelo, y estados de UI transitorios (loading, streaming de la respuesta del chat).

### 5.2 Qué se guarda dónde (tabla resumen)

| Dato | SQLite local | Backend | Solo memoria |
|---|---|---|---|
| Mensajes de chat | Sí (cache de sesión activa + últimas N sesiones) | Sí (persistencia completa, para usuarios autenticados) | — |
| `MusicProfile` | Sí (cache de solo lectura) | Sí (fuente de verdad, recalculado por worker) | — |
| `SongClassification` | Sí (para canciones descargadas localmente) | Sí (catálogo global) | — |
| `RecommendationFeedback` | Sí (outbox hasta sincronizar) | Sí (definitivo) | — |
| `ListeningContext` | No | No | Sí |
| Tabla central `songs` | Sí (obligatoria, ver 5.3) | Opcional (solo si hay biblioteca en la nube a futuro) | — |
| Streaming de respuesta del chat (tokens parciales) | No | No | Sí (se persiste el mensaje completo al finalizar) |

### 5.3 Tabla central de canciones: ¿hace falta?

**Sí, es indispensable**, y es el cambio de persistencia más importante de todo el plan. Hoy `Song` se reconstruye escaneando el filesystem cada vez (`AudioRepositoryImpl`), sin tabla propia. Sin una tabla central:

- No hay dónde adjuntar `SongClassification` de forma eficiente (tendría que recalcularse o buscarse por `filePath` cada vez).
- No se puede indexar por género/mood/energía para que el motor de recomendación filtre rápido.

**Diseño propuesto:** una tabla `songs` con los campos actuales de `Song` (`id`, `title`, `artist`, `filePath`, `durationMillis`, `thumbnailUrl`, `videoId`) más una relación 1:1 (o embebida) con `song_classification`. El escaneo de filesystem (`AudioRepositoryImpl`) pasa de ser la única fuente a ser un **proceso de sincronización**: al escanear, hace *upsert* en `songs` en lugar de reconstruir todo en memoria. Esto es aditivo — no cambia el contrato de `AudioRepository`, solo su implementación interna.

### 5.4 Índices recomendados

- `songs(genre)`, `songs(energy)` — para filtrado rápido por el motor de recomendación.
- `conversation_messages(conversationId, createdAt)` — para reconstruir el hilo en orden.
- `recommendation_feedback(userId, createdAt)` — para el worker de agregación.
- `music_preferences(userId, type, value)` — único compuesto, para upsert eficiente de pesos.

### 5.5 Migración de la base actual

1. Nueva migración SQLite (versión 4 en `database_helper.dart`), aditiva: crea tablas nuevas (`songs`, `song_classification`, `conversations`, `conversation_messages`, `recommendation_feedback_outbox`, `music_profile_cache`). No se toca ninguna tabla existente (`favorite_songs`, `playlist_songs`).
2. Job de backfill (ejecutado una vez, en background, al primer arranque tras el update): recorre la biblioteca local vía `AudioRepository` existente y hace *upsert* en `songs`, sin bloquear la UI ni requerir conexión.
3. La clasificación (`song_classification`) se llena de forma **perezosa y asíncrona**: no bloquea el backfill; se completa a medida que el backend clasifica canciones (sección 6) y el cliente sincroniza.

---

## 6. Sistema de clasificación musical

### 6.1 Objetivo

Enriquecer cada canción con atributos (género, mood, energía, tempo, etc.) sin depender de que el usuario los ingrese manualmente.

### 6.2 Fuentes de información posibles (comparadas)

| Fuente | Ventajas | Desventajas |
|---|---|---|
| **API externa de metadata musical** (p.ej. servicios de metadata por artista/canción) | Datos de alta calidad, ya curados (género, era, popularidad) | Requiere que el título/artista extraído del archivo/YouTube coincida bien; límites de rate; dependencia externa |
| **Heurística basada en metadata existente** (título, artista, tags de YouTube al momento de descarga) | Sin costo adicional, disponible ya en `DownloadServiceImpl` | Poca precisión para mood/energía; bueno solo para género/artista |
| **Análisis de audio (tempo, energía) vía librería de audio-features** | Más preciso para mood/energía/tempo reales | Costoso computacionalmente; requiere procesar el archivo de audio, no solo metadata |
| **Derivado del comportamiento del usuario (`userDerived`)** | Gratis, mejora con el uso, no depende de proveedores externos | Solo aparece con el tiempo; no sirve para clasificar canciones nunca reproducidas |

**Recomendación:** enfoque híbrido en capas, en este orden de prioridad:
1. Al descargarse una canción nueva (`DownloadServiceImpl` ya tiene el flujo), se encola un job de clasificación (`ClassificationWorker`) que intenta la **API externa** primero (género, era, popularidad — más el `mood`/`energy` si el proveedor los ofrece).
2. Si la API externa no responde o no tiene datos, se aplica la **heurística** (por género de artista conocido, patrones de título) como fallback de baja confianza (`classificationSource: heuristic`).
3. Con el tiempo, las señales de comportamiento (`userDerived`) pueden **refinar** (no reemplazar) mood/energía: por ejemplo, si muchos usuarios piden "energía alta" y esta canción aparece con alta tasa de completitud en esas recomendaciones, se ajusta su `energy` levemente.

### 6.3 Dónde vive el procesamiento

Todo el trabajo de clasificación ocurre en el **backend**, vía `ClassificationWorker` sobre BullMQ (reutilizando el patrón ya existente de `audio-extraction`), nunca en el cliente. Esto evita duplicar llamadas a APIs externas por cada usuario que tenga la misma canción, y permite cachear la clasificación **por canción a nivel global** (si dos usuarios descargan la misma canción de YouTube, con el mismo `videoId`, se clasifica una sola vez).

### 6.4 Confianza y versión

Cada `SongClassification` lleva `classificationSource` y podría llevar una `confidence` implícita por la fuente. El motor de recomendación (sección 8) puede ponderar menos las clasificaciones heurísticas que las de API externa.

---

## 7. Perfil musical

### 7.1 Naturaleza del perfil

El `MusicProfile` es un **agregado derivado**, recalculado periódicamente por `ProfileAggregationWorker` (BullMQ, cron o disparado por volumen de eventos nuevos) a partir de eventos crudos: `RecommendationFeedback`, plays completos (ya registrados vía `HistoryRepository`), favoritos, y patrones temporales.

### 7.2 Cómo responde a las preguntas del producto

| Pregunta | Fuente de dato |
|---|---|
| ¿Qué artistas escucha? | `topArtists` (agregado de plays + favoritos, ponderado por recencia). |
| ¿Qué géneros? | `topGenres`, derivado de `SongClassification` de las canciones reproducidas. |
| ¿Qué evita? | `avoidedGenres`, géneros con alta tasa de `skippedEarly` sostenida en el tiempo. |
| ¿Qué canciones termina / abandona? | `completionRate` global + por canción (vía `RecommendationFeedback.signal`). |
| ¿Cuáles repite? | Señal `replayed`, acumulada en `MusicPreference` con peso extra. |
| ¿Qué escucha por la mañana / estudiando / trabajando? | `contextualPreferences`, cruzando `ListeningContext.timeOfDay`/`inferredActivity` de cada sesión con el género de lo reproducido. |
| ¿Qué descubre y termina gustándole? | Recomendaciones con `sourceType: discovery` (o `explorationRequested`) que terminan con `completed`/`liked`; alimenta `explorationScore`. |
| ¿Cómo evoluciona? | `weight` en `MusicPreference` usa decaimiento temporal (las señales viejas pesan menos), y `version`/`lastRecalculatedAt` permiten trazar la evolución si se decide guardar snapshots históricos (opcional, fase futura). |

### 7.3 Por qué agregado y no en tiempo real

Calcular el perfil completo en cada solicitud sería costoso y volátil (una sola sesión mala no debería redefinir el perfil). El recálculo periódico (p.ej. cada N eventos o cada X horas) da estabilidad, y el motor de recomendación puede combinar el perfil "estable" con señales de la sesión actual (contexto) para no sentirse desactualizado.

---

## 8. Motor de recomendaciones

### 8.1 Naturaleza del motor

**No es un LLM.** Es un sistema de **scoring y filtrado** sobre el catálogo clasificado (`songs` + `song_classification`), determinista y auditable. El LLM solo produce la `ConversationIntent` de entrada; el motor decide las canciones.

### 8.2 Pipeline conceptual (fases, no código)

1. **Filtrado duro:** excluir canciones no disponibles (no descargadas si se prioriza catálogo local), y opcionalmente excluir géneros en `avoidedGenres` salvo que la intención los pida explícitamente.
2. **Scoring por señal**, cada canción candidata recibe un puntaje combinado de:
   - Afinidad de artista/género (`ArtistAffinity`/`GenreAffinity` del perfil).
   - Ajuste a la intención conversacional (mood/energía/actividad solicitados vs. `SongClassification` de la canción).
   - Contexto (`ListeningContext`: hora del día, actividad inferida).
   - Novedad/exploración (bonus si `explorationScore` del usuario es alto y la canción es poco escuchada por él).
   - Recencia negativa (penalización leve si sonó hace muy poco, para evitar repetición excesiva salvo pedido explícito de repetir).
3. **Diversificación:** evitar que la playlist final sea 10 canciones del mismo artista (regla de máximo N por artista).
4. **Selección final + orden:** top-K por score, con un orden que mezcle "empezar fuerte" (alta confianza) y variar hacia el final.
5. **Explicación:** se genera un texto corto (`Recommendation.explanation`) basado en las señales dominantes que ganaron el score — esto puede ser una plantilla simple (no requiere LLM) o, opcionalmente, pedirle al LLM que redacte una frase natural a partir de las señales ya calculadas (nunca que invente canciones).

### 8.3 Pesos conceptuales (punto de partida, ajustable)

| Señal | Peso relativo sugerido | Justificación |
|---|---|---|
| Intención explícita de la conversación (mood/energía/artista pedido) | Alto | Es lo que el usuario pidió *ahora*; debe dominar. |
| Afinidad histórica (perfil) | Medio-alto | Da personalización de fondo, pero no debe pisar lo que se pidió explícitamente. |
| Contexto (hora/actividad) | Medio | Ajusta, no decide por sí solo. |
| Exploración/novedad | Bajo-medio, escalado por `explorationScore` | Debe sentirse como sorpresa ocasional, no dominar la lista. |
| Recencia negativa (anti-repetición) | Bajo, salvo pedido explícito de repetir | Evita monotonía sin ser agresivo. |

Estos pesos deben vivir como **configuración**, no hardcodeados, para poder ajustarse por experimentación (A/B) sin desplegar cambios de arquitectura.

### 8.4 Caso "sorpréndeme"

Es simplemente el caso donde `explorationRequested = true` invierte temporalmente los pesos: novedad domina, afinidad histórica baja su peso (para no devolver "lo de siempre"), pero el filtrado duro de `avoidedGenres` se mantiene (sorpresa no significa ignorar lo que el usuario rechaza activamente).

---

## 9. IA conversacional

### 9.1 Función exacta del LLM

Un único rol: **NLU + generación de respuesta conversacional breve**. Recibe el mensaje del usuario + contexto mínimo necesario, devuelve una `ConversationIntent` estructurada (idealmente como salida estructurada/JSON, ver el patrón ya soportado en `anthropic_api_in_artifacts` de "structured outputs") y un texto de respuesta corto tipo "Va, algo relajante para esta noche 🎧".

### 9.2 Memoria necesaria

- **Corto plazo (obligatoria):** los últimos N mensajes de la conversación activa, para mantener coherencia ("y algo más movido" después de "quiero música relajante" debe entenderse como continuación).
- **Largo plazo (opcional, resumida):** un resumen de preferencias ya conocidas del `MusicProfile` (top géneros/artistas, no el perfil completo) para que el LLM no tenga que "redescubrir" gustos obvios en cada sesión.

### 9.3 Qué contexto enviar / no enviar

**Enviar:**
- Últimos mensajes de la conversación activa (recortados).
- Resumen compacto del `MusicProfile` (top 5 artistas, top 5 géneros, moods frecuentes) — no el perfil completo con todos los pesos.
- `ListeningContext` actual (hora, actividad inferida) si es relevante para la interpretación.

**No enviar:**
- Historial completo de reproducción (irrelevante para NLU, caro en tokens).
- Datos de otros usuarios.
- IDs internos, `filePath`, tokens de autenticación, ni ningún dato técnico interno.
- El catálogo completo de canciones (el LLM no elige canciones, no necesita conocerlas).

### 9.4 Resumen de conversaciones largas

Cuando una `Conversation` supera un umbral de mensajes (p.ej. 20), el backend dispara (de forma asíncrona, no bloqueando la respuesta actual) una llamada de resumen que condensa los mensajes antiguos en `Conversation.summary`, y a partir de ahí el prompt usa `summary` + últimos N mensajes en vez de la conversación completa. Es el mismo patrón de "memoria comprimida" usado en asistentes conversacionales de larga duración.

### 9.5 Reducción de costos

- Usar un modelo pequeño/rápido para la clasificación de intención (tarea simple, estructurada) y reservar un modelo más capaz solo si se decide generar explicaciones conversacionales más elaboradas.
- Cachear intenciones para mensajes idénticos o muy similares a chips rápidos (p.ej. "estoy triste" mapea directo a un mood conocido sin necesitar LLM si coincide con un chip existente — los chips pueden resolverse **sin IA en absoluto**, ahorrando la llamada por completo).
- Streaming de la respuesta conversacional (reutilizando `sse_client.dart` ya existente en el proyecto) para mejorar percepción de velocidad sin aumentar costo real.
- Resumir conversaciones largas (9.4) para no reenviar historial creciente en cada turno.

### 9.6 Manejo de sesiones

Una `Conversation` se considera activa mientras haya actividad reciente (umbral de inactividad, p.ej. 30–60 min); pasado eso, se marca `archived` y la siguiente interacción crea una nueva `Conversation`. Esto evita prompts eternos y permite que el backend limpie/resuma conversaciones viejas en batch (similar al cron de limpieza que ya existe para `audio_jobs` con TTL de 7 días).

---

## 10. Backend

### 10.1 Endpoints nuevos

| Endpoint | Método | Propósito |
|---|---|---|
| `/api/conversation/message` | POST | Enviar un mensaje de usuario, recibir intención + respuesta (puede ser SSE para streaming). |
| `/api/conversation/:id/history` | GET | Obtener historial de una conversación. |
| `/api/recommendation` | POST | Solicitar una recomendación (por intención estructurada o por chip). |
| `/api/recommendation/:id/feedback` | POST | Registrar `RecommendationFeedback`. |
| `/api/music-profile` | GET | Obtener el `MusicProfile` actual del usuario. |
| `/api/music-profile/sync` | POST | Sincronizar eventos pendientes desde el outbox local (batch). |
| `/api/songs/classification/:songId` | GET | Consultar clasificación de una canción (uso interno/depuración, opcional exponerlo). |

### 10.2 Servicios

- `ConversationalAIService` — wrapper del proveedor LLM (aislado, intercambiable).
- `RecommendationEngineService` — implementa el pipeline de la sección 8.
- `ClassificationService` — invocado por el worker, consulta fuentes externas + heurísticas.
- `ProfileAggregationService` — invocado por el worker, recalcula `MusicProfile`.

### 10.3 Workers (BullMQ, reutilizando Redis existente)

- `classification-queue` — un job por canción nueva descargada (o encolado en batch para backfill del catálogo existente).
- `profile-aggregation-queue` — un job por usuario, disparado por umbral de eventos nuevos o por cron periódico (p.ej. cada 6h).
- `conversation-summary-queue` — un job por conversación que cruza el umbral de mensajes (9.4).

### 10.4 Tablas backend nuevas

Equivalentes a las entidades de la sección 4: `conversations`, `conversation_messages`, `recommendations`, `recommendation_feedback`, `music_profiles`, `music_preferences`, `song_classifications`, `sessions`. Se agregan sobre el esquema existente (`audio_jobs`, `users`, etc.) sin tocarlas.

### 10.5 Índices

Los mismos descritos en 5.4, aplicados también en la base del backend (que probablemente deba migrar de `better-sqlite3` a Postgres si se apunta a escala — ver sección 14, esto es una decisión a evaluar, no obligatoria de entrada).

### 10.6 Eventos

Se recomienda introducir un **bus de eventos interno** simple (puede ser tan simple como emitir eventos a las colas de BullMQ) para que "una canción terminó" o "un feedback llegó" dispare, de forma desacoplada, tanto la actualización del perfil como futuras integraciones (p.ej. analítica).

### 10.7 Cachés

- Cache de `MusicProfile` en Redis (TTL corto, p.ej. 10 min) para no golpear la base en cada solicitud de recomendación.
- Cache de clasificación por `videoId`/canción (evita reclasificar la misma canción para distintos usuarios).
- Cache de resumen de conversación reciente en Redis mientras la sesión está activa.

---

## 11. Flutter

### 11.1 Pantallas nuevas

- `ChatScreen` — vista conversacional principal, con chips rápidos.
- `RecommendationResultScreen` (o un panel/bottom sheet, a decidir en UX) — muestra la playlist generada con opción de reproducir todo o canción por canción.
- `DiscoveryScreen` (opcional, podría integrarse como un modo dentro de `ChatScreen`) — modo "sorpréndeme" con feedback dedicado.
- Insight de perfil musical (opcional, fase futura) dentro de `ProfileScreen` existente, sin crear pantalla nueva obligatoria.

### 11.2 Widgets nuevos

- `ChatBubble` (mensaje de usuario/asistente).
- `QuickChipsRow` (moods, actividades, "basado en...", artistas frecuentes).
- `RecommendationCard` / `PlaylistPreviewList`.
- `TypingIndicator` (para el streaming de respuesta vía SSE).

### 11.3 Providers / StateNotifier

- `conversationProvider` → `ConversationState` (`messages`, `isTyping`, `currentIntent`) / `ConversationNotifier`.
- `recommendationProvider` → `RecommendationState` (`songs`, `explanation`, `isLoading`) / `RecommendationNotifier`.
- `musicProfileProvider` → lectura simple, cacheada.

### 11.4 Navegación

`ChatScreen` se agrega como destino inicial opcional en `app_router.dart`; el `BottomNavigationBar` existente en `HomeScreen` gana una pestaña "Chat" (o se convierte en la pantalla de entrada, configurable), sin remover ninguna pestaña actual (Biblioteca, Favoritos, Playlists, etc. siguen intactas).

---

## 12. Flujo completo

1. Usuario abre la app → `AuthNotifier` resuelve sesión (autenticado/invitado) como ya ocurre hoy.
2. `HomeScreen`/`ChatScreen` se muestra con saludo + chips rápidos; en paralelo, `musicProfileProvider` carga el perfil cacheado local (si existe) para no esperar red.
3. Usuario escribe "estoy triste" **o** toca un chip → dos caminos:
   - **Chip:** se resuelve localmente a una `ConversationIntent` conocida, **sin llamar al LLM**, y se pasa directo a `recommendationProvider`.
   - **Texto libre:** `conversationProvider.sendMessage()` → `ConversationRepository` → backend → `ConversationalAIService` (LLM) devuelve `ConversationIntent` + respuesta textual (streaming vía SSE reutilizando `sse_client.dart`).
4. `recommendationProvider` toma la `ConversationIntent` (+ `ListeningContext` calculado por `context_engine`) y llama a `RecommendationRepository.getRecommendation()`.
5. Backend ejecuta `RecommendationEngineService` (pipeline de la sección 8) usando `MusicProfile` cacheado en Redis + `song_classifications` + catálogo disponible, y devuelve `Recommendation` (lista de `songIds` + explicación).
6. Cliente resuelve `songIds` contra la tabla local `songs` (o solicita metadata si falta) y construye la lista de `Song`.
7. Se muestra `RecommendationResultScreen`/panel con la explicación y la lista.
8. Usuario toca "Reproducir" → se llama al método existente de `playerProvider` para cargar la cola (mismo mecanismo que hoy usan `library`/`playlists`), y **el reproductor actual (`PlayerNotifier`, `AudioPlayerService`) toma el control sin cambios**.
9. Mientras suena, `PlayerNotifier` sigue registrando en `HistoryRepository` (como hoy) **y además** emite eventos que `recommendationProvider` escucha (`ref.listen`) para generar `RecommendationFeedback` (skip, completado, replay).
10. El feedback se guarda en el outbox local (SQLite) y se sincroniza al backend cuando hay red; el `ProfileAggregationWorker` eventualmente recalcula el `MusicProfile`, cerrando el ciclo de aprendizaje.

---

## 13. Aprendizaje continuo

### 13.1 Eventos a registrar

- Reproducción completa de una canción (ya existe vía `HistoryRepository`, se reutiliza).
- Skip temprano/tardío (nuevo, vía `RecommendationFeedback`).
- Replay inmediato de una canción.
- Favorito agregado/quitado durante o después de una recomendación (ya existe el repositorio, se correlaciona con la `Recommendation` activa si aplica).
- Aceptación o rechazo explícito de una recomendación completa ("me gustó esta lista" / "no, otra cosa").
- Uso de chips vs. texto libre (para entender qué canal prefiere el usuario, útil para UX, no para el motor musical en sí).

### 13.2 Feedback implícito vs. explícito

- **Implícito:** todo lo que se infiere del comportamiento (skip, tiempo escuchado, replay) — es la señal más abundante y la que alimenta el `MusicProfile` día a día.
- **Explícito:** acciones deliberadas (like/dislike de una recomendación, favorito). Debe pesar más que el implícito equivalente cuando ambos están disponibles, porque es una señal de mayor intención.

### 13.3 Cómo mejora futuras recomendaciones

El ciclo es: **evento crudo → outbox local → sincronización → agregación periódica (worker) → `MusicProfile` actualizado → cacheado en Redis → usado en el próximo scoring**. No hay reentrenamiento de modelos de IA en este diseño (el LLM no se reentrena); lo que "aprende" es el perfil y los pesos de afinidad, que son estructuras de datos simples, auditables y explicables — coherente con el requisito de no depender de una IA específica para el motor.

---

## 14. Escalabilidad

### 14.1 Diseño pensando en millones de usuarios

- **Clasificación de canciones es global, no por usuario:** clasificar una canción una sola vez (cacheada por `videoId`) y reutilizarla para todos los usuarios que la tengan es el ahorro más grande de costo/tiempo a escala.
- **Perfil agregado, no recalculado en cada request:** ya cubierto en 7.3, es clave para no saturar la base con cómputo síncrono.
- **Separación NLU vs. motor de recomendación:** permite escalar el motor de recomendación (CPU/DB-bound) independientemente del componente que llama al LLM (I/O-bound, con costos por proveedor externo).
- **Colas (BullMQ/Redis) para todo trabajo pesado:** clasificación, agregación de perfil y resumen de conversación ya están diseñados como jobs asíncronos desde el día uno, no como llamadas síncronas bloqueantes.

### 14.2 Componentes reemplazables sin romper la arquitectura

| Componente | Reemplazable por | Por qué es seguro reemplazarlo |
|---|---|---|
| `ConversationalAIService` (proveedor LLM) | Cualquier otro proveedor de IA | Está detrás de una interfaz; nada fuera de este servicio conoce el proveedor. |
| Motor de recomendación (scoring) | Un sistema más sofisticado (p.ej. embeddings, modelo de ranking aprendido) | El contrato `RecommendationRepository` no cambia; solo cambia la implementación interna del backend. |
| `better-sqlite3` (backend) | Postgres/MySQL a escala | Los repositorios ya abstraen el acceso a datos (patrón ya usado en Flutter, aplicable igual en backend). |
| Fuente de clasificación externa | Otro proveedor de metadata | Aislado en `ClassificationService`; el resto del sistema solo consume `SongClassification`. |

### 14.3 Qué NO debería escalar de forma ingenua

Enviar el catálogo completo o el perfil completo al LLM en cada mensaje. Esto es, además de caro, innecesario dado el diseño de la sección 9 (el LLM nunca necesita conocer el catálogo).

---

## 15. Roadmap

### Fase 0 — Fundaciones de datos (sin IA todavía)
- **Objetivo:** crear la tabla central `songs` y migrar el escaneo actual a upsert sobre ella, sin ningún cambio visible para el usuario.
- **Archivos afectados:** `database_helper.dart` (migración v4), `AudioRepositoryImpl`.
- **Features involucradas:** `audio_player/`, `library/`.
- **Riesgos:** inconsistencia entre filesystem y tabla si el usuario borra archivos fuera de la app (mitigar con reconciliación en cada escaneo, ya que `AudioRepositoryImpl` ya recorre el filesystem).
- **Dependencias:** ninguna.
- **Criterio de aceptación:** la biblioteca se sigue viendo idéntica a hoy; la tabla `songs` queda poblada y sincronizada con el filesystem.

### Fase 1 — Clasificación musical (backend)
- **Objetivo:** poblar `song_classification` para el catálogo ya descargado + nuevas descargas.
- **Archivos afectados:** backend (`ClassificationWorker`, `ClassificationService`, migraciones de tablas), `DownloadServiceImpl` (encolar job al completar descarga).
- **Features involucradas:** `download/` (backend), nueva feature backend de clasificación.
- **Riesgos:** dependencia de disponibilidad/costos de API externa; cobertura incompleta al inicio.
- **Dependencias:** Fase 0.
- **Criterio de aceptación:** al menos las descargas nuevas quedan clasificadas automáticamente; el backfill del catálogo existente corre en background sin afectar UX.

### Fase 2 — Chips rápidos (sin LLM)
- **Objetivo:** implementar `recommendation/` end-to-end usando solo los chips (mood/actividad predefinidos), sin conversación libre todavía. Esto valida el motor de recomendación de forma aislada.
- **Archivos afectados:** nueva feature `recommendation/` (Flutter + backend), `RecommendationEngineService`.
- **Features involucradas:** `recommendation/`, `music_profile/` (versión mínima con datos que ya existen: favoritos + historial), `context_engine/`.
- **Riesgos:** calidad de recomendación pobre si la clasificación (Fase 1) tiene poca cobertura aún.
- **Dependencias:** Fase 0 y 1 (al menos parcialmente).
- **Criterio de aceptación:** un usuario puede tocar "Estudiar" y recibir una playlist reproducible coherente.

### Fase 3 — Perfil musical dinámico
- **Objetivo:** implementar `music_profile/` completo con `ProfileAggregationWorker` real, `RecommendationFeedback` y outbox.
- **Archivos afectados:** backend (workers, tablas), Flutter (`recommendation/` empieza a reportar feedback, `PlayerNotifier` se conecta vía `ref.listen`).
- **Features involucradas:** `music_profile/`, `recommendation/`.
- **Riesgos:** volumen de eventos puede ser alto; cuidar el diseño del outbox para no perder datos ni saturar batch de sync.
- **Dependencias:** Fase 2.
- **Criterio de aceptación:** las recomendaciones mejoran medibles con el uso (p.ej. mayor `completionRate` en A/B).

### Fase 4 — Chat conversacional con IA
- **Objetivo:** introducir `conversation/`, `ConversationalAIService`, NLU real, streaming vía SSE.
- **Archivos afectados:** nueva feature `conversation/` (Flutter + backend), `app_router.dart`, `HomeScreen`.
- **Features involucradas:** `conversation/`, `recommendation/` (ya existente, ahora también alimentada por chat).
- **Riesgos:** costos de IA, calidad de extracción de intención, latencia percibida (mitigar con streaming).
- **Dependencias:** Fase 2 y 3 (el motor de recomendación y el perfil deben existir antes de que valga la pena invertir en NLU).
- **Criterio de aceptación:** un usuario puede escribir "estoy triste" y recibir una playlist coherente con explicación, con el chat como pantalla de entrada opcional.

### Fase 5 — Descubrimiento y exploración
- **Objetivo:** modo "sorpréndeme" dedicado con balance exploración/explotación y `explorationScore`.
- **Archivos afectados:** `discovery/` (nueva feature), ajustes en `RecommendationEngineService`.
- **Features involucradas:** `discovery/`, `recommendation/`, `music_profile/`.
- **Riesgos:** UX de "sorpresa" mal calibrada puede sentirse aleatoria o irrelevante.
- **Dependencias:** Fase 3.
- **Criterio de aceptación:** el usuario percibe descubrimientos relevantes, medible por tasa de aceptación de canciones nuevas.

### Fase 6 — Resumen de conversaciones y optimización de costos
- **Objetivo:** implementar `conversation-summary-queue`, caching de intenciones, ajustes de prompt.
- **Archivos afectados:** backend únicamente.
- **Features involucradas:** `conversation/`.
- **Riesgos:** resúmenes de baja calidad pueden degradar coherencia conversacional.
- **Dependencias:** Fase 4, con volumen real de uso para justificar la optimización.
- **Criterio de aceptación:** reducción medible de tokens/costo por conversación sin pérdida perceptible de calidad.

---

## 16. Riesgos técnicos

| Riesgo | Descripción | Mitigación |
|---|---|---|
| **Rendimiento** | Escaneo + clasificación + scoring podrían introducir latencia perceptible. | Cachear perfil y clasificación en Redis; mantener el LLM fuera del camino crítico de selección de canciones; precomputar donde sea posible. |
| **Privacidad** | El perfil musical y las conversaciones son datos sensibles de comportamiento personal. | Minimizar qué se envía al LLM (sección 9.3); cifrar en tránsito (ya hay Dio+interceptor); definir política de retención/borrado de conversaciones. |
| **Escalabilidad de base de datos backend** | `better-sqlite3` puede no soportar la concurrencia de escritura de millones de usuarios generando eventos de feedback constantemente. | Evaluar migración a Postgres para las tablas de alto volumen (`recommendation_feedback`, `conversation_messages`) cuando el uso lo justifique; no es un bloqueante para las fases iniciales. |
| **Costos de IA** | Cada mensaje conversacional tiene un costo real por token. | Chips sin LLM, resumen de conversaciones largas, modelo pequeño para NLU (sección 9.5). |
| **Sincronización** | Outbox local desincronizado del backend puede causar doble conteo o pérdida de feedback. | Idempotencia por `id` de evento; reintentos con backoff (mismo patrón ya usado en `DownloadServiceImpl`). |
| **Migraciones** | Cambios de esquema en `songs`/clasificación podrían romper backfills a mitad de camino. | Migraciones aditivas únicamente (nunca destructivas) y versión (`version`) en `MusicProfile`/`SongClassification` para invalidar caches de forma controlada. |
| **Calidad de clasificación** | Datos heurísticos de baja confianza pueden generar recomendaciones pobres. | Marcar `classificationSource` y ponderar menos las fuentes de baja confianza en el motor (sección 6.4 y 8.3). |
| **Alucinación del LLM** | Un LLM mal diseñado podría "inventar" canciones o artistas inexistentes en el catálogo. | Mitigado estructuralmente: el LLM nunca elige canciones, solo produce intención (sección 1.1, 9.1) — riesgo eliminado por diseño, no por prompt engineering. |

---

## 17. Mejoras futuras

- **IA:** asistente proactivo que sugiere playlists sin que el usuario pregunte (p.ej. al detectar patrón de "los lunes por la mañana escuchas X"), siempre opt-in.
- **Descubrimiento musical:** integración con fuentes de tendencias/novedades externas para ampliar el catálogo más allá de lo ya descargado.
- **Perfil inteligente:** visualización de insights ("tu año en música", evolución de gustos) reutilizando `MusicProfile` histórico si se decide guardar snapshots.
- **Social:** comparar afinidades musicales entre amigos (requeriría nuevas features de social graph, fuera de alcance actual).
- **Playlists colaborativas:** extensión de `playlists/` existente para permitir múltiples usuarios editando, apoyándose en el mismo backend de sync ya usado para favoritos/playlists.
- **Agentes musicales:** un modo donde el usuario delega tareas más complejas ("arma una playlist de 2 horas para un roadtrip que empiece tranquila y termine enérgica") — requeriría que el motor de recomendación soporte "arcos" de energía a lo largo de la playlist, no solo scoring plano.
- **Recomendaciones contextuales avanzadas:** integrar señales de calendario/actividad (siempre con consentimiento explícito) para enriquecer `ListeningContext` más allá de hora del día.

---

*Fin del documento.*
