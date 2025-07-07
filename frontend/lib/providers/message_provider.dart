import 'package:flutter/material.dart';

enum MessageType {
  info,
  warning,
  error,
  success,
}

class MessageData {
  final String message;
  final MessageType type;
  final Duration? duration;
  final String? title;

  MessageData({
    required this.message,
    required this.type,
    this.duration,
    this.title,
  });

  MessageTypeConfig get typeConfig {
    switch (type) {
      case MessageType.info:
        return MessageTypeConfig(
          icon: Icons.info_outline,
          color: Colors.blue,
          backgroundColor: Colors.blue.withOpacity(0.1),
        );
      case MessageType.warning:
        return MessageTypeConfig(
          icon: Icons.warning_amber_outlined,
          color: Colors.orange,
          backgroundColor: Colors.orange.withOpacity(0.1),
        );
      case MessageType.error:
        return MessageTypeConfig(
          icon: Icons.error_outline,
          color: Colors.red,
          backgroundColor: Colors.red.withOpacity(0.1),
        );
      case MessageType.success:
        return MessageTypeConfig(
          icon: Icons.check_circle_outline,
          color: Colors.green,
          backgroundColor: Colors.green.withOpacity(0.1),
        );
    }
  }
}

class MessageTypeConfig {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  MessageTypeConfig({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

class MessageProvider with ChangeNotifier {
  final List<MessageData> _messages = [];
  MessageData? _currentMessage;

  List<MessageData> get messages => List.unmodifiable(_messages);
  MessageData? get currentMessage => _currentMessage;
  bool get hasMessages => _messages.isNotEmpty;
  int get messageCount => _messages.length;

  void showMessage({
    required String message,
    required MessageType type,
    String? title,
    Duration? duration,
  }) {
    final messageData = MessageData(
      message: message,
      type: type,
      title: title,
      duration: duration ?? const Duration(seconds: 4),
    );

    _messages.insert(0, messageData);
    _currentMessage = messageData;
    notifyListeners();

    // Auto-remove message after duration
    if (messageData.duration != null) {
      Future.delayed(messageData.duration!, () {
        dismissMessage(messageData);
      });
    }
  }

  void showInfo(String message, {String? title, Duration? duration}) {
    showMessage(
      message: message,
      type: MessageType.info,
      title: title,
      duration: duration,
    );
  }

  void showWarning(String message, {String? title, Duration? duration}) {
    showMessage(
      message: message,
      type: MessageType.warning,
      title: title,
      duration: duration,
    );
  }

  void showError(String message, {String? title, Duration? duration}) {
    showMessage(
      message: message,
      type: MessageType.error,
      title: title,
      duration: duration ?? const Duration(seconds: 6),
    );
  }

  void showSuccess(String message, {String? title, Duration? duration}) {
    showMessage(
      message: message,
      type: MessageType.success,
      title: title,
      duration: duration,
    );
  }

  void dismissMessage(MessageData message) {
    _messages.remove(message);
    if (_currentMessage == message) {
      _currentMessage = _messages.isNotEmpty ? _messages.first : null;
    }
    notifyListeners();
  }

  void dismissCurrentMessage() {
    if (_currentMessage != null) {
      dismissMessage(_currentMessage!);
    }
  }

  void clearAllMessages() {
    _messages.clear();
    _currentMessage = null;
    notifyListeners();
  }

  void markAsRead(MessageData message) {
    // For future implementation of read/unread status
    notifyListeners();
  }

  void markAllAsRead() {
    // For future implementation of read/unread status
    notifyListeners();
  }
}