import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SseEvent {
  final String event;
  final String data;

  const SseEvent({required this.event, required this.data});
}

class SseClient {
  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _closed = false;

  Stream<SseEvent> connect(
    String url, {
    Map<String, String>? headers,
  }) async* {
    _client = http.Client();
    _closed = false;

    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      if (headers != null) {
        request.headers.addAll(headers);
      }

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('SSE connection failed: ${response.statusCode}');
      }

      String buffer = '';
      String? currentEvent;

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (_closed) break;

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (final line in lines.take(lines.length - 1)) {
          if (line.startsWith('event: ')) {
            currentEvent = line.substring(7);
          } else if (line.startsWith('data: ')) {
            yield SseEvent(
              event: currentEvent ?? 'message',
              data: line.substring(6),
            );
            currentEvent = null;
          } else if (line.isEmpty) {
            currentEvent = null;
          }
        }
      }
    } finally {
      _client?.close();
      _client = null;
    }
  }

  void close() {
    _closed = true;
    _subscription?.cancel();
    _client?.close();
    _client = null;
  }
}
