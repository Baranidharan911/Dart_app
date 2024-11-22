// ignore_for_file: library_prefixes, avoid_print, prefer_interpolation_to_compose_strings, use_build_context_synchronously, prefer_const_constructors, library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/services.dart' as rootBundle;
import 'package:firebase_messaging/firebase_messaging.dart'; // Import Firebase Messaging
import 'package:techwiz/auth/Terms_and_condition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

import 'login_page.dart';

class AdditionalInfoPage extends StatefulWidget {
  final String username;
  final String email;
  final String password;
  final bool isSocialLogin;

  const AdditionalInfoPage({
    super.key,
    required this.username,
    required this.email,
    required this.password,
    required this.isSocialLogin,
  });

  @override
  _AdditionalInfoPageState createState() => _AdditionalInfoPageState();
}

class _AdditionalInfoPageState extends State<AdditionalInfoPage> {
  final _phoneNumberController = TextEditingController();
  final _cityController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _profileController = TextEditingController();
  final _organisationController = TextEditingController();
  final _usernameController = TextEditingController(); // New username field
  final _formKey = GlobalKey<FormState>();
  bool _isCheckboxSelected = false;
  bool _isLoading = false; // Added loading indicator variable

  List<String> businessTypes = ['Business to Business', 'Business to Customer'];
  List<String> profiles = [];
  List<String> cities = [];

  @override
  void initState() {
    super.initState();
    loadCities();
    _usernameController.text = widget.username; // Pre-fill username if provided
  }

  Future<void> loadCities() async {
    final String response =
        await rootBundle.rootBundle.loadString('assets/cities.json');
    final data = await json.decode(response);
    setState(() {
      cities = List<String>.from(data);
    });
  }

  void _updateProfiles(String businessType) {
    setState(() {
      if (businessType == 'Business to Business') {
        profiles = ['Startups', 'MNCs', 'Others'];
      } else if (businessType == 'Business to Customer') {
        profiles = [
          'School Students',
          'Polytechnic Students',
          'Engineering Students',
          'Freelancers',
          'Others'
        ];
      }
      _profileController.clear(); // Clear the profile selection when business type changes
    });
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (!_isCheckboxSelected) {
        Fluttertoast.showToast(
            msg: "Please accept the terms and conditions",
            gravity: ToastGravity.CENTER);
        return;
      }

      setState(() {
        _isLoading = true; // Start loading indicator
      });

      try {
        User? user;
        if (widget.isSocialLogin) {
          user = FirebaseAuth.instance.currentUser;
        } else {
          UserCredential userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );
          user = userCredential.user;
        }

        String profession = _profileController.text;
        String type = _businessTypeController.text;
        String organisation = _organisationController.text;
        String username = _usernameController.text;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .set({
          'username': username,
          'email': widget.email,
          'phone': _phoneNumberController.text,
          'city': _cityController.text,
          'type': type,
          'profile': profession,
          'organisation': organisation,
          'role': 'user',
        });

        // Store session data
        await _setSession(username, 'user', type, user.uid);

        // Fetch and update FCM token
        await _updateFcmToken(user.uid);

        // Send registration email
        await _sendRegistrationEmail(widget.email, user.uid);

        Fluttertoast.showToast(
            msg: "Successfully registered", gravity: ToastGravity.CENTER);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } on FirebaseAuthException catch (e) {
        String message = 'Failed to register. Please try again.';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'The account already exists for that email.';
        }
        Fluttertoast.showToast(msg: message, gravity: ToastGravity.CENTER);
      } catch (e) {
        Fluttertoast.showToast(
            msg: "Error occurred: ${e.toString()}",
            gravity: ToastGravity.CENTER);
      } finally {
        setState(() {
          _isLoading = false; // Stop loading indicator
        });
      }
    }
  }

  Future<void> _setSession(
      String username, String role, String type, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('username', username);
    await prefs.setString('role', role);
    await prefs.setString('type', type);
    await prefs.setString('userId', userId);
  }

  Future<void> _updateFcmToken(String userId) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Delete the existing token to force the generation of a new token
    await messaging.deleteToken();

    // Request a new token
    String? token = await messaging.getToken();

    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }

  Future<void> _sendRegistrationEmail(String email, String userId) async {
    String username = 'techwizapp@gmail.com'; // Your Email
    String password = 'wabd qlet brxw pnod'; // Your App Password

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'Dial2Tech Team')
      ..recipients.add(email)
      ..subject = 'Successful Registration'
      ..text =
          'You are successfully registered in Dial2Tech\n\nUser ID: $userId\n\nThank you,\nDial2Tech Team';

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('Message not sent.');
      print(e.message);
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.03),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Additional information',
                  style: TextStyle(
                    fontSize: screenWidth * 0.11,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(244, 121, 35, 1),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.05),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTextField(
                            controller: _usernameController,
                            hintText: 'Username',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildTextField(
                            controller: _phoneNumberController,
                            hintText: 'Phone Number',
                            icon: Icons.phone,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                                return 'Phone number must be exactly 10 digits';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          TypeAheadFormField(
                            textFieldConfiguration: TextFieldConfiguration(
                              controller: _cityController,
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.04),
                              decoration: InputDecoration(
                                hintText: 'Enter your city',
                                hintStyle: TextStyle(
                                    color: Colors.black54,
                                    fontSize: screenWidth * 0.04),
                                prefixIcon: const Icon(Icons.location_city,
                                    color: Colors.black54),
                                fillColor: const Color(0xFFF0F0F0),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            suggestionsBoxDecoration: SuggestionsBoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              elevation: 4.0,
                              shadowColor: Colors.black45,
                            ),
                            suggestionsCallback: (pattern) {
                              return cities.where((city) => city
                                  .toLowerCase()
                                  .contains(pattern.toLowerCase()));
                            },
                            itemBuilder: (context, String suggestion) {
                              return ListTile(
                                title: Text(suggestion),
                              );
                            },
                            onSuggestionSelected: (String suggestion) {
                              _cityController.text = suggestion;
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your city';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              hintText: 'Select Business Type',
                              hintStyle: TextStyle(
                                  color: Colors.black54,
                                  fontSize: screenWidth * 0.04),
                              prefixIcon: Icon(Icons.business,
                                  color: Colors.black54),
                              fillColor: const Color(0xFFF0F0F0),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            value: _businessTypeController.text.isEmpty
                                ? null
                                : _businessTypeController.text,
                            items: businessTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: screenWidth * 0.04)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _businessTypeController.text = value!;
                                _updateProfiles(value);
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a business type';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              hintText: 'Choose your Profile',
                              hintStyle: TextStyle(
                                  color: Colors.black54,
                                  fontSize: screenWidth * 0.04),
                              prefixIcon: Icon(Icons.person,
                                  color: Colors.black54),
                              fillColor: const Color(0xFFF0F0F0),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            value: _profileController.text.isEmpty
                                ? null
                                : _profileController.text,
                            items: profiles.map((String profile) {
                              return DropdownMenuItem<String>(
                                value: profile,
                                child: Text(profile,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: screenWidth * 0.04)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _profileController.text = value!;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please choose a profile';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          if (_profileController.text == 'School Students' ||
                              _profileController.text ==
                                  'Polytechnic Students' ||
                              _profileController.text ==
                                  'Engineering Students')
                            _buildTextField(
                              controller: _organisationController,
                              hintText: 'Enter the name of the organisation',
                              icon: Icons.business,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the name of the organisation';
                                }
                                return null;
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _isCheckboxSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        _isCheckboxSelected = value ?? false;
                      });
                    },
                  ),
                  Text(
                    "I accept the ",
                    style: TextStyle(
                        fontSize: screenWidth * 0.04, color: Colors.black),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TermsAndConditionsPage(),
                        ),
                      );
                    },
                    child: Text(
                      "terms and conditions",
                      style: TextStyle(
                          fontSize: screenWidth * 0.04, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
              ElevatedButton(
                onPressed:
                    _isLoading ? null : _handleRegister, // Disable button when loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(0, 43, 135, 1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.25,
                    vertical: screenHeight * 0.02,
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Text('Create Account',
                        style: TextStyle(fontSize: screenWidth * 0.05)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return TextFormField(
      controller: controller,
      style: TextStyle(color: Colors.black, fontSize: screenWidth * 0.04),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            TextStyle(color: Colors.black54, fontSize: screenWidth * 0.04),
        prefixIcon: Icon(icon, color: Colors.black54),
        fillColor: const Color(0xFFF0F0F0),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
