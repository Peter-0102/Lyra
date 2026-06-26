import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryState {
  final List<HistoryEntry> entries;
  final bool isLoading;
  final String? error;

  const HistoryState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  HistoryState copyWith({
    List<HistoryEntry>? entries,
    bool? isLoading,
    String? error,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final HistoryRepository _repository;

  HistoryNotifier(this._repository) : super(const HistoryState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _repository.getHistory();
      state = HistoryState(entries: entries, isLoading: false);
    } catch (e) {
      state = HistoryState(error: 'Failed to load history: $e', isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final more = await _repository.getHistory(limit: 50, offset: state.entries.length);
      state = HistoryState(
        entries: [...state.entries, ...more],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load more: $e');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _load();
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return sl<HistoryRepository>();
});

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final repository = ref.watch(historyRepositoryProvider);
  return HistoryNotifier(repository);
});
