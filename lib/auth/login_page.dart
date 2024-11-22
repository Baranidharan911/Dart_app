// ignore_for_file: unused_local_variable, library_private_types_in_public_api, unused_element, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:twitter_login/twitter_login.dart';
import 'package:techwiz/user_interface/b2c_ui_page.dart';
import 'package:techwiz/user_interface/technician_ui_page.dart';
import 'package:techwiz/user_interface/b2b_ui_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techwiz/auth/user_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'register_page.dart';
import 'additional_info_page.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _clearTextFields();
  }

  void _clearTextFields() {
    _usernameController.clear();
    _passwordController.clear();
  }

  Future<void> _setSession(String username, String role, String type, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('username', username);
    await prefs.setString('role', role);
    await prefs.setString('type', type);
    await prefs.setString('userId', userId);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<String?> _getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<String?> _getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<String?> _getType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('type');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.1),
              Text(
                'Welcome',
                style: TextStyle(
                  fontSize: screenWidth * 0.12,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(244, 121, 35, 1),
                ),
              ),
              Text(
                'Back!',
                style: TextStyle(
                  fontSize: screenWidth * 0.12,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(244, 121, 35, 1),
                ),
              ),
              SizedBox(height: screenHeight * 0.05),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.person, color: Colors.grey),
                        fillColor: const Color(0xFFF0F0F0),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email or phone number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.black),
                      obscureText: _isObscure,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscure ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        fillColor: const Color(0xFFF0F0F0),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(0, 43, 135, 1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.3,
                          vertical: screenHeight * 0.02,
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              'Login',
                              style: TextStyle(fontSize: screenWidth * 0.05),
                            ),
                    ),
                    SizedBox(height: screenHeight * 0.06),
                    const Text(
                      '- OR Continue with -',
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: screenWidth * 0.15,
                          height: screenWidth * 0.15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color.fromRGBO(0, 43, 135, 1),
                                width: 1.5),
                          ),
                          child: CircleAvatar(
                            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                            child: IconButton(
                              icon: Image.asset(
                                'assets/google 1.png',
                                width: screenWidth * 0.08,
                                height: screenWidth * 0.08,
                              ),
                              onPressed: _handleGoogleSignIn,
                            ),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Container(
                          width: screenWidth * 0.15,
                          height: screenWidth * 0.15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color.fromRGBO(0, 43, 135, 1),
                                width: 1.5),
                          ),
                          child: CircleAvatar(
                            backgroundColor:
                                const Color.fromARGB(255, 255, 255, 255),
                            child: IconButton(
                              icon: Image.asset(
                                'assets/twitter 2.png',
                                width: screenWidth * 0.08,
                                height: screenWidth * 0.08,
                              ),
                              onPressed: _handleTwitterSignIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    TextButton(
                      onPressed: _handleSignUp,
                      child: Text(
                        'Create An Account',
                        style: TextStyle(color: Colors.black54, fontSize: screenWidth * 0.04),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final String username = _usernameController.text.trim();
        final AuthCredential credential =
            _getCredential(username, _passwordController.text.trim());

        await FirebaseAuth.instance.signInWithCredential(credential);

        // Fetch the user's role and type from Firestore
        var currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (userDoc.exists) {
            String role = userDoc['role'] ?? 'user';
            String type = userDoc['type'] ?? 'user';

            // Store session data
            await _setSession(username, role, type, currentUser.uid);

            // Update FCM Token
            await _updateFcmToken(currentUser.uid);

            // Redirect based on the role and type
            await _redirectToHomePage(role, type, username);
          } else {
            // Handle the case when the user document does not exist
            _showErrorDialog('User document does not exist.');
          }
        }
      } catch (e) {
        print('Login Error: $e');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateFcmToken(String userId) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Delete the existing token to force the generation of a new token
    await messaging.deleteToken();

    // Request a new token
    String? newToken = await messaging.getToken();

    if (newToken != null) {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Use Firestore transaction to safely update the array
      FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception("User document does not exist!");
        }

        List<dynamic> fcmToken = snapshot.get('fcmToken') ?? [];

        // Add new token to the list
        if (!fcmToken.contains(newToken)) {
          fcmToken.add(newToken);
        }

        // Update the user's document
        transaction.update(userRef, {'fcmToken': fcmToken});
      });
    }
  }

  AuthCredential _getCredential(String username, String password) {
    if (RegExp(r'^[a-zA-Z0-9+.-]+@[a-zA-Z0-9.-]+$').hasMatch(username)) {
      return EmailAuthProvider.credential(email: username, password: password);
    } else {
      return PhoneAuthProvider.credential(
          verificationId: username, smsCode: password);
    }
  }

  void _handleForgotPassword() async {
    String emailAddress = _usernameController.text.trim();

    if (emailAddress.isEmpty || !RegExp(r'^[a-zA-Z0-9+.-]+@[a-zA-Z0-9.-]+$').hasMatch(emailAddress)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Email'),
          content: const Text('Please enter a valid email address.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailAddress);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Reset Email Sent'),
          content:
              const Text('Please check your email to reset your password.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Forgot Password Error: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(
              'An error occurred while trying to send the password reset email. Please ensure your email address is correct and try again. Error: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _handleSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isObscure = !_isObscure;
    });
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final user = await UserController.loginWithGoogle();
      var currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          String role = userDoc['role'] ?? 'user';
          String type = userDoc['type'] ?? 'user';

          // Store session data
          await _setSession(currentUser.email!, role, type, currentUser.uid);

          // Redirect based on the role and type
          await _redirectToHomePage(role, type, currentUser.email!);

          // Update FCM Token
          await _updateFcmToken(currentUser.uid);
        } else {
          // If user document does not exist, navigate to AdditionalInfoPage
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AdditionalInfoPage(
                username: currentUser.displayName ?? 'User',
                email: currentUser.email ?? 'No email',
                password: '', // No need to pass password for social login
                isSocialLogin: true,
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (error) {
      print(error.message);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        error.message ?? "Something went wrong",
      )));
    } catch (error) {
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        error.toString(),
      )));
    }
  }

  Future<void> _storeUserData(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      await userDoc.set({
        'email': user.email,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error storing user data: $e');
    }
  }

  Future<void> _handleTwitterSignIn() async {
    try {
      final twitterLogin = TwitterLogin(
        apiKey: 'LYyXdi5AHzuP6hYf228olpkhp', // Replace with your API key
        apiSecretKey:
            'thdMT3HmlDeDBeEEZySrtM5xQddU72vGDz61lChl0v9dsm4Gta', // Replace with your API secret
        redirectURI: 'techwiz://', // Replace with your redirect URI
      );

      final authResult = await twitterLogin.login();

      if (authResult.status == TwitterLoginStatus.loggedIn) {
        final twitterAuthCredential = TwitterAuthProvider.credential(
          accessToken: authResult.authToken!,
          secret: authResult.authTokenSecret!,
        );

        await FirebaseAuth.instance.signInWithCredential(twitterAuthCredential);

        // Fetch the user's role and type from Firestore
        var currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (userDoc.exists) {
            String role = userDoc['role'] ?? 'user';
            String type = userDoc['type'] ?? 'user';

            // Store session data
            await _setSession(currentUser.email!, role, type, currentUser.uid);

            await _redirectToHomePage(role, type, currentUser.email!);

            // Update FCM Token
            await _updateFcmToken(currentUser.uid);
          } else {
            // If user document does not exist, navigate to AdditionalInfoPage
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => AdditionalInfoPage(
                  username: currentUser.displayName ?? 'User',
                  email: currentUser.email ?? 'No email',
                  password: '', // No need to pass password for social login
                  isSocialLogin: true,
                ),
              ),
            );
          }
        }
      } else if (authResult.status == TwitterLoginStatus.cancelledByUser) {
        // Handle cancel
      } else {
        _showErrorDialog(authResult.errorMessage ?? 'Unknown error');
      }
    } catch (e) {
      print('Twitter Sign-In Error: $e');
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _redirectToHomePage(
      String role, String type, String username) async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      if (role == 'technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  TechnicianUIPage(username: currentUser.email!)),
        );
      } else if (type == 'Business to Business') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => B2BUIPage(username: currentUser.email!)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => UIPage(username: currentUser.email!)),
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
