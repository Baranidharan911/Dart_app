// ignore_for_file: prefer_const_constructors, prefer_const_constructors_in_immutables, library_private_types_in_public_api, avoid_print

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techwiz/user_interface/b2c_ui_page.dart';  // Import NotificationPage

class PaymentsGateway extends StatefulWidget {
  final String paymentAmount;
  final String orderId;
  final String userId;

  PaymentsGateway({
    super.key,
    required this.paymentAmount,
    required this.orderId,
    required this.userId,
  });

  @override
  _PaymentsGatewayState createState() => _PaymentsGatewayState();
}

class _PaymentsGatewayState extends State<PaymentsGateway> {
  late Razorpay _razorpay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    print("PaymentsGateway initialized with amount: ${widget.paymentAmount} and orderId: ${widget.orderId}");

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _openCheckout();
  }

  void _openCheckout() {
    try {
      // Parse paymentAmount as double and multiply by 100 to convert to paise
      double amount = double.parse(widget.paymentAmount) * 100;

      var options = {
        'key': 'rzp_live_O5AirT0bLUgu0B',
        'amount': amount.toInt(), // Razorpay expects an integer value in paise
        'name': 'Dial2Tech',
        'description': 'Payment for Order: ${widget.orderId}',
        'prefill': {
          'contact': '97870 85114',
          'email': 'info@protowiz.in',
        },
        'theme': {
          'color': '#3399cc'
        },
        'method': {
          'upi': true,
          'wallet': true,
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      print("Opening Razorpay checkout with options: $options");
      _razorpay.open(options);
    } catch (e) {
      print('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Payment Success: ${response.paymentId}');
    _updatePaymentStatus(response.paymentId, 'success');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/successfull.png'), // Success Image
              Text('Your payment was successful. Payment ID: ${response.paymentId}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/home');
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    // Delay navigation to /home route for 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pop();
    });

    _storePaymentDetails(response.paymentId, 'success');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment Error: ${response.code} - ${response.message}');
    _updatePaymentStatus(response.message, 'failed');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Payment Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/unsucessfull.png'), // Error Image
              Text('Your payment failed. Error: ${response.message}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Retry the payment
                _openCheckout();
              },
              child: Text('Retry'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationPage(),
                  ),
                );
              },
              child: Text('Go to Notifications'),
            ),
          ],
        );
      },
    );

    _storePaymentDetails(response.message, 'failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('External Wallet Selected'),
          content: Text('You have selected ${response.walletName} for payment.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );

    _storePaymentDetails(response.walletName, 'external_wallet');
  }

  void _updatePaymentStatus(String? paymentId, String status) {
    print('Payment status updated: $status for payment ID: $paymentId');
  }

  void _storePaymentDetails(String? id, String status) async {
    try {
      await _firestore
          .collection('payments')
          .add({
            'user_id': widget.userId,  // Store the userId here
            'payment_id': id,
            'enquiry_id': widget.orderId,
            'amount': widget.paymentAmount,
            'status': status,
            'timestamp': FieldValue.serverTimestamp(),
          });
      print("Payment details stored successfully.");
    } catch (e) {
      print("Failed to store payment details: $e");
    }
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway'),
      ),
      body: const Center(
        child: Text('Processing payment...'),
      ),
    );
  }
}
