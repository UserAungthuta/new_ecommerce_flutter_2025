// lib/screens/guests/wishlist_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../utils/api_config.dart';
import '../../utils/shared_prefs.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late Future<List<dynamic>> _wishlistItemsFuture;

  @override
  void initState() {
    super.initState();
    _wishlistItemsFuture = _fetchWishlistItems();
  }

  Future<List<dynamic>> _fetchWishlistItems() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated. Please log in.');
      }

      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/wishlist/readall',
            ), // Assumed API endpoint
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Server not responding.'),
          );

      final data = json.decode(response.body);

      // FIX: Explicitly check if data['success'] is true and data['data'] is a List
      if (response.statusCode == 200) {
        if (data['data'] is List) {
          return data['data'];
        } else if (data['data'] is Map &&
            data['data'].containsKey('wishlists')) {
          return data['data']['wishlists'];
        }
        return [];
      } else {
        throw Exception(
          data['message'] ?? 'Failed to load wishlist. Server error.',
        );
      }
    } on SocketException {
      throw Exception('Network error. Check your internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Server not responding.');
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> _removeFromWishlist(String productId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
          'Please log in to remove items from your wishlist.',
          color: Colors.red,
        );
        return;
      }

      // FIX: Use the new RESTful endpoint with the product ID in the URL
      final response = await http
          .delete(
            Uri.parse(
              '${ApiConfig.baseUrl}/wishlist/delete/$productId',
            ), // Note the change here
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            // Note: The body is no longer needed since the ID is in the URL
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('Product removed from wishlist.', color: Colors.green);
        setState(() {
          _wishlistItemsFuture = _fetchWishlistItems();
        });
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to remove product. Server error.',
          color: Colors.red,
        );
      }
    } on TimeoutException {
      _showSnackBar(
        'Request timed out. Server is not responding.',
        color: Colors.red,
      );
    } on SocketException {
      _showSnackBar(
        'Network error. Check your internet connection.',
        color: Colors.red,
      );
    } on FormatException {
      _showSnackBar('Invalid response format from server.', color: Colors.red);
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  Future<void> _addToCart(String productId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
          'Please log in to add items to your cart.',
          color: Colors.red,
        );
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/cartItems/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'product_id': productId, 'quantity': 1}),
      );

      final data = json.decode(response.body);
      // FIX: Explicitly check if data['success'] is true
      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar('Product added to cart!', color: Colors.green);
        _removeFromWishlist(productId);
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to add product to cart.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}', color: Colors.red);
    }
  }

  void _showSnackBar(String message, {Color color = Colors.black}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        backgroundColor: const Color(0xFF00BF63), // Green color
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _wishlistItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _wishlistItemsFuture = _fetchWishlistItems();
                        });
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    color: Colors.grey,
                    size: 80,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your wishlist is empty.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/home');
                    },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Start Shopping'),
                  ),
                ],
              ),
            );
          } else {
            final wishlistItems = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: wishlistItems.length,
              itemBuilder: (context, index) {
                // FIX: Access product details directly from the 'item' map
                final item = wishlistItems[index];

                // FIX: Use a placeholder image if product_image is null
                final imageUrl = (item['product_image'] != null)
                    ? '${ApiConfig.baseUrl}/${item['product_image']}'
                    : 'https://via.placeholder.com/150';

                // FIX: Handle cases where the item itself might be malformed
                if (item['product_id'] == null) {
                  return const SizedBox.shrink();
                }

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 80),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Product Info and Buttons
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // FIX: Access directly from 'item'
                                item['product_name'] ?? 'No Name',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                // FIX: Access directly from 'item'
                                item['sale_price'] != null
                                    ? '${double.tryParse(item['sale_price'].toString())?.toStringAsFixed(2) ?? '0.00'} Kyats'
                                    : 'No Price',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      // FIX: Use the product_id from the top-level item
                                      onPressed: () => _addToCart(
                                        item['product_id'].toString(),
                                      ),
                                      icon: const Icon(
                                        Icons.shopping_cart,
                                        size: 18,
                                      ),
                                      label: const Text('Add to Cart'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF00BF63,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF00BF63),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    // FIX: Use the product_id from the top-level item
                                    onPressed: () => _removeFromWishlist(
                                      item['product_id'].toString(),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Remove from Wishlist',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
