import 'package:signalr_netcore/signalr_client.dart';
import 'package:signalr_netcore/ihub_protocol.dart';

class SignalRService {
  static const String _hubPath = '/gamehub';

  HubConnection? _connection;
  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect(String serverUrl) async {
    _connection = HubConnectionBuilder()
        .withUrl(
          '$serverUrl$_hubPath',
          options: HttpConnectionOptions(
            // The server can take 5–10+ seconds to complete a single hub call
            // when AI chains (multiple 6s / helper pass-throughs) are in flight.
            // 30s is too tight — it caused the client to time out mid-turn and
            // diverge from server state, producing the "hang" symptom.
            requestTimeout: 120000,
            skipNegotiation: false,
            // Leave `transport` unset so the client / server negotiate the
            // best transport automatically: WebSockets is preferred, and the
            // client transparently falls back to Server-Sent Events and then
            // Long Polling if the host/proxy strips the Upgrade header.
            // NOTE: The `signalr_netcore` 1.4.x API does NOT support combining
            // multiple `HttpTransportType` values with `|` — the `transport`
            // field on `HttpConnectionOptions` is a single `Object?` value.
            headers: MessageHeaders()..setHeaderValue('Content-Type', 'application/json'),
          ),
        )
        .withAutomaticReconnect(retryDelays: [1000, 2000, 4000, 8000, 16000])
        .build();

    // Allow the server up to 2 minutes for a single hub invocation.
    // (With the iterative CheckAndAutoPlay refactor this is only a safety
    // net — the typical hub call now completes in < 1s.)
    _connection!.serverTimeoutInMilliseconds = 120000;
    _connection!.keepAliveIntervalInMilliseconds = 15000;

    await _connection!.start();
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _connection = null;
  }

  void on(String method, Function(List<Object?>?) handler) =>
      _connection?.on(method, handler);

  void off(String method) => _connection?.off(method);

  Future<void> invoke(String method, {List<Object>? args}) async {
    if (!isConnected) throw Exception('Not connected to server');
    await _connection!.invoke(method, args: args);
  }
}
