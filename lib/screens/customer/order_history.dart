// lib/screens/profile/order_history_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';

import '../../../utils/api_config.dart';
import '../../../utils/shared_prefs.dart';
import 'order_detail.dart';
import 'checkout_otp_screen.dart';
import 'payment_password_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadAuthTokenAndFetchOrders();
  }

  // Method to load auth token and then fetch orders
  Future<void> _loadAuthTokenAndFetchOrders() async {
    _authToken = await SharedPrefs.getToken();
    if (_authToken == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar(
          'Please log in to view your order history.',
          color: Colors.orange,
        );
      }
      return;
    }
    _fetchOrders();
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

  // Fetches the user's order history from the backend API
  Future<void> _fetchOrders() async {
    if (_authToken == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/orders/readall'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - Server not responding');
            },
          );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          setState(() {
            _orders = data['data'] is List ? data['data'] : [];
          });
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to load order history.',
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

  String _formatDate(String dateString) {
    try {
      final DateTime dateTime = DateTime.parse(dateString);
      return DateFormat.yMMMd().add_jm().format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 80, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text(
                    'You have no past orders.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/product');
                    },
                    child: const Text('Start Shopping'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final String orderStatus = order['status'] ?? 'Unknown';

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order ID: ${order['order_id'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: orderStatus == 'Completed'
                                    ? Colors.green
                                    : Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                orderStatus,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ${(double.tryParse(order['total_amount'].toString()) ?? 0.0).toStringAsFixed(2)} MMK',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${_formatDate(order['created_date'] ?? '')}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Button to view order details
                        if (order['status'] == 'approved') //
                          Align(
                            //
                            alignment: Alignment.bottomRight, //
                            child: ElevatedButton(
                              //
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PaymentPasswordScreen(
                                      orderId: order['order_id']!,
                                      amount: order['total_amount']!,
                                    ),
                                  ),
                                );
                              }, //
                              style: ElevatedButton.styleFrom(
                                //
                                backgroundColor: //
                                const Color(
                                  0xFF00BF63,
                                ), //
                                foregroundColor: Colors.white, //
                              ), //
                              child: const Text('Pay Now'), //
                            ), //
                          ),
                        if (order['status'] == 'user_verify') //
                          Align(
                            //
                            alignment: Alignment.bottomRight, //
                            child: ElevatedButton(
                              //
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CheckoutOtpScreen(
                                      orderId: order['order_id']!,
                                    ),
                                  ),
                                );
                              }, //
                              style: ElevatedButton.styleFrom(
                                //
                                backgroundColor: //
                                const Color.fromARGB(
                                  255,
                                  248,
                                  228,
                                  8,
                                ), //
                                foregroundColor: Colors.black, //
                              ), //
                              child: const Text('Verfiy Now'), //
                            ), //
                          ), //
                        Align(
                          //
                          alignment: Alignment.bottomRight, //
                          child: TextButton(
                            //
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderDetailScreen(
                                    orderId: order['order_id']!,
                                  ),
                                ),
                              );
                            }, //
                            child: const Text('View Details'), //
                          ), //
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
