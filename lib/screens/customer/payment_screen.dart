// lib/screens/customer/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/api_config.dart';
import '../../../utils/shared_prefs.dart';
import 'payment_success_screen.dart'; // Import the new screen
import 'package:flutter/services.dart';

class PaymentScreen extends StatefulWidget {
  final int orderId;
  final double amount;

  const PaymentScreen({super.key, required this.orderId, required this.amount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _transactionController = TextEditingController();
  final TextEditingController _senderNameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isProcessingPayment = false;
  bool _isLoading = true;
  String? _authToken;
  String? _userId;
  String? _selectedPaymentType;

  @override
  void initState() {
    super.initState();
    _loadUserAndToken();
  }

  @override
  void dispose() {
    _transactionController.dispose();
    _senderNameController.dispose();
    _noteController.dispose();
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

  // Load user token and ID from shared preferences
  Future<void> _loadUserAndToken() async {
    _authToken = await SharedPrefs.getToken();
    _userId = (await SharedPrefs.getUserId())?.toString();
    if (_authToken == null || _userId == null) {
      if (mounted) {
        _showSnackBar(
          'Authentication failed. Please log in again.',
          color: Colors.red,
        );
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handles the payment submission
  Future<void> _processPayment() async {
    if (_selectedPaymentType == null) {
      _showSnackBar('Please select a payment method.', color: Colors.orange);
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessingPayment = true;
      });
    }

    // Build the request body
    Map<String, dynamic> requestBody = {
      'user_id': _userId,
      'order_id': widget.orderId,
      'amount': widget.amount,
      'type': _selectedPaymentType,
      'note': _noteController.text,
    };

    if (_selectedPaymentType == 'COD') {
      // For COD, send a minimal request without other form data
      requestBody.addAll({'transaction_number': '', 'sender_name': ''});
    } else {
      // For other payment types, include form data
      if (_transactionController.text.isEmpty ||
          _senderNameController.text.isEmpty) {
        _showSnackBar(
          'Please fill in all required payment details.',
          color: Colors.orange,
        );
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
          });
        }
        return;
      }
      requestBody.addAll({
        'transaction_number': _transactionController.text,
        'sender_name': _senderNameController.text,
      });
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/payment/create'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timeout - Server not responding');
            },
          );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('Payment successful!', color: Colors.green);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                orderId: widget.orderId,
                amount: widget.amount,
                transactionId: data['data']['payment_id']
                    .toString(), // Assumes the backend returns a payment_id
              ),
            ),
          );
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Payment failed. Please try again.',
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
          _isProcessingPayment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Order ID:', '#${widget.orderId}'),
                  _buildInfoRow(
                    'Amount:',
                    '${widget.amount.toStringAsFixed(2)} MMK',
                    isAmount: true,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Payment Method',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentTypeSelector(),
                  const SizedBox(height: 20),
                  // Conditionally show payment form
                  if (_selectedPaymentType != 'COD' &&
                      _selectedPaymentType != null)
                    _buildPaymentForm(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessingPayment ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BF63),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isProcessingPayment
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Pay Now'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Build the payment form fields
  Widget _buildPaymentForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _transactionController,
          label: 'Transaction Number',
          icon: Icons.receipt_long,
        ),
        _buildTextField(
          controller: _senderNameController,
          label: 'Sender Name',
          icon: Icons.person_outline,
        ),
        _buildTextField(
          controller: _noteController,
          label: 'Note (Optional)',
          icon: Icons.note_alt_outlined,
          isOptional: true,
        ),
      ],
    );
  }

  // Helper method for building text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: isOptional ? 'E.g., for my purchase' : null,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  // Builds the dropdown or list of payment types
  Widget _buildPaymentTypeSelector() {
    final List<String> paymentTypes = [
      'COD',
      'Kpay',
      'Wavepay',
      'Bank Transfer',
    ];
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Payment Type',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      value: _selectedPaymentType,
      items: paymentTypes.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedPaymentType = newValue;
        });
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: isAmount ? const Color(0xFF00BF63) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
