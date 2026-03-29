import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Web: POST to debug ingest only (no dart:io).
Future<void> agentLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
}) async {
  // #region agent log
  final line = jsonEncode({
    'sessionId': 'ec7beb',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });
  debugPrint('AGENT_NDJSON:$line');
  try {
    await http
        .post(
          Uri.parse(
            'http://127.0.0.1:7850/ingest/03ca8b9a-6a23-4b4e-844f-14bf16287c96',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': 'ec7beb',
          },
          body: line,
        )
        .timeout(const Duration(seconds: 2));
  } catch (_) {}
  // #endregion
}
