import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'credential_store.dart';

/// Result wrapper for API responses.
class ApiResult<T> {
  final T? data;
  final String? error;
  final int statusCode;

  ApiResult({this.data, this.error, required this.statusCode});

  bool get isSuccess => error == null && statusCode >= 200 && statusCode < 300;
}

/// Base API service for making HTTP requests.
///
/// Provides common methods for GET, POST, PUT, and DELETE operations.
class ApiService {
  static final http.Client _client = http.Client();

  /// Helper to get headers with Authorization token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await CredentialStore.readToken();

    final headers = Map<String, String>.from(ApiConfig.headers);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Check if the server is healthy/reachable.
  static Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.healthUrl))
          .timeout(ApiConfig.timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Perform a GET request.
  static Future<ApiResult<T>> get<T>(
    String url, {
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic jsonData = json.decode(response.body);
        final T? data = fromJson != null ? fromJson(jsonData) : jsonData as T?;
        return ApiResult(data: data, statusCode: response.statusCode);
      } else {
        final errorBody = _parseError(response.body);
        return ApiResult(error: errorBody, statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResult(error: e.toString(), statusCode: 0);
    }
  }

  /// Perform a POST request.
  static Future<ApiResult<T>> post<T>(
    String url, {
    required Map<String, dynamic> body,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .post(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(ApiConfig.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic jsonData = json.decode(response.body);
        final T? data = fromJson != null ? fromJson(jsonData) : jsonData as T?;
        return ApiResult(data: data, statusCode: response.statusCode);
      } else {
        final errorBody = _parseError(response.body);
        return ApiResult(error: errorBody, statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResult(error: e.toString(), statusCode: 0);
    }
  }

  /// Perform a PUT request.
  static Future<ApiResult<T>> put<T>(
    String url, {
    required Map<String, dynamic> body,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .put(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(ApiConfig.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic jsonData = json.decode(response.body);
        final T? data = fromJson != null ? fromJson(jsonData) : jsonData as T?;
        return ApiResult(data: data, statusCode: response.statusCode);
      } else {
        final errorBody = _parseError(response.body);
        return ApiResult(error: errorBody, statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResult(error: e.toString(), statusCode: 0);
    }
  }

  /// Perform a PATCH request.
  static Future<ApiResult<T>> patch<T>(
    String url, {
    required Map<String, dynamic> body,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .patch(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(ApiConfig.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic jsonData = json.decode(response.body);
        final T? data = fromJson != null ? fromJson(jsonData) : jsonData as T?;
        return ApiResult(data: data, statusCode: response.statusCode);
      } else {
        final errorBody = _parseError(response.body);
        return ApiResult(error: errorBody, statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResult(error: e.toString(), statusCode: 0);
    }
  }

  /// Perform a DELETE request.
  static Future<ApiResult<bool>> delete(String url) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .delete(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult(data: true, statusCode: response.statusCode);
      } else {
        final errorBody = _parseError(response.body);
        return ApiResult(error: errorBody, statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResult(error: e.toString(), statusCode: 0);
    }
  }

  /// Parse error message from response body.
  static String _parseError(String body) {
    try {
      final jsonData = json.decode(body);
      return jsonData['error']?.toString() ?? 'Unknown error';
    } catch (e) {
      return body.isNotEmpty ? body : 'Unknown error';
    }
  }
}
