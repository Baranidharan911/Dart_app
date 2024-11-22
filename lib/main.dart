// ignore_for_file: avoid_print, library_private_types_in_public_api, prefer_const_constructors

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techwiz/auth/login_page.dart';
import 'package:techwiz/chat/b2b_chat_page.dart';
import 'package:techwiz/home_page.dart';
import 'package:techwiz/rating/rating_page.dart';
import 'package:techwiz/subcription/subscription_page.dart';
import 'package:techwiz/two_way_chat/admin_chat.dart';
import 'package:techwiz/user_interface/b2c_ui_page.dart';
import 'package:techwiz/user_interface/technician_ui_page.dart';
import 'package:techwiz/user_interface/b2b_ui_page.dart' as b2b;
import 'package:techwiz/chat_page/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'package:techwiz/webview/webview_page.dart';
import 'package:techwiz/payments_gateway.dart'; // Import PaymentsGateway


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  NotificationService().handleMessage(message);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Dial2Tech',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LandingPage(),
      routes: {
        '/chat': (context) => const ChatPage(),
        '/B2Bchat': (context) => const B2BChatPage(),
        '/home': (context) => const UIPage(username: 'User'),
        '/login': (context) => const LoginPage(),
        '/technician': (context) => const TechnicianUIPage(username: 'Technician'),
        '/b2b_ui_page': (context) => const b2b.B2BUIPage(username: 'B2B'),
        '/Getstarted': (context) => const HomePage(),
        '/inbox': (context) => const StackPage(userId: 'User'),
        '/webview_ibots': (context) => WebViewPage(url: 'https://ibots.in'),
        '/webview_protowiz': (context) => WebViewPage(url: 'https://protowiz.in'),
        '/subscription': (context) => const SubscriptionPage(),
        '/adminChat': (context) {
          try {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
            print("Received arguments: $args");

            return Admin(
              userId: args['userId']!,
              enquiryId: args['enquiryId']!,
            );
          } catch (e) {
            print("Error parsing route arguments: $e");
            return Scaffold(
              appBar: AppBar(title: Text("Error")),
              body: Center(child: Text("Failed to load the chat page")),
            );
          }
        },
        '/payment': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
          return PaymentsGateway(
            paymentAmount: args['paymentAmount']!,
            orderId: args['orderId']!,
            userId: args['userId']!,
          );
        },
      },
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _role;
  String? _username;
  String? _type;
  final Set<String> _shownEnquiryIds = {};

  @override
  void initState() {
    super.initState();
    _checkSession();
    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    _listenForStatusChanges(); 
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? role = prefs.getString('role');
    String? username = prefs.getString('username');
    String? type = prefs.getString('type');

    setState(() {
      _isLoggedIn = isLoggedIn;
      _role = role;
      _username = username;
      _type = type;
      _isLoading = false;
    });

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false);
      navigatorKey.currentState?.pushReplacementNamed('/Getstarted');
    } else {
      if (_isLoggedIn) {
        await _updateFcmToken();

        if (_role == 'technician') {
          navigatorKey.currentState?.pushReplacementNamed('/technician');
        } else if (_type == 'Business to Business') {
          navigatorKey.currentState?.pushReplacementNamed('/b2b_ui_page');
        } else if (_type == 'Business to Customer') {
          navigatorKey.currentState?.pushReplacementNamed('/home');
        }
      } else {
        navigatorKey.currentState?.pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _updateFcmToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();

    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');

      if (userId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
        });
      }
    }
  }

  Future<void> _onMessage(RemoteMessage message) async {
    NotificationService().handleMessage(message);
  }

  Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    NotificationService().handleMessage(message);
  }

  void _listenForStatusChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('responses')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.modified && doc.doc['status'] == 'completed') {
            print('Status changed to completed for enquiryId: ${doc.doc.id}');
            if (!_shownEnquiryIds.contains(doc.doc.id)) {
              _shownEnquiryIds.add(doc.doc.id);
              _showRatingsPage(doc.doc.id);
            }
          }
        }
      });
    }
  }

  void _showRatingsPage(String enquiryId) {
    showModalBottomSheet(
      context: navigatorKey.currentState!.context,
      isScrollControlled: true,
      builder: (context) {
        return RatingsPage(enquiryId: enquiryId);
      },
    ).then((value) {
      print('Ratings page closed');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator.adaptive()
            : const Text('Redirecting...'),
      ),
    );
  }
}

Stream<int> getUnreadNotificationsCount() {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  } else {
    return Stream.value(0);
  }
}
