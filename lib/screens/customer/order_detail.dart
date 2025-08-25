// lib/screens/order_detail/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart'; // For fetching the token
import '../../../utils/api_config.dart'; // For API base URL

class OrderDetailScreen extends StatefulWidget {
  final int orderId; // The ID of the order to display

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _orderDetails; // To store the fetched order details
  Map<String, dynamic>? _paymentDetails; // To store the fetched payment details
  bool _isLoading = true;
  bool _isPaymentLoading = false;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  // Fetches the main order details
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
    });

    _authToken = await SharedPrefs.getToken();

    if (_authToken == null) {
      _showSnackBar(
        'Authentication token missing. Please log in.',
        color: Colors.orange,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/orders/read/${widget.orderId}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timeout - Server not responding for order details',
              );
            },
          );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          setState(() {
            _orderDetails = data['data'];
          });
          // After loading order details, check the status and fetch payment info
          if (_orderDetails != null &&
              _orderDetails!['status'] != 'pending' &&
              _orderDetails!['status'] != 'approved') {
            _loadPaymentDetails();
          }
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to load order details. Please try again.',
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
        'Request timed out. Server is not responding.',
        color: Colors.red,
      );
    } on FormatException {
      _showSnackBar('Invalid response from server.', color: Colors.red);
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

  // New function to fetch payment details
  Future<void> _loadPaymentDetails() async {
    setState(() {
      _isPaymentLoading = true;
      _paymentDetails = null; // Clear previous details
    });

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/payment/order/${widget.orderId}'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _paymentDetails = data['data'];
          });
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to load payment details.',
          color: Colors.orange,
        );
      }
    } on TimeoutException {
      _showSnackBar(
        'Payment details request timed out. Please try again.',
        color: Colors.red,
      );
    } catch (e) {
      _showSnackBar(
        'Error fetching payment details: ${e.toString()}',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentLoading = false;
        });
      }
    }
  }

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

  Widget _buildInfoRow(String label, String? value) {
    final displayValue = (value == null || value.isEmpty) ? 'N/A' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey[300], thickness: 1);
  }

  // A new widget to build the payment details section
  Widget _buildPaymentDetailsSection() {
    if (_isPaymentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentDetails == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text(
          'No payment details found for this order.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Payment Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoRow('Payment Type', _paymentDetails!['payment_type']),
        _buildDivider(),
        _buildInfoRow('Payment Status', _paymentDetails!['payment_status']),
        _buildDivider(),
        _buildInfoRow(
          'OTP Verified',
          _paymentDetails!['otp_verified'] == true ? 'Yes' : 'No',
        ),
        _buildDivider(),
        _buildInfoRow(
          'Payment Date',
          _paymentDetails!['created_date']?.split(' ')[0],
        ),
        if (_paymentDetails!['payment_transaction_image'] != null) ...[
          const SizedBox(height: 10),
          const Text(
            'Transaction Image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Image.network(
              '${ApiConfig.baseUrl}/${_paymentDetails!['payment_transaction_image']}',
              width: 250,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 100, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderDetails == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Order details not found or failed to load.',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadOrderDetails, // Retry loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BF63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Information',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(
                        'Order ID',
                        _orderDetails!['order_id']?.toString(),
                      ),
                      _buildDivider(),
                      _buildInfoRow('Status', _orderDetails!['status']),
                      _buildDivider(),
                      _buildInfoRow(
                        'Total Amount',
                        '${double.tryParse(_orderDetails!['total_amount']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00'} Kyats',
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        'Created Date',
                        _orderDetails!['created_date']?.split(' ')[0],
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        'Delivery Address',
                        _orderDetails!['delivery_address'],
                      ),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      const Text(
                        'Items in this Order',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_orderDetails!['items'] != null &&
                          _orderDetails!['items'] is List)
                        ...(_orderDetails!['items'] as List).map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5.0),
                            child: Text(
                              '${item['product_name'] ?? 'N/A'} x ${item['quantity'] ?? 'N/A'} - ${item['price']?.toStringAsFixed(2) ?? '0.00'} Kyats',
                              style: const TextStyle(fontSize: 16),
                            ),
                          );
                        })
                      else
                        const Text('No items found for this order.'),
                      const SizedBox(height: 20),

                      // Conditionally display the "Pay Now" button or payment info
                      if (_orderDetails!['status'] == 'approved')
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              _showSnackBar(
                                'Navigating to payment for Order ID: ${_orderDetails!['order_id']}',
                              );
                              Navigator.pushNamed(
                                context,
                                '/payment_screen',
                                arguments: {
                                  'order_id': _orderDetails!['order_id'],
                                  'amount': _orderDetails!['total_amount'],
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BF63),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Pay Now'),
                          ),
                        ),
                      // Display payment details for other statuses
                      if (_orderDetails!['status'] != 'pending' &&
                          _orderDetails!['status'] != 'approved')
                        _buildPaymentDetailsSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
