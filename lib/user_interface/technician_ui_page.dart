// ignore_for_file: unused_import, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techwiz/auth/login_page.dart';
import 'package:techwiz/technician/profile_page.dart';
import 'package:techwiz/two_way_chat/two_way_chat_page.dart';
import 'package:techwiz/user_interface/b2b_ui_page.dart';
import 'package:techwiz/user_interface/b2c_ui_page.dart';
// Import the ChatService

class TechnicianUIPage extends StatefulWidget {
  final String username;

  const TechnicianUIPage({super.key, required this.username});

  @override
  _TechnicianUIPageState createState() => _TechnicianUIPageState();
}

class _TechnicianUIPageState extends State<TechnicianUIPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Dashboard'),
      ),
      body: Center(
        child: Text('Welcome, ${widget.username}!'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Hi, ${widget.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Assignments'),
              onTap: () {
                // Navigate to assignments page
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat'),
              onTap: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // Navigate to settings page
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}