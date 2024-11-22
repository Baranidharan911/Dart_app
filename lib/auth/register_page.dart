// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:techwiz/user_interface/technician_ui_page.dart';
import 'package:twitter_login/twitter_login.dart';
import 'additional_info_page.dart';
import 'login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techwiz/user_interface/b2c_ui_page.dart';
import 'package:techwiz/user_interface/b2b_ui_page.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isObscure = true;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.04),
              Text(
                'Create an account',
                style: TextStyle(
                  fontSize: screenWidth * 0.12,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromRGBO(244, 121, 35, 1),
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _usernameController,
                            hintText: 'Username',
                            icon: Icons.person,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please enter your username'
                                : null,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildTextField(
                            controller: _emailController,
                            hintText: 'Email',
                            icon: Icons.email,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r"^[a-zA-Z0-9+.-]+@[a-zA-Z0-9.-]+$")
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildPasswordField(),
                          SizedBox(height: screenHeight * 0.05),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdditionalInfoPage(
                                        username: _usernameController.text,
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                        isSocialLogin: false,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Next>',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.05,
                                  color: const Color.fromRGBO(0, 43, 135, 1),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.06),
                          const Text(
                            '- OR Continue with -',
                            style: TextStyle(color: Colors.black54, fontSize: 16),
                          ),
                          SizedBox(height: screenHeight * 0.04),
                          _buildSocialLoginButtons(screenWidth),
                          SizedBox(height: screenHeight * 0.04),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const LoginPage()),
                                  );
                                },
                                child: Text(
                                  'I Already Have an Account',
                                  style: TextStyle(
                                      color: Colors.black54, fontSize: screenWidth * 0.04),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
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

  Widget _buildPasswordField() {

    return TextFormField(
      controller: _passwordController,
      obscureText: _isObscure,
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.lock, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey),
          onPressed: () {
            setState(() {
              _isObscure = !_isObscure;
            });
          },
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
        if (value.length < 8) {
          return 'Password must be at least 8 characters long';
        }
        if (!RegExp(r'[A-Z]').hasMatch(value)) {
          return 'Password must contain at least one uppercase letter';
        }
        if (!RegExp(r'[a-z]').hasMatch(value)) {
          return 'Password must contain at least one lowercase letter';
        }
        if (!RegExp(r'[0-9]').hasMatch(value)) {
          return 'Password must contain at least one digit';
        }
        if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
          return 'Password must contain at least one special character';
        }
        return null;
      },
    );
  }

  Widget _buildSocialLoginButtons(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(
          onPressed: _handleGoogleSignIn,
          assetPath: 'assets/google 1.png',
          screenWidth: screenWidth,
        ),
        SizedBox(width: screenWidth * 0.04),
        _buildSocialButton(
          onPressed: _handleTwitterSignIn,
          assetPath: 'assets/twitter 2.png',
          screenWidth: screenWidth,
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required String assetPath,
    required double screenWidth,
  }) {
    return Container(
      width: screenWidth * 0.15,
      height: screenWidth * 0.15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color.fromRGBO(0, 43, 135, 1), width: 1.5),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Image.asset(assetPath, width: screenWidth * 0.08, height: screenWidth * 0.08),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      var currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          String role = userDoc['role'] ?? 'user';
          String type = userDoc['type'] ?? 'user';

          // Redirect based on the role and type
          await _redirectToHomePage(role, type, currentUser.email!);
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
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
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
            await _redirectToHomePage(role, type, currentUser.email!);
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

  void _showError(String? message) {
    Fluttertoast.showToast(
      msg: message ?? "Something went wrong",
      gravity: ToastGravity.CENTER,
    );
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