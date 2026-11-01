import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_events.dart';

enum RideSocketState {
  disconnected,
  connecting,
  connected,
  failed,
}

class RideSocketException implements Exception {
  const RideSocketException(
    this.message, {
    this.cause,
  });

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? message
        : '$message Cause: $cause';
  }
}

class WebSocketClient {
  WebSocketClient({
    this.connectionTimeout = const Duration(seconds: 10),
  });

  final Duration connectionTimeout;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _messages =
      StreamController<WebSocketMessage>.broadcast();

  final _errors = StreamController<Object>.broadcast();

  final ValueNotifier<RideSocketState> state =
      ValueNotifier(RideSocketState.disconnected);

  Future<void>? _connectionAttempt;

  bool _disposed = false;
  bool _intentionalDisconnect = false;

  Stream<WebSocketMessage> get messages => _messages.stream;

  Stream<Object> get errors => _errors.stream;

  bool get isConnected => state.value == RideSocketState.connected;

  Future<void> connect(Uri uri) async {
    _ensureNotDisposed();

    if (isConnected) return;

    final existingAttempt = _connectionAttempt;

    if (existingAttempt != null) {
      return existingAttempt;
    }

    _intentionalDisconnect = false;

    final attempt = _connectInternal(uri);
    _connectionAttempt = attempt;

    try {
      await attempt;
    } finally {
      if (identical(_connectionAttempt, attempt)) {
        _connectionAttempt = null;
      }
    }
  }

  Future<void> _connectInternal(Uri uri) async {
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      throw const RideSocketException(
        'WebSocket URL must use ws:// or wss://.',
      );
    }

    state.value = RideSocketState.connecting;

    WebSocketChannel? channel;

    try {
      channel = WebSocketChannel.connect(uri);
      _channel = channel;

      await channel.ready.timeout(connectionTimeout);

      if (_disposed || _intentionalDisconnect) {
        await channel.sink.close();
        return;
      }

      state.value = RideSocketState.connected;

      _subscription = channel.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } on TimeoutException catch (error) {
      await _cleanup(channel);

      state.value = RideSocketState.failed;

      final exception = RideSocketException(
        'WebSocket connection timed out.',
        cause: error,
      );

      _reportError(exception);
      throw exception;
    } catch (error) {
      await _cleanup(channel);

      state.value = RideSocketState.failed;

      final exception = error is RideSocketException
          ? error
          : RideSocketException(
              'Failed to connect to the WebSocket server.',
              cause: error,
            );

      _reportError(exception);
      throw exception;
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;

    try {
      if (raw is! String) {
        throw const FormatException(
          'Expected a text WebSocket message.',
        );
      }

      final message = WebSocketMessage.decode(raw);

      if (message.type == WebSocketEvents.error) {
        _reportError(
          RideSocketException(
            message.message ?? 'WebSocket server error.',
          ),
        );
      }

      if (!_messages.isClosed) {
        _messages.add(message);
      }
    } catch (error) {
      _reportError(error);
    }
  }

  void _onError(Object error, [StackTrace? stackTrace]) {
    if (_disposed || _intentionalDisconnect) return;

    state.value = RideSocketState.failed;

    _reportError(
      RideSocketException(
        'WebSocket stream failed.',
        cause: error,
      ),
    );
  }

  void _onDone() {
    if (_disposed) return;

    state.value = RideSocketState.disconnected;

    if (!_intentionalDisconnect) {
      _reportError(
        const RideSocketException(
          'WebSocket connection closed unexpectedly.',
        ),
      );
    }
  }

  void send(WebSocketMessage message) {
    _ensureNotDisposed();

    if (!isConnected || _channel == null) {
      throw const RideSocketException(
        'Cannot send a message while disconnected.',
      );
    }

    try {
      _channel!.sink.add(message.encode());
    } catch (error) {
      final exception = RideSocketException(
        'Failed to send WebSocket message.',
        cause: error,
      );

      _reportError(exception);
      throw exception;
    }
  }

  Future<void> disconnect() async {
    if (_disposed) return;

    _intentionalDisconnect = true;

    final channel = _channel;
    final subscription = _subscription;

    _channel = null;
    _subscription = null;

    try {
      await subscription?.cancel();
      await channel?.sink.close();
    } catch (error) {
      _reportError(
        RideSocketException(
          'Failed to close WebSocket cleanly.',
          cause: error,
        ),
      );
    } finally {
      state.value = RideSocketState.disconnected;
    }
  }

  Future<void> _cleanup(WebSocketChannel? channel) async {
    if (identical(_channel, channel)) {
      _channel = null;
    }

    try {
      await channel?.sink.close();
    } catch (error) {
      debugPrint('WebSocket cleanup error: $error');
    }
  }

  void _reportError(Object error) {
    if (!_disposed && !_errors.isClosed) {
      _errors.add(error);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const RideSocketException(
        'WebSocket client has already been disposed.',
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;

    await disconnect();

    _disposed = true;

    await _messages.close();
    await _errors.close();

    state.dispose();
  }
}