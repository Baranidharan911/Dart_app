// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TermsAndConditionsPage extends StatefulWidget {
  @override
  _TermsAndConditionsPageState createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  String _termsText = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchTermsAndConditions();
  }

  Future<void> _fetchTermsAndConditions() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Terms_and_condition')
          .doc('I54o9VqBaDtuR07c4mYL')
          .get();
      setState(() {
        _termsText = doc['text'];
      });
    } catch (e) {
      setState(() {
        _termsText =
            'Failed to load terms and conditions. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(0, 43, 135, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            _termsText,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}