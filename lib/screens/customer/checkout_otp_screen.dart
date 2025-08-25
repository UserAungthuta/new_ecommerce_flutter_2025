// lib/screens/profile/checkout_otp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/api_config.dart';
import '../../../utils/shared_prefs.dart';

class CheckoutOtpScreen extends StatefulWidget {
  final int orderId;
  const CheckoutOtpScreen({super.key, required this.orderId});

  @override
  State<CheckoutOtpScreen> createState() => _CheckoutOtpScreenState();
}

class _CheckoutOtpScreenState extends State<CheckoutOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final int _otpLength = 6;
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // Helper method to show a SnackBar message
  void _showSnackBar(String message, {Color color = Colors.black}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Handles the OTP verification process
  Future<void> _verifyOtp() async {
    if (_otpController.text.length != _otpLength) {
      _showSnackBar('Please enter a 6-digit OTP.', color: Colors.orange);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final String? authToken = await SharedPrefs.getToken();
      if (authToken == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/orders/verify-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'order_id': widget.orderId,
              'otp': _otpController.text,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Server not responding.'),
          );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar(
          'Order verification successful! Redirecting...',
          color: Colors.green,
        );
        // Navigate to a success screen or back to order history
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to verify OTP. Please try again.',
          color: Colors.red,
        );
      }
    } on SocketException {
      _showSnackBar(
        'Network error. Check your internet connection.',
        color: Colors.red,
      );
    } on TimeoutException {
      _showSnackBar(
        'Request timed out. Server not responding.',
        color: Colors.red,
      );
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred: ${e.toString()}',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Order'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter the 6-digit OTP sent to your phone number to complete your order.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_otpLength),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Verify OTP Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BF63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
}
