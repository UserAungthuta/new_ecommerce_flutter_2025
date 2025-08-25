// lib/screens/cart/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/api_config.dart'; // Ensure this path is correct
import '../../../utils/device_utils.dart'; // For ResponsiveBuilder
import '../../../utils/shared_prefs.dart'; // For fetching user token/id

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<dynamic> _cartItems = [];
  bool _isLoading = true;
  String? _authToken; // To store the user's authentication token

  @override
  void initState() {
    super.initState();
    _loadAuthTokenAndFetchCart();
  }

  // Method to load auth token and then fetch cart items
  Future<void> _loadAuthTokenAndFetchCart() async {
    _authToken = await SharedPrefs.getToken();
    if (_authToken == null) {
      _showSnackBar('Please log in to view your cart.', color: Colors.orange);
      setState(() {
        _isLoading = false;
      });
      // Optionally navigate to login page if not logged in
      // Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    _fetchCartItems();
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

  // Shows a full-screen loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF00BF63)),
          ),
        );
      },
    );
  }

  // Hides the full-screen loading dialog
  void _hideLoadingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // Calculates the total price of all items in the cart
  double get _totalPrice {
    double total = 0.0;
    for (var item in _cartItems) {
      // Using 'item_sale_price' and 'number_of_items' as per provided JSON structure
      final price = double.tryParse(item['item_sale_price'].toString()) ?? 0.0;
      final quantity = item['number_of_items'] as int? ?? 0;
      total += price * quantity;
    }
    return total;
  }

  /// Fetches cart items from the backend API.
  Future<void> _fetchCartItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Changed endpoint from /cart/read to /cart/get as per backend routing
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/cart/get'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken', // Pass the auth token
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
            // Access 'items' list nested within 'data' as per provided JSON structure
            if (data['data'] is Map &&
                data['data'].containsKey('items') &&
                data['data']['items'] is List) {
              _cartItems = data['data']['items'];
            } else {
              _cartItems = []; // Default to empty list if unexpected format
              _showSnackBar(
                'Unexpected cart data format from server.',
                color: Colors.red,
              );
            }
          });
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to load cart items. Please try again.',
          color: Colors.red,
        );
      }
    } on SocketException {
      _showSnackBar(
        'Cannot connect to server. Check your internet connection.',
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

  /// Updates the quantity of a specific item in the cart.
  Future<void> _updateCartItemQuantity(int cartItemId, int newQuantity) async {
    if (newQuantity < 1) return; // Prevent quantity from going below 1

    _showLoadingDialog(); // Show loading indicator

    try {
      // Changed HTTP method to PUT and URI to /cartItems/update/{cart_item_id}
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/cartItems/update/$cartItemId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            body: json.encode({
              'number_of_items':
                  newQuantity, // Use 'number_of_items' as per JSON
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - Server not responding');
            },
          );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar('Cart updated successfully!', color: Colors.green);
        // Re-fetch to ensure consistency after successful update
        _fetchCartItems();
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to update cart. Please try again.',
          color: Colors.red,
        );
        // Revert UI if update failed
        _fetchCartItems();
      }
    } on SocketException {
      _showSnackBar(
        'Network error. Check your internet connection.',
        color: Colors.red,
      );
      _fetchCartItems(); // Revert on network error
    } on TimeoutException {
      _showSnackBar(
        'Request timed out. Server is not responding.',
        color: Colors.red,
      );
      _fetchCartItems(); // Revert on timeout
    } on FormatException {
      _showSnackBar('Invalid response from server.', color: Colors.red);
      _fetchCartItems(); // Revert on format error
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred: ${e.toString()}',
        color: Colors.red,
      );
      _fetchCartItems(); // Revert on general error
    } finally {
      _hideLoadingDialog(); // Hide loading indicator
    }
  }

  /// Removes a specific item from the cart.
  Future<void> _removeCartItem(int cartItemId) async {
    // Show confirmation dialog before removing
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Item'),
          content: const Text(
            'Are you sure you want to remove this item from your cart?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return; // If user cancels, do nothing
    }

    _showLoadingDialog(); // Show loading indicator

    try {
      // Changed HTTP method to DELETE and URI to /cartItems/delete/{cart_item_id}
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/cartItems/delete/$cartItemId'),
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
        _showSnackBar('Item removed from cart!', color: Colors.green);
        _fetchCartItems(); // Re-fetch to update UI after successful removal
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to remove item. Please try again.',
          color: Colors.red,
        );
        _fetchCartItems(); // Revert if removal failed
      }
    } on SocketException {
      _showSnackBar(
        'Network error. Check your internet connection.',
        color: Colors.red,
      );
      _fetchCartItems(); // Revert on network error
    } on TimeoutException {
      _showSnackBar(
        'Request timed out. Server is not responding.',
        color: Colors.red,
      );
      _fetchCartItems(); // Revert on timeout
    } on FormatException {
      _showSnackBar('Invalid response from server.', color: Colors.red);
      _fetchCartItems(); // Revert on format error
    } catch (e) {
      _showSnackBar(
        'An unexpected error occurred: ${e.toString()}',
        color: Colors.red,
      );
      _fetchCartItems(); // Revert on general error
    } finally {
      _hideLoadingDialog(); // Hide loading indicator
    }
  }

  /// Clears all items from the cart.
  Future<void> _clearCart() async {
    if (_cartItems.isEmpty) {
      _showSnackBar('Cart is already empty.', color: Colors.orange);
      return;
    }

    // Confirmation dialog for clearing cart
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Cart'),
          content: const Text(
            'Are you sure you want to clear your entire cart?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _showLoadingDialog(); // Show loading indicator

      try {
        // Changed HTTP method to DELETE as per backend routing
        final response = await http
            .delete(
              Uri.parse('${ApiConfig.baseUrl}/cart/clear'),
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
          _showSnackBar('Cart cleared successfully!', color: Colors.green);
          setState(() {
            _cartItems.clear(); // Clear UI after successful backend clear
          });
        } else {
          _showSnackBar(
            data['message'] ?? 'Failed to clear cart. Please try again.',
            color: Colors.red,
          );
          _fetchCartItems(); // Revert if clear failed
        }
      } on SocketException {
        _showSnackBar(
          'Network error. Check your internet connection.',
          color: Colors.red,
        );
        _fetchCartItems(); // Revert on network error
      } on TimeoutException {
        _showSnackBar(
          'Request timed out. Server is not responding.',
          color: Colors.red,
        );
        _fetchCartItems(); // Revert on timeout
      } on FormatException {
        _showSnackBar('Invalid response from server.', color: Colors.red);
        _fetchCartItems(); // Revert on format error
      } catch (e) {
        _showSnackBar(
          'An unexpected error occurred: ${e.toString()}',
          color: Colors.red,
        );
        _fetchCartItems(); // Revert on general error
      } finally {
        _hideLoadingDialog(); // Hide loading indicator
      }
    }
  }

  /// Handles the checkout process.
  Future<void> _checkout() async {
    if (_cartItems.isEmpty) {
      _showSnackBar(
        'Your cart is empty. Please add items before checking out.',
        color: Colors.orange,
      );
      return;
    }

    _showLoadingDialog(); // Show loading indicator

    try {
      // API call to create order from cart
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/orders/create',
            ), // Endpoint for creating order
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            // No body needed if backend creates order from user's current cart
            // You might send a payment method or shipping address if required by your backend
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - Server not responding');
            },
          );

      final data = json.decode(response.body);
      print(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        // 201 Created is common for resource creation
        _showSnackBar('Order placed successfully!', color: Colors.green);
        setState(() {
          _cartItems.clear(); // Clear cart after successful order creation
        });
        // Optionally navigate to an order confirmation page or user's orders list
        // Navigator.pushReplacementNamed(context, '/order_confirmation', arguments: data['order_id']);
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to place order. Please try again.',
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
      _hideLoadingDialog(); // Hide loading indicator
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shopping Cart'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Cart',
            onPressed: _clearCart,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your cart is empty!',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/customer_home',
                      ); // Navigate to products
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
                    child: const Text('Start Shopping'),
                  ),
                ],
              ),
            )
          : ResponsiveBuilder(
              builder: (context, deviceType) {
                bool isLargeScreen =
                    deviceType == DeviceType.desktop ||
                    deviceType == DeviceType.tablet;

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(isLargeScreen ? 20.0 : 10.0),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          final imageUrl =
                              '${ApiConfig.baseUrl}/${item['product_image']}';
                          // Using 'item_sale_price' and 'number_of_items' as per provided JSON structure
                          final itemPrice =
                              double.tryParse(
                                item['item_sale_price'].toString(),
                              ) ??
                              0.0;
                          final itemQuantity =
                              item['number_of_items'] as int? ?? 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 5.0,
                            ),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Product Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: isLargeScreen ? 100 : 80,
                                      height: isLargeScreen ? 100 : 80,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                width: isLargeScreen ? 100 : 80,
                                                height: isLargeScreen
                                                    ? 100
                                                    : 80,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                    ),
                                  ),
                                  SizedBox(width: isLargeScreen ? 20 : 10),
                                  // Product Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['product_name'] ??
                                              'Unknown Product',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLargeScreen ? 18 : 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: isLargeScreen ? 8 : 4),
                                        Text(
                                          'Price: ${itemPrice.toStringAsFixed(2)} Kyats',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: isLargeScreen ? 16 : 14,
                                          ),
                                        ),
                                        SizedBox(height: isLargeScreen ? 8 : 4),
                                        Text(
                                          'Total: ${(itemPrice * itemQuantity).toStringAsFixed(2)} Kyats',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLargeScreen ? 16 : 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: isLargeScreen ? 20 : 10),
                                  // Quantity Controls
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        color: const Color(0xFF00BF63),
                                        onPressed: () =>
                                            _updateCartItemQuantity(
                                              item['cart_item_id'],
                                              itemQuantity - 1,
                                            ),
                                      ),
                                      Text(
                                        '$itemQuantity',
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 18 : 16,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        color: const Color(0xFF00BF63),
                                        onPressed: () =>
                                            _updateCartItemQuantity(
                                              item['cart_item_id'],
                                              itemQuantity + 1,
                                            ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: isLargeScreen ? 10 : 5),
                                  // Remove Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () =>
                                        _removeCartItem(item['cart_item_id']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Cart Summary and Checkout Button
                    Container(
                      padding: EdgeInsets.all(isLargeScreen ? 20.0 : 15.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal:',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 20 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '${_totalPrice.toStringAsFixed(2)} Kyats',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 22 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00BF63),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isLargeScreen ? 20 : 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _checkout,
                              icon: const Icon(Icons.payment),
                              label: const Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BF63),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
