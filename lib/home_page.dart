import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the screen size
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: screenHeight * 0.1,
              left: screenWidth * 0.05,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Image.asset(
                'assets/getStartedLogo.jpg',
                width: screenWidth * 0.25,
                height: screenHeight * 0.1,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
              child: Center(
                child: Image.asset(
                  'assets/bg1.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: screenHeight * 0.05),
            child: Column(
              children: [
                Text(
                  'Find the Right',
                  style: TextStyle(
                    color: const Color.fromRGBO(244, 121, 35, 0.9),
                    fontSize: screenWidth * 0.1,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Montserrat',
                  ),
                ),
                Text(
                  'Technical Engineer',
                  style: TextStyle(
                    color: const Color.fromRGBO(244, 121, 35, 0.9),
                    fontSize: screenWidth * 0.1,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Montserrat',
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  'Anytime, Everytime.',
                  style: TextStyle(
                    color: const Color.fromARGB(241, 0, 0, 0),
                    fontSize: screenWidth * 0.07,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: screenHeight * 0.07),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login'); // Navigate to the LoginPage
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(0, 43, 135, 1),
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.02,
                  horizontal: screenWidth * 0.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Get Started',
                style: TextStyle(
                  color: const Color.fromRGBO(255, 255, 255, 1),
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}