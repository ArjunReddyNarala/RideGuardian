import 'dart:convert';

class WebSocketEvents {
  WebSocketEvents._();

  static const String connected = 'CONNECTED';
  static const String locationUpdate = 'LOCATION_UPDATE';
  static const String rideEnded = 'RIDE_ENDED';
  static const String error = 'ERROR';
  static const String ping = 'PING';
  static const String pong = 'PONG';
  static const String locationReceived = 'LOCATION_RECEIVED';
  static const String speedLimitExceeded =
    'SPEED_LIMIT_EXCEEDED';
}

class WebSocketMessage {
  const WebSocketMessage({
    required this.type,
    this.data,
    this.message,
  });

  final String type;
  final Map<String, dynamic>? data;
  final String? message;

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'];

    if (type is! String || type.trim().isEmpty) {
      throw const FormatException(
        'WebSocket message has no valid event type.',
      );
    }

    final rawData = json['data'];

    if (rawData != null && rawData is! Map) {
      throw const FormatException(
        'WebSocket message data must be an object.',
      );
    }

    final rawMessage = json['message'];

    if (rawMessage != null && rawMessage is! String) {
      throw const FormatException(
        'WebSocket error message must be a string.',
      );
    }

    return WebSocketMessage(
      type: type,
      data: rawData == null
          ? null
          : Map<String, dynamic>.from(rawData),
      message: rawMessage as String?,
    );
  }

  factory WebSocketMessage.decode(String raw) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException(
        'Received malformed JSON from the WebSocket server.',
      );
    }

    if (decoded is! Map) {
      throw const FormatException(
        'Expected a JSON object from the WebSocket server.',
      );
    }

    return WebSocketMessage.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (data != null) 'data': data,
    if (message != null) 'message': message,
  };

  String encode() => jsonEncode(toJson());
}