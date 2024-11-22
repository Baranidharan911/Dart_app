import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:techwiz/user_interface/b2c_ui_page.dart';

class SuccessPage extends StatelessWidget {
  final String selectedOption;

  const SuccessPage({super.key, required this.selectedOption});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/celebration.json', // Path to your Lottie file
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/check_animation.json', // Path to your Lottie file
                  width: screenWidth * 0.5,
                  height: screenWidth * 0.5,
                  fit: BoxFit.fill,
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Form successfully submitted for $selectedOption',
                  style: TextStyle(
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.1),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UIPage(username: 'User'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(0, 43, 135, 1), // Background color
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          'Return to Homepage',
                          style: TextStyle(fontSize: screenWidth * 0.045, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
