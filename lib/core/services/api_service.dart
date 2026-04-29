import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ─── Base URL ────────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://www.sparkmind.in/petsathi/api/v1';

  // ─── Common Headers ──────────────────────────────────────────────────────────
  static Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ─── POST Request ─────────────────────────────────────────────────────────────
  static Future<ApiResponse> post(
      String endpoint,
      Map<String, dynamic> body, {
        String? token,
      }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final stopwatch = Stopwatch()..start();

    _logRequest(
        method: 'POST',
        url: uri.toString(),
        headers: _headers(token: token),
        body: body);

    try {
      final response = await http
          .post(uri, headers: _headers(token: token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();
      _logResponse(
          method: 'POST',
          url: uri.toString(),
          statusCode: response.statusCode,
          body: response.body,
          duration: stopwatch.elapsedMilliseconds);

      return _parseResponse(response);
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
          method: 'POST',
          url: uri.toString(),
          error: e,
          stackTrace: stackTrace,
          duration: stopwatch.elapsedMilliseconds);
      return ApiResponse(
          success: false,
          message: 'Network error: ${e.toString()}',
          data: null,
          statusCode: 0);
    }
  }

  // ─── GET Request ──────────────────────────────────────────────────────────────
  static Future<ApiResponse> get(
      String endpoint, {
        String? token,
        Map<String, String>? queryParams,
      }) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null) uri = uri.replace(queryParameters: queryParams);
    final stopwatch = Stopwatch()..start();

    _logRequest(
        method: 'GET',
        url: uri.toString(),
        headers: _headers(token: token),
        body: queryParams);

    try {
      final response = await http
          .get(uri, headers: _headers(token: token))
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();
      _logResponse(
          method: 'GET',
          url: uri.toString(),
          statusCode: response.statusCode,
          body: response.body,
          duration: stopwatch.elapsedMilliseconds);

      return _parseResponse(response);
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
          method: 'GET',
          url: uri.toString(),
          error: e,
          stackTrace: stackTrace,
          duration: stopwatch.elapsedMilliseconds);
      return ApiResponse(
          success: false,
          message: 'Network error: ${e.toString()}',
          data: null,
          statusCode: 0);
    }
  }

  // ─── POST Multipart (for file uploads like profile_image) ────────────────────
  static Future<ApiResponse> postMultipart(
      String endpoint, {
        required Map<String, String> fields,
        String? token,
        File? imageFile,
        String imageFieldName = 'profile_image',
      }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final stopwatch = Stopwatch()..start();

    // Build auth headers (no Content-Type — multipart sets its own boundary)
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    _logRequest(
        method: 'POST (multipart)',
        url: uri.toString(),
        headers: headers,
        body: {
          ...fields,
          if (imageFile != null) imageFieldName: imageFile.path,
        });

    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers)
        ..fields.addAll(fields);

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(imageFieldName, imageFile.path),
        );
      }

      final streamed =
      await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      stopwatch.stop();
      _logResponse(
          method: 'POST (multipart)',
          url: uri.toString(),
          statusCode: response.statusCode,
          body: response.body,
          duration: stopwatch.elapsedMilliseconds);

      return _parseResponse(response);
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
          method: 'POST (multipart)',
          url: uri.toString(),
          error: e,
          stackTrace: stackTrace,
          duration: stopwatch.elapsedMilliseconds);
      return ApiResponse(
          success: false,
          message: 'Network error: ${e.toString()}',
          data: null,
          statusCode: 0);
    }
  }

  // ─── DELETE Request ───────────────────────────────────────────────────────────
  static Future<ApiResponse> delete(
      String endpoint, {
        String? token,
      }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final stopwatch = Stopwatch()..start();

    _logRequest(
        method: 'DELETE',
        url: uri.toString(),
        headers: _headers(token: token),
        body: null);

    try {
      final response = await http
          .delete(uri, headers: _headers(token: token))
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();
      _logResponse(
          method: 'DELETE',
          url: uri.toString(),
          statusCode: response.statusCode,
          body: response.body,
          duration: stopwatch.elapsedMilliseconds);

      return _parseResponse(response);
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
          method: 'DELETE',
          url: uri.toString(),
          error: e,
          stackTrace: stackTrace,
          duration: stopwatch.elapsedMilliseconds);
      return ApiResponse(
          success: false,
          message: 'Network error: ${e.toString()}',
          data: null,
          statusCode: 0);
    }
  }

  // ─── Parse Response ───────────────────────────────────────────────────────────
  static ApiResponse _parseResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      return ApiResponse(
        success: isSuccess && (decoded['status'] == true || isSuccess),
        message: decoded['message'] as String? ?? '',
        data: decoded,
        statusCode: response.statusCode,
        errors: decoded['errors'] as Map<String, dynamic>?,
      );
    } catch (e) {
      developer.log('PARSE ERROR: $e', name: 'API');
      return ApiResponse(
          success: false,
          message: 'Server error (${response.statusCode})',
          data: null,
          statusCode: response.statusCode);
    }
  }

  // ─── Logger: Request ──────────────────────────────────────────────────────────
  static void _logRequest(
      {required String method,
        required String url,
        required Map<String, String> headers,
        Map<String, dynamic>? body}) {
    if (!kDebugMode) return;
    final buffer = StringBuffer();
    buffer.writeln(
        '\n╔══════════════════════════════════════════════════════╗');
    buffer.writeln('║  🚀  API REQUEST                                      ║');
    buffer.writeln(
        '╠══════════════════════════════════════════════════════╣');
    buffer.writeln('  [$method]  $url');
    buffer
        .writeln('──────────────────────────────────────────────────────');
    buffer.writeln('  HEADERS:');
    headers.forEach((k, v) {
      final displayVal = k == 'Authorization' && v.length > 15
          ? '${v.substring(0, 15)}••••'
          : v;
      buffer.writeln('    $k: $displayVal');
    });
    if (body != null && body.isNotEmpty) {
      buffer.writeln(
          '──────────────────────────────────────────────────────');
      buffer.writeln('  BODY:');
      final safeBody = Map<String, dynamic>.from(body);
      if (safeBody.containsKey('password')) safeBody['password'] = '••••••';
      buffer.writeln(_prettyJson(safeBody));
    }
    buffer.writeln(
        '╚══════════════════════════════════════════════════════╝');
    developer.log(buffer.toString(), name: 'API');
  }

  // ─── Logger: Response ─────────────────────────────────────────────────────────
  static void _logResponse(
      {required String method,
        required String url,
        required int statusCode,
        required String body,
        required int duration}) {
    if (!kDebugMode) return;
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';
    final buffer = StringBuffer();
    buffer.writeln(
        '\n╔══════════════════════════════════════════════════════╗');
    buffer.writeln(
        '║  $icon  API RESPONSE — ${isSuccess ? "SUCCESS" : "ERROR"}');
    buffer.writeln(
        '╠══════════════════════════════════════════════════════╣');
    buffer.writeln('  [$method]  $url');
    buffer.writeln('  Status: $statusCode  |  Time: ${duration}ms');
    buffer.writeln(
        '──────────────────────────────────────────────────────');
    buffer.writeln('  RESPONSE BODY:');
    try {
      buffer.writeln(_prettyJson(jsonDecode(body)));
    } catch (_) {
      buffer.writeln('  $body');
    }
    buffer.writeln(
        '╚══════════════════════════════════════════════════════╝');
    developer.log(buffer.toString(), name: 'API');
  }

  // ─── Logger: Error ────────────────────────────────────────────────────────────
  static void _logError(
      {required String method,
        required String url,
        required Object error,
        required StackTrace stackTrace,
        required int duration}) {
    if (!kDebugMode) return;
    final buffer = StringBuffer();
    buffer.writeln(
        '\n╔══════════════════════════════════════════════════════╗');
    buffer.writeln('║  💥  NETWORK ERROR                                    ║');
    buffer.writeln(
        '╠══════════════════════════════════════════════════════╣');
    buffer.writeln('  [$method]  $url');
    buffer.writeln('  Time: ${duration}ms');
    buffer.writeln(
        '──────────────────────────────────────────────────────');
    buffer.writeln('  ERROR: $error');
    buffer.writeln(
        '╚══════════════════════════════════════════════════════╝');
    developer.log(buffer.toString(),
        name: 'API', error: error, stackTrace: stackTrace);
  }

  // ─── Helper: Pretty JSON ──────────────────────────────────────────────────────
  static String _prettyJson(dynamic json) {
    try {
      const encoder = JsonEncoder.withIndent('    ');
      return encoder.convert(json).split('\n').map((l) => '  $l').join('\n');
    } catch (_) {
      return '  $json';
    }
  }
}

// ─── API Response Model ────────────────────────────────────────────────────────
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final int statusCode;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.statusCode,
    this.errors,
  });

  String? get token => data?['token'] as String?;
  Map<String, dynamic>? get user => data?['user'] as Map<String, dynamic>?;
  int? get userId => data?['user_id'] as int?;
  int? get customerId => data?['customer_id'] as int?;

  /// The raw 'data' payload inside the response (for profile etc.)
  Map<String, dynamic>? get payload => data?['data'] as Map<String, dynamic>?;

  String get errorMessage {
    if (errors != null && errors!.isNotEmpty) {
      final msgs = <String>[];
      errors!.forEach((key, value) {
        if (value is List) {
          msgs.addAll(value.map((e) => e.toString()));
        } else {
          msgs.add(value.toString());
        }
      });
      return msgs.join('\n');
    }
    return message;
  }
}