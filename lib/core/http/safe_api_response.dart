import 'package:dio/dio.dart';

class SafeApiResponse {
  final Map<String, dynamic> _data;

  SafeApiResponse._(this._data);

  static SafeApiResponse? from(Response<dynamic> response) {
    if (response.data is! Map<String, dynamic>) return null;
    return SafeApiResponse._(response.data as Map<String, dynamic>);
  }

  String string(String key, {String fallback = ''}) {
    final v = _data[key];
    if (v is String) return v;
    if (v is num) return v.toString();
    return fallback;
  }

  String? stringOrNull(String key) {
    final v = _data[key];
    if (v is String) return v;
    if (v is num) return v.toString();
    return null;
  }

  int integer(String key, {int fallback = 0}) {
    final v = _data[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  int? integerOrNull(String key) {
    final v = _data[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double decimal(String key, {double fallback = 0.0}) {
    final v = _data[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  double? decimalOrNull(String key) {
    final v = _data[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool boolean(String key, {bool fallback = false}) {
    final v = _data[key];
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return fallback;
  }

  bool? booleanOrNull(String key) {
    final v = _data[key];
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }

  Map<String, dynamic> map(String key, {Map<String, dynamic>? fallback}) {
    final v = _data[key];
    if (v is Map<String, dynamic>) return v;
    return fallback ?? const {};
  }

  Map<String, dynamic>? mapOrNull(String key) {
    final v = _data[key];
    if (v is Map<String, dynamic>) return v;
    return null;
  }

  List<dynamic> list(String key, {List<dynamic>? fallback}) {
    final v = _data[key];
    if (v is List<dynamic>) return v;
    return fallback ?? const [];
  }

  List<dynamic>? listOrNull(String key) {
    final v = _data[key];
    if (v is List<dynamic>) return v;
    return null;
  }
}
