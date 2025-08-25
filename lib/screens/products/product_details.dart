// lib/screens/products/product_detail_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/api_config.dart'; // Ensure this path is correct
import '../../../utils/shared_prefs.dart';
import '../../../utils/device_utils.dart'; // For ResponsiveBuilder

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product; // Expecting product data as a map

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _isLoading = false;
  int _quantity = 1; // Default quantity for adding to cart

  @override
  void initState() {
    super.initState();
    // No initial data fetching needed if product is passed via arguments
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

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    setState(() {
      if (_quantity > 1) {
        _quantity--;
      }
    });
  }

  Future<void> _addToCart() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
          'Authentication token missing. Please log in again.',
          color: Colors.red,
        );

        return;
      }
      // Assuming a /cart/add API endpoint
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/cartItems/create'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'product_id':
                  widget.product['id'], // Assuming 'id' is the product ID
              'quantity': _quantity,
              // You might need to add userId or token here if your API requires authentication
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
        _showSnackBar('Product added to cart!', color: Colors.green);
        // Optionally navigate to cart or update cart icon
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to add product to cart. Please try again.',
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imageUrl = '${ApiConfig.baseUrl}/${product['product_image']}';

    return Scaffold(
      appBar: AppBar(
        title: Text(product['product_name'] ?? 'Product Details'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
      ),
      body: ResponsiveBuilder(
        builder: (context, deviceType) {
          bool isLargeScreen =
              deviceType == DeviceType.desktop ||
              deviceType == DeviceType.tablet;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isLargeScreen ? 40.0 : 20.0),
            child: isLargeScreen
                ? _buildLargeScreenLayout(product, imageUrl)
                : _buildSmallScreenLayout(product, imageUrl),
          );
        },
      ),
    );
  }

  Widget _buildLargeScreenLayout(
    Map<String, dynamic> product,
    String imageUrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Image (Left side)
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
        // Product Details (Right side)
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['product_name'] ?? 'Product Name',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product['category_name'] ??
                    'Category', // Assuming category_name is available
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Text(
                product['sale_price'] != null
                    ? '${double.tryParse(product['sale_price'].toString())?.toStringAsFixed(2) ?? '0.00'} Kyats'
                    : 'Price Not Available',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                product['product_description'] ??
                    'No description available for this product.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              _buildQuantitySelector(),
              const SizedBox(height: 20),
              _buildAddToCartButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallScreenLayout(
    Map<String, dynamic> product,
    String imageUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 250,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Product Details
        Text(
          product['product_name'] ?? 'Product Name',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product['category_name'] ?? 'Category',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 15),
        Text(
          product['sale_price'] != null
              ? '${double.tryParse(product['sale_price'].toString())?.toStringAsFixed(2) ?? '0.00'} Kyats'
              : 'Price Not Available',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          product['product_description'] ??
              'No description available for this product.',
          style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
        ),
        const SizedBox(height: 25),
        _buildQuantitySelector(),
        const SizedBox(height: 20),
        _buildAddToCartButton(),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _decrementQuantity,
          icon: const Icon(Icons.remove_circle_outline),
          color: const Color(0xFF00BF63),
          iconSize: 30,
        ),
        Text(
          '$_quantity',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: _incrementQuantity,
          icon: const Icon(Icons.add_circle_outline),
          color: const Color(0xFF00BF63),
          iconSize: 30,
        ),
      ],
    );
  }

  Widget _buildAddToCartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _addToCart,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.shopping_cart),
        label: Text(
          _isLoading ? 'Adding to Cart...' : 'Add to Cart',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BF63),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
        ),
      ),
    );
  }
}
