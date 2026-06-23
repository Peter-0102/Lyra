# Mispoti - Development Rules

## Arquitectura

Este proyecto sigue una arquitectura:

- Feature-first
- Clean Architecture
- Separación estricta de capas:
  - domain/
  - data/
  - presentation/

Toda nueva funcionalidad debe respetar esta estructura.

## Gestión de Estado

Usar exclusivamente:

- flutter_riverpod
- StateNotifier
- StateNotifierProvider

No introducir:

- Bloc
- Cubit
- Provider
- GetX
- ValueNotifier para lógica de negocio

Los estados deben ser inmutables y exponer copyWith().

## Inyección de Dependencias

Usar GetIt.

Registrar toda nueva dependencia en:

lib/core/di/injection_container.dart

Ejemplo:

```dart
sl.registerLazySingleton<FavoritesRepository>(
  () => FavoritesRepositoryImpl(),
);