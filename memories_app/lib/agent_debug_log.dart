import 'agent_log_io.dart' if (dart.library.html) 'agent_log_web.dart' as _impl;

Future<void> agentDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
}) =>
    _impl.agentLog(
      hypothesisId: hypothesisId,
      location: location,
      message: message,
      data: data,
    );
