// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingsPage extends StatefulWidget {
  final String enquiryId;

  const RatingsPage({Key? key, required this.enquiryId}) : super(key: key);

  @override
  _RatingsPageState createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 300),
      curve: Curves.decelerate,
      child: Container(
        height: screenHeight * 0.5, // Increased height to accommodate feedback text box
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.black, size: screenWidth * 0.06),
                onPressed: () {
                  _closeRating(context);
                },
              ),
            ),
            Text(
              'Rate the service for the enquiry id: ${widget.enquiryId}',
              style: TextStyle(fontSize: screenWidth * 0.06, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.03),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _selectedRating ? Icons.star : Icons.star_border,
                    size: screenWidth * 0.1,
                    color: index < _selectedRating ? Color.fromRGBO(244, 121, 35, 0.9) : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedRating = index + 1;
                    });
                  },
                );
              }),
            ),
            SizedBox(height: screenHeight * 0.03),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter your feedback',
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton(
              onPressed: () {
                _submitRating(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(0, 43, 135, 1), // Background color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.015),
              ),
              child: Text(
                'Submit',
                style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.045),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitRating(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ratingData = {
        'userId': user.uid,
        'enquiryId': widget.enquiryId,
        'rating': _selectedRating,
        'feedback': _feedbackController.text,
        'status': _selectedRating > 0 ? 'answered' : 'not answered',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('ratings').add(ratingData);

      // Update the status of the enquiry to reflect that the rating has been answered or not answered
      await FirebaseFirestore.instance.collection('responses').doc(widget.enquiryId).update({
        'ratingStatus': _selectedRating > 0 ? 'answered' : 'not answered',
      });

      // Pop the bottom sheet
      Navigator.pop(context);
    }
  }

  void _closeRating(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Update the status of the enquiry to reflect that the rating has not been answered
      await FirebaseFirestore.instance.collection('responses').doc(widget.enquiryId).update({
        'ratingStatus': 'not answered',
      });

      // Pop the bottom sheet
      Navigator.pop(context);
    }
  }
}