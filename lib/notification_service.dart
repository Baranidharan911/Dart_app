import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'main.dart'; // Import the navigator key

class NotificationService {
  // Private constructor
  NotificationService._privateConstructor();

  // Singleton instance
  static final NotificationService _instance = NotificationService._privateConstructor();

  // Factory constructor
  factory NotificationService() {
    return _instance;
  }

  // Method to handle messages
  void handleMessage(RemoteMessage message) {
    final context = navigatorKey.currentState?.overlay?.context;

    if (context != null) {
      if (message.data['route'] != null) {
        Navigator.pushNamed(context, message.data['route']);
      } else if (message.notification != null) {
        // Show a dialog or any other UI element to display notification details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(message.notification!.title ?? 'Notification'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.notification!.body != null)
                  Text(message.notification!.body!),
                if (message.data['image'] != null)
                  Image.network(message.data['image']),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}