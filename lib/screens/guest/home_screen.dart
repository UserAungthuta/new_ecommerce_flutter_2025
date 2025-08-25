// lib/screens/guests/home_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException
import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  // Constants for layout
  static const double _kContentHorizontalPadding =
      20.0; // Padding around main content sections
  static const double _kWrapSpacing = 16.0; // Spacing between cards in Wrap
  static const double _kAppBarHeight = kToolbarHeight; // Standard AppBar height

  // State variables for Recent Reports data
  List<dynamic> bannerData = []; // Initialized as an empty list
  bool _recentBannerLoading = true;

  List<dynamic> categoryData = []; // Initialized as an empty list
  bool _recentCategoryLoading = true;

  List<dynamic> productData = []; // Initialized as an empty list
  bool _recentProductLoading = true;

  // Placeholder for user details (will be fetched)
  User? _currentUser;
  String get userRole => _currentUser?.user_role ?? 'guest';

  // Key for Scaffold to control the Drawer (only used for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // For Banner Slideshow
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchBannerData(); // Fetch quick stats data on init
    _fetchCategoryData();
    _fetchProductData(); // Fetch recent reports on init

    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  // Helper method to show a SnackBar message (can still be used for other alerts)
  void _showSnackBar(
    BuildContext context,
    String message, {
    Color color = Colors.black,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Method to handle user logout
  Future<void> _logout() async {
    await SharedPrefs.clearAll(); // Clear user data and token
    // Navigate back to the login screen, removing all previous routes
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  /// Fetches quick statistics data from the backend API.
  Future<void> _fetchBannerData() async {
    setState(() {
      _recentBannerLoading = true;
    });

    try {
      String url = '${ApiConfig.baseUrl}/banners/readall';

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Request timeout - Server not responding.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          if (mounted) {
            setState(() {
              bannerData = data['data'];
            });
            // Start the slideshow timer only if there's banner data
            if (bannerData.isNotEmpty) {
              _startBannerSlideshow();
            }
          }
        } else if (data['data'] is Map<String, dynamic> &&
            data['data'].containsKey('banners')) {
          if (mounted) {
            setState(() {
              bannerData = data['data']['banners'];
            });
            if (bannerData.isNotEmpty) {
              _startBannerSlideshow();
            }
          }
        } else {
          _showSnackBar(
            context,
            data['message'] ??
                'Failed to load banner data. Invalid data format.',
            color: Colors.red,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to banner data. Server error.',
          color: Colors.red,
        );
      }
    } on SocketException {
      _showSnackBar(
        context,
        'Network error. Check your internet connection.',
        color: Colors.red,
      );
    } on TimeoutException {
      _showSnackBar(
        context,
        'Request timed out. Server not responding.',
        color: Colors.red,
      );
    } on FormatException {
      _showSnackBar(
        context,
        'Invalid response format from server.',
        color: Colors.red,
      );
    } catch (e) {
      _showSnackBar(
        context,
        'An unexpected error occurred: ${e.toString()}',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _recentBannerLoading = false;
        });
      }
    }
  }

  void _startBannerSlideshow() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < bannerData.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      }
    });
  }

  Future<void> _fetchCategoryData() async {
    setState(() {
      _recentCategoryLoading = true;
    });

    try {
      String url = '';
      url = '${ApiConfig.baseUrl}/category/readall';

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Request timeout - Server not responding.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          if (mounted) {
            setState(() {
              categoryData = data['data'];
            });
          }
        } else {
          _showSnackBar(
            context,
            data['message'] ?? 'Failed to load quick stats.',
            color: Colors.red,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to load quick stats. Server error.',
          color: Colors.red,
        );
      }
    } on SocketException {
      _showSnackBar(
        context,
        'Network error. Check your internet connection.',
        color: Colors.red,
      );
    } on TimeoutException {
      _showSnackBar(
        context,
        'Request timed out. Server not responding.',
        color: Colors.red,
      );
    } on FormatException {
      _showSnackBar(
        context,
        'Invalid response format from server.',
        color: Colors.red,
      );
    } catch (e) {
      _showSnackBar(
        context,
        'An unexpected error occurred: ${e.toString()}',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _recentCategoryLoading = false;
        });
      }
    }
  }

  Future<void> _fetchProductData() async {
    setState(() {
      _recentProductLoading = true;
    });

    try {
      String url = '';
      url = '${ApiConfig.baseUrl}/product/readall';

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Request timeout - Server not responding.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          if (mounted) {
            setState(() {
              productData = data['data'];
            });
          }
        } else {
          _showSnackBar(
            context,
            data['message'] ?? 'Failed to load quick stats.',
            color: Colors.red,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to load quick stats. Server error.',
          color: Colors.red,
        );
      }
    } on SocketException {
      _showSnackBar(
        context,
        'Network error. Check your internet connection.',
        color: Colors.red,
      );
    } on TimeoutException {
      _showSnackBar(
        context,
        'Request timed out. Server not responding.',
        color: Colors.red,
      );
    } on FormatException {
      _showSnackBar(
        context,
        'Invalid response format from server.',
        color: Colors.red,
      );
    } catch (e) {
      _showSnackBar(
        context,
        'An unexpected error occurred: ${e.toString()}',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _recentProductLoading = false;
        });
      }
    }
  }

  // Custom AppBar/Header content for large screens
  Widget _buildCustomHeader(bool isLargeScreen) {
    return Container(
      height: _kAppBarHeight, // Standard AppBar height
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey, // Replace with Colors.blue[800] if needed
            width: 1.0, // Adjust width as needed
          ),
        ), // Equivalent to bg-blue-800
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.network(
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                fit: BoxFit.contain,
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if the asset image cannot be loaded
                  return const Icon(Icons.error, size: 50, color: Colors.white);
                },
              ),
            ],
          ),
          // Navigation Links for large screens in Header
          Row(
            children: [
              // Wishlist Icon
              IconButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/wishlist');
                },
                icon: const Icon(
                  Icons.favorite_border,
                  color: Color(0xFF00BF63),
                ),
                tooltip: 'Wishlist',
              ),

              // Cart Icon
              IconButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/cart');
                },
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Color(0xFF00BF63),
                ),
                tooltip: 'Cart',
              ),

              // Login Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/login');
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF00BF63), // Green color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3), // Border radius 3
                  ),
                ),
                child: const Text('Login'),
              ),

              const SizedBox(width: 8),

              // Register Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/register');
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF00BF63), // Green color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3), // Border radius 3
                  ),
                ),
                child: const Text('Register'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 768;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isLargeScreen
          ? null
          : AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
              ),
              title: Image.network(
                '${ApiConfig.baseUrl}/assets/logowtext.png',
                fit: BoxFit.contain,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 50, color: Colors.white);
                },
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF00BF63)),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
      drawer: isLargeScreen
          ? null
          : Drawer(
              child: Container(
                color: const Color(0xFF1E293B),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    DrawerHeader(
                      decoration: const BoxDecoration(color: Color(0xFF00BF63)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.account_circle,
                            color: Colors.white,
                            size: 60,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _currentUser?.fullname ?? 'Guest',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDrawerItem(Icons.shopping_cart, 'Shop Now', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/product');
                    }),
                    _buildDrawerItem(Icons.favorite_border, 'Wishlist', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/wishlist');
                    }),
                    _buildDrawerItem(Icons.shopping_cart_outlined, 'Cart', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/cart');
                    }),
                    SizedBox(height: 20),
                    _buildDrawerItem(Icons.lock, 'Login', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/login');
                    }),
                    _buildDrawerItem(Icons.file_copy, 'Register', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/register');
                    }),
                  ],
                ),
              ),
            ),
      body: Column(
        children: [
          if (isLargeScreen) _buildCustomHeader(isLargeScreen),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full-width Banner Slideshow
                  _recentBannerLoading
                      ? const Center(
                          heightFactor: 4, // Adjust as needed
                          child: CircularProgressIndicator(),
                        )
                      : bannerData.isEmpty
                      ? Container(
                          height: 400,
                          alignment: Alignment.center,
                          color: Colors.grey[200], // Background for no banner
                          child: const Text(
                            'No banners to display.',
                            style: TextStyle(color: Colors.red),
                          ),
                        )
                      : SizedBox(
                          height: 400, // Fixed height for the slideshow
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: bannerData.length,
                                onPageChanged: (int page) {
                                  setState(() {
                                    _currentPage = page;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final banner = bannerData[index];
                                  return Image.network(
                                    '${ApiConfig.baseUrl}/${banner['banner_image']}',
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.image_not_supported,
                                        size: 80,
                                        color: Colors.grey,
                                      );
                                    },
                                  );
                                },
                              ),
                              Positioned(
                                bottom: 10.0,
                                left: 0.0,
                                right: 0.0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(bannerData.length, (
                                    index,
                                  ) {
                                    return Container(
                                      width: 8.0,
                                      height: 8.0,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentPage == index
                                            ? Colors
                                                  .blueAccent // Active indicator color
                                            : Colors.grey.withOpacity(
                                                0.5,
                                              ), // Inactive indicator color
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 20), // Space after banner

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kContentHorizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LOADING
                        if (_recentCategoryLoading)
                          const Center(child: CircularProgressIndicator())
                        // EMPTY STATE
                        else if (categoryData.isEmpty)
                          const Center(
                            child: Text(
                              'No category data available.',
                              style: TextStyle(color: Colors.red),
                            ),
                          )
                        // GRID OF CATEGORIES
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: categoryData.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 12, // 4 columns
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.75,
                                ),
                            itemBuilder: (context, index) {
                              final category = categoryData[index];
                              final imageUrl =
                                  '${ApiConfig.baseUrl}/${category['category_image']}';

                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    '/product_by_category',
                                    arguments: {
                                      'categoryId': category['id'],
                                      'categoryName': category['category_name'],
                                    },
                                  );
                                },
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 3,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(8),
                                              ),
                                          child: Image.network(
                                            imageUrl,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.broken_image,
                                                      size: 40,
                                                    ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          category['category_name'] ??
                                              'No Name',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Product Data Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kContentHorizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Products',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Loading
                        if (_recentProductLoading)
                          const Center(child: CircularProgressIndicator())
                        // No products
                        else if (productData.isEmpty)
                          const Center(
                            child: Text(
                              'No product data available.',
                              style: TextStyle(color: Colors.red),
                            ),
                          )
                        // Grid of products
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: productData.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6, // 4 columns
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.75,
                                ),
                            itemBuilder: (context, index) {
                              final product = productData[index];
                              final imageUrl =
                                  '${ApiConfig.baseUrl}/${product['product_image']}';

                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Product Image
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(8),
                                            ),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.broken_image,
                                                    size: 50,
                                                  ),
                                        ),
                                      ),
                                    ),

                                    // Product Info
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Product Name
                                          Text(
                                            product['product_name'] ??
                                                'No Name',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),

                                          // Price
                                          Text(
                                            product['sale_price'] != null
                                                ? '${double.tryParse(product['sale_price'].toString())?.toStringAsFixed(2) ?? '0.00'} Kyats'
                                                : 'No Price',
                                            style: const TextStyle(
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Action Buttons: View, Add to Cart, Wishlist
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // View Product Button
                                              IconButton(
                                                onPressed: () {
                                                  Navigator.of(
                                                    context,
                                                  ).pushNamed(
                                                    '/product_detail',
                                                    arguments:
                                                        product, // Pass full product data
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.visibility,
                                                  color: Colors.blue,
                                                ),
                                                tooltip: 'View Product',
                                                iconSize: 20,
                                              ),

                                              // Add to Cart
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    // Add to cart logic here
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF00BF63),
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Add to Cart',
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 8),

                                              // Wishlist
                                              IconButton(
                                                onPressed: () {
                                                  // Wishlist logic here
                                                },
                                                icon: const Icon(
                                                  Icons.favorite_border,
                                                  color: Colors.red,
                                                ),
                                                tooltip: 'Add to Wishlist',
                                                iconSize: 20,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for building drawer items (similar to sidebar but separate for clarity)
  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color textColor = Colors.white,
    bool isSubItem = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: isSubItem ? 32.0 : 8.0,
      ), // Indent sub-items
      minLeadingWidth: 0, // Set minimum leading width to 0
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
      tileColor: const Color(0xFF1E293B), // Dark background for drawer items
      selectedTileColor: const Color(0xFF2563EB), // blue-600
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
