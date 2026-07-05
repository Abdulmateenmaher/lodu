import 'package:logging/logging.dart';
import 'package:signalr_netcore/ihub_protocol.dart';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  static const String _hubPath = '/gamehub';
  static final Logger _log = Logger('SignalRService');

  HubConnection? _connection;
  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect(String serverUrl) async {
    if (_connection != null) {
      final state = _connection!.state;
      if (state == HubConnectionState.Connected ||
          state == HubConnectionState.Connecting ||
          state == HubConnectionState.Reconnecting) {
        return;
      }
    }

    _log.info('Connecting to $serverUrl$_hubPath');
    _connection = HubConnectionBuilder()
        .withUrl(
          '$serverUrl$_hubPath',
          options: HttpConnectionOptions(
            logger: _log,
            transport: HttpTransportType.WebSockets,
            headers: MessageHeaders()..setHeaderValue('Content-Type', 'application/json'),
          ),
        )
        .withAutomaticReconnect(retryDelays: [1000, 2000, 4000, 8000, 16000])
        .configureLogging(_log)
        .build();

    _connection!.serverTimeoutInMilliseconds = 120000;
    _connection!.keepAliveIntervalInMilliseconds = 15000;

    _connection!.onclose(({error}) {
      _log.warning('SignalR connection closed: $error');
    });

    try {
      await _connection!.start();
      _log.info('SignalR connection started successfully');
    } catch (e) {
      final msg = e.toString();
      _log.severe('SignalR start failed: $e');
      _connection = null;
      throw Exception('Cannot connect to server: $msg');
    }
  }

  Future<void> disconnect() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
  }

  void on(String method, Function(List<Object?>?) handler) =>
      _connection?.on(method, handler);

  void off(String method) => _connection?.off(method);

  Future<void> invoke(String method, {List<Object>? args}) async {
    if (!isConnected) throw Exception('Not connected to server');
    try {
      await _connection!.invoke(method, args: args);
    } catch (e) {
      _log.warning('Invoke $method failed: $e');
      rethrow;
    }
  }
}
