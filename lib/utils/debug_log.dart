import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;

/// Debug session logging for agent debugging. POSTs to ingest endpoint;
/// also prints to console when kDebugMode so "flutter run" captures evidence.
// #region agent log
void debugAgentLog({
  required String location,
  required String message,
  Map<String, dynamic>? data,
  String? hypothesisId,
  String? runId,
}) {
  final payload = <String, dynamic>{
    'sessionId': '9411f0',
    'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    if (data != null) 'data': data,
    if (hypothesisId != null) 'hypothesisId': hypothesisId,
    if (runId != null) 'runId': runId,
  };
  if (kDebugMode) {
    debugPrint('[DEBUG_9411f0] ${jsonEncode(payload)}');
  }
  try {
    http.post(
      Uri.parse('http://127.0.0.1:7373/ingest/f7ee33c0-e8eb-4a38-ae71-560f82ada79c'),
      headers: {'Content-Type': 'application/json', 'X-Debug-Session-Id': '9411f0'},
      body: jsonEncode(payload),
    ).catchError((_) => http.Response('', 0));
  } catch (_) {}
}
// #endregion
