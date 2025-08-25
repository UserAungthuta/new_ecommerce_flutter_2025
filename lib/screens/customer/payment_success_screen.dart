// lib/screens/customer/payment_success_screen.dart
import 'package:flutter/material.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final int orderId;
  final double amount;
  final String transactionId;

  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Complete'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
        automaticallyImplyLeading:
            false, // Prevents navigating back with the back button
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Order ID: $orderId',
              style: const TextStyle(fontSize: 20, color: Colors.black54),
            ),
            const SizedBox(height: 5),
            Text(
              'Total Amount: $amount',
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 5),
            Text(
              'Transaction ID: $transactionId',
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Navigate back to the home screen or another desired screen
                // This removes all routes until the first one (usually home)
                Navigator.of(
                  context,
                ).popUntil((route) => route.settings.name == '/customer_home');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BF63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Return to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
