import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Desktop/mobile: POST to debug ingest + append NDJSON to workspace log file.
Future<void> agentLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
}) async {
  // #region agent log
  final payload = <String, Object?>{
    'sessionId': 'ec7beb',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  final line = jsonEncode(payload);
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
  try {
    File(r'c:\Memories\debug-ec7beb.log')
        .writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {}
  // #endregion
}
