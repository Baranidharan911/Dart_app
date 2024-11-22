// ignore_for_file: use_build_context_synchronously, avoid_function_literals_in_foreach_calls, prefer_const_constructors, prefer_const_literals_to_create_immutables, library_private_types_in_public_api

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _loading = true;
  String? _selectedPlan;

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error here.
    });
    _initializeSubscription();

    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  Future<void> _initializeSubscription() async {
    // Simulate a delay to fetch the plans (you can replace this with actual product fetching if needed)
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _loading = false;
    });
  }

  void _subscribe(BuildContext context, String plan, Color color) async {
    setState(() {
      _selectedPlan = plan;
    });

    // Save the selected plan in Firestore, SharedPreferences, or wherever needed
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Update user's subscription in Firestore
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'subscription': plan,
      });

      // Save subscription in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription', plan);
      await prefs.setInt('subscriptionColor', color.value);

      // Optionally navigate or update the UI
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$plan selected!'),
      ));

      // Optionally navigate to a different page
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        // Handle successful purchase
      }
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Subscription Plan'),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _animation,
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildSideBox('Premium', isLeft: true),
                    _buildSubscriptionOption(
                      context,
                      'Premium Plan',
                      '₹9999/mo',
                      'premium_plan',
                      Colors.orange,
                      Colors.blueAccent,
                    ),
                    _buildSubscriptionOption(
                      context,
                      'Basic Plan',
                      '₹2999/mo',
                      'basic_plan',
                      Colors.blue,
                      Colors.blueAccent,
                    ),
                    _buildSubscriptionOption(
                      context,
                      'Standard Plan',
                      '₹4999/mo',
                      'standard_plan',
                      Colors.green,
                      Colors.blueAccent,
                    ),
                    _buildSideBox('Standard', isLeft: false),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSubscriptionOption(
    BuildContext context,
    String title,
    String price,
    String plan,
    Color color,
    Color priceBackground,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => _subscribe(context, plan, color),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: screenWidth * 0.8,
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: color,
            width: 2,
          ),
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 10),
              ..._buildFeatureList(screenWidth),
              Spacer(),
              _buildPrice(price, priceBackground, screenWidth),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _subscribe(context, plan, color),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.1,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    'Shop now',
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeatureList(double screenWidth) {
    List<String> features = [
      'Sample Text Here',
      'Other Text Title',
      'Text Space Goes Here',
      'Description Space',
      'Sample Text Here',
      'Text Space Goes Here',
    ];

    return features.map((feature) {
      return Row(
        children: [
          Icon(
            feature.contains('Sample') ? Icons.check_circle : Icons.cancel,
            color: feature.contains('Sample') ? Colors.green : Colors.red,
          ),
          SizedBox(width: 10),
          Text(
            feature,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              color: Colors.black87,
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildPrice(String price, Color priceBackground, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.02,
        horizontal: screenWidth * 0.05,
      ),
      decoration: BoxDecoration(
        color: priceBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        price,
        style: TextStyle(
          fontSize: screenWidth * 0.055,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSideBox(String text, {required bool isLeft}) {
    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: RotatedBox(
        quarterTurns: isLeft ? -1 : 1,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ),
    );
  }
}
