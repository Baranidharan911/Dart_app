// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController professionController = TextEditingController();
  String email = '';
  String type = '';
  String profileImageUrl = '';

  Future<Map<String, dynamic>?> _fetchUserDetails() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      return userDoc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  void _saveChanges() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'username': nameController.text,
        'phone': phoneController.text,
        'city': cityController.text,
        'profession': professionController.text,
        'profileImageUrl': profileImageUrl,
      });
      setState(() {
        isEditing = false;
      });
    }
  }

  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      var currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        String filePath = 'profile_pictures/${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.${pickedFile.name.split('.').last}';
        await FirebaseStorage.instance.ref().child(filePath).putFile(file);
        String downloadUrl = await FirebaseStorage.instance.ref().child(filePath).getDownloadURL();

        setState(() {
          profileImageUrl = downloadUrl;
        });

        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'profileImageUrl': profileImageUrl,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            var userData = snapshot.data;
            if (!isEditing) {
              nameController.text = userData?['username'] ?? '';
              phoneController.text = userData?['phone'] ?? '';
              cityController.text = userData?['city'] ?? '';
              professionController.text = userData?['profession'] ?? '';
              email = userData?['email'] ?? '';
              type = userData?['type'] ?? '';
              profileImageUrl = userData?['profileImageUrl'] ?? '';
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: profileImageUrl.isNotEmpty
                              ? NetworkImage(profileImageUrl) as ImageProvider<Object>
                              : const AssetImage('assets/profile.jpg') as ImageProvider<Object>,
                        ),
                        if (isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.orange),
                              onPressed: _uploadProfilePicture,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      enabled: isEditing,
                      labelStyle: TextStyle(color: isEditing ? Colors.black : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      border: const OutlineInputBorder(),
                      enabled: isEditing,
                      labelStyle: TextStyle(color: isEditing ? Colors.black : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cityController,
                    decoration: InputDecoration(
                      labelText: 'City',
                      border: const OutlineInputBorder(),
                      enabled: isEditing,
                      labelStyle: TextStyle(color: isEditing ? Colors.black : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: professionController,
                    decoration: InputDecoration(
                      labelText: 'Profession',
                      border: const OutlineInputBorder(),
                      enabled: isEditing,
                      labelStyle: TextStyle(color: isEditing ? Colors.black : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: email),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      enabled: false,
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: type),
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      enabled: false,
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isEditing)
                    ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(0, 43, 135, 1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Text('Save changes', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                ],
              ),
            );
          } else {
            return const Center(child: Text('No user data found.'));
          }
        },
      ),
    );
  }
}
