// lib/screens/admin/web_superadmin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException
import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
// Import the new sidebar widget
import '../../../widgets/sidebar_widget.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // Constants for layout
  static const double _kSidebarWidth = 256.0; // Width of the persistent sidebar
  static const double _kContentHorizontalPadding =
      20.0; // Padding around main content sections
  static const double _kWrapSpacing = 16.0; // Spacing between cards in Wrap
  static const double _kAppBarHeight = kToolbarHeight; // Standard AppBar height

  // State variables for Quick Stats data
  Map<String, dynamic> _quickStatsData = {
    'totalCustomers': 'N/A',
    'totalProducts': 'N/A',
    'total Orders': 'N/A',
    'PendingOrders': 'N/A',
    'totalSaleAmount': 'N/A',
  };
  bool _quickStatsLoading = true;

  // State variables for Recent Reports data
  final List<dynamic> _recentReportsData = []; // Initialized as an empty list
  final bool _recentReportsLoading = true;

  // State variable for Warning Config loading
  final bool _WarningConfigLoading = false;

  // Placeholder for user details (will be fetched)
  User? _currentUser;
  String get userRole => _currentUser?.user_role ?? 'guest';

  // Key for Scaffold to control the Drawer (only used for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar on large screens
  bool _isSidebarOpen = true;
  // Initial state: sidebar is open

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Fetch user data on init
    _fetchQuickStats(); // Fetch quick stats data on init // Fetch recent reports on init
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

  // Fetches current user data from SharedPrefs
  Future<void> _fetchUserData() async {
    final user = await SharedPrefs.getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  /// Fetches quick statistics data from the backend API.
  Future<void> _fetchQuickStats() async {
    setState(() {
      _quickStatsLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
          context,
          'Authentication token missing. Please log in again.',
          color: Colors.red,
        );
        if (mounted) {
          setState(() {
            _quickStatsLoading = false;
          });
        }
        return;
      }

      String url = '';
      url = '${ApiConfig.baseUrl}/quickstats/admin';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
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
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _quickStatsData = data['data'];
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
          _quickStatsLoading = false;
        });
      }
    }
  }

  /// Calculates the appropriate width for each stat card based on screen size.
  double _calculateCardWidth(bool isLargeScreen, double screenWidth) {
    // Calculate available content width:
    // Total screen width
    // MINUS sidebar width (if present and open, i.e., on large screen)
    // MINUS total horizontal padding of the main content column
    double availableWidth = screenWidth;
    if (isLargeScreen && _isSidebarOpen) {
      availableWidth -= _kSidebarWidth;
      availableWidth -= 10.0; // Subtract the 10.0 space
    }
    availableWidth -= (_kContentHorizontalPadding * 2);

    int columns = isLargeScreen ? 4 : 2;
    double totalSpacing = (columns - 1) * _kWrapSpacing;
    // Ensure availableWidth is not negative or zero before division
    if (availableWidth <= 0) return 0;
    return (availableWidth - totalSpacing) / columns;
  }

  // Helper method to build a single statistic card
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    double cardWidth,
  ) {
    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Adjusted padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: const Color(0xFF00BF63), // Adjusted icon size and color
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom AppBar/Header content for large screens
  Widget _buildCustomHeader(bool isLargeScreen) {
    return Container(
      height: _kAppBarHeight, // Standard AppBar height
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 1.0),
        ), // Equivalent to bg-blue-800
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isSidebarOpen
                      ? CupertinoIcons.arrow_left_to_line
                      : CupertinoIcons.arrow_right_to_line,
                  color: const Color(0xFF00BF63),
                  size: 18.0,
                ),
                onPressed: () {
                  setState(() {
                    _isSidebarOpen = !_isSidebarOpen;
                  });
                },
              ),
              const SizedBox(width: 8),
              Image.network(
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                fit: BoxFit.contain,
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if the asset image cannot be loaded
                  return const Icon(
                    Icons.error,
                    size: 50,
                    color: Color(0xFF00BF63),
                  );
                },
              ),
            ],
          ),
          // Navigation Links for large screens in Header
          Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/admin_home');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Dashboard'),
              ),

              // FIX: Removed extra curly braces around PopupMenuButton for conditional inclusion
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/users');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Users'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/admin_product');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Products'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/admin_order');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Orders'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/admin_category');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Category'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/banners');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Banner'),
              ),

              // User Profile/Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'profile',
                          child: Text('Profile'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                  onSelected: (String value) {
                    if (value == 'logout') {
                      _logout();
                    } else if (value == 'profile') {
                      Navigator.of(context).pushNamed('/admin_profile');
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_circle,
                        color: Color(0xFF00BF63),
                        size: 32,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _currentUser?.fullname ?? 'Admin',
                          style: const TextStyle(color: Color(0xFF00BF63)),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF00BF63),
                      ),
                    ],
                  ),
                ),
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
    // userRole is now a getter, so no need to declare it again here
    // String userRole = _currentUser?.role ?? 'guest';
    // Determine if it's a large screen (desktop/tablet) or small (mobile)
    final bool isLargeScreen = screenWidth > 768; // md:breakpoint in Tailwind

    // Calculate card width once for all stat cards
    final double statCardWidth = _calculateCardWidth(
      isLargeScreen,
      screenWidth,
    );

    return Scaffold(
      key: _scaffoldKey, // Assign the Scaffold key for drawer control
      // Conditionally show AppBar only for small screens
      appBar: isLargeScreen
          ? null // No AppBar on large screens
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
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                fit: BoxFit.contain,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if the asset image cannot be loaded
                  return const Icon(
                    Icons.error,
                    size: 50,
                    color: Color(0xFF00BF63),
                  );
                },
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF00BF63)),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
      // Mobile Navigation Drawer (only for small screens)
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
                            _currentUser?.fullname ?? 'Admin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            _currentUser?.email ?? 'admin@example.com',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDrawerItem(Icons.home, 'Dashboard', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/admin_home');
                    }),
                    _buildDrawerItem(Icons.people, 'Users', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/users');
                    }),
                    _buildDrawerItem(Icons.shopping_bag, 'Products', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/admin_product');
                    }),
                    _buildDrawerItem(Icons.receipt, 'Orders', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/admin_order');
                    }),
                    _buildDrawerItem(Icons.category, 'Category', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/admin_category');
                    }),
                    _buildDrawerItem(Icons.image, 'Banner', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/banners');
                    }),
                    const Divider(color: Colors.white54),
                    _buildDrawerItem(Icons.account_circle, 'Profile', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/admin_profile');
                    }),
                    _buildDrawerItem(Icons.logout, 'Logout', () {
                      Navigator.pop(context);
                      _logout();
                    }, textColor: Colors.red),
                  ],
                ),
              ),
            ),
      body: isLargeScreen
          ? Row(
              children: [
                // Persistent Full-Height Sidebar for large screens
                WebSuperAdminSidebar(
                  isOpen: _isSidebarOpen,
                  width: _kSidebarWidth,
                  onDashboardTap: () {
                    Navigator.of(context).pushNamed('/admin_home');
                  },
                  onUsersTap: () {
                    Navigator.of(context).pushNamed('/users');
                  },
                  onProductsTap: () {
                    Navigator.of(context).pushNamed('/admin_product');
                  },
                  onOrdersTap: () {
                    Navigator.of(context).pushNamed('/admin_order');
                  },
                  onCategoryTap: () {
                    Navigator.of(context).pushNamed('/admin_category');
                  },
                  onBannerTap: () {
                    Navigator.of(context).pushNamed('/banner');
                  },
                ),
                // Add a SizedBox for spacing only if the sidebar is open
                if (_isSidebarOpen) const SizedBox(width: 0.0),
                // Main Content Area with Custom Header
                Expanded(
                  child: Column(
                    children: [
                      // Custom Header
                      _buildCustomHeader(isLargeScreen),
                      // Main Scrollable Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Welcome Card
                              Card(
                                margin: const EdgeInsets.all(20.0),
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, ${_currentUser?.fullname ?? 'Admin'}!',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(
                                            255,
                                            13,
                                            13,
                                            14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Here’s an overview of your dashboard.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Quick Stats Section
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _kContentHorizontalPadding,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Analysis Report',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _quickStatsLoading
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _quickStatsData.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'No quick stats data available.',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          )
                                        : Wrap(
                                            spacing: _kWrapSpacing,
                                            runSpacing: _kWrapSpacing,
                                            children: [
                                              _buildStatCard(
                                                'Total Customers',
                                                _quickStatsData['totalCustomers']
                                                    .toString(),
                                                Icons.people_alt,
                                                statCardWidth,
                                              ),
                                              _buildStatCard(
                                                'Total Products',
                                                _quickStatsData['totalProducts']
                                                    .toString(),
                                                Icons.shopping_bag,
                                                statCardWidth,
                                              ),
                                              _buildStatCard(
                                                'Total Orders',
                                                _quickStatsData['totalOrders']
                                                    .toString(),
                                                Icons.receipt,
                                                statCardWidth,
                                              ),
                                              _buildStatCard(
                                                'Pending Orders',
                                                _quickStatsData['pendingOrders']
                                                    .toString(),
                                                Icons.pending_actions,
                                                statCardWidth,
                                              ),
                                              _buildStatCard(
                                                'Total Sale Amount',
                                                _quickStatsData['totalSaleAmount']
                                                    .toString(),
                                                Icons.money,
                                                statCardWidth,
                                              ),
                                            ],
                                          ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Recent Reports Section
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : // Small Screen Layout (existing Scaffold with AppBar and Drawer)
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Welcome Card
                        Card(
                          margin: const EdgeInsets.all(20.0),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${_currentUser?.fullname ?? 'Admin'}!',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 13, 13, 14),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Here’s an overview of your dashboard.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Quick Stats Section
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _kContentHorizontalPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Analysis Reports',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _quickStatsLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : _quickStatsData.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No quick stats data available.',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: _kWrapSpacing,
                                      runSpacing: _kWrapSpacing,
                                      children: [
                                        _buildStatCard(
                                          'Total Customers',
                                          _quickStatsData['totalCustomers']
                                              .toString(),
                                          Icons.people_alt,
                                          statCardWidth,
                                        ),
                                        _buildStatCard(
                                          'Total Products',
                                          _quickStatsData['totalProducts']
                                              .toString(),
                                          Icons.shopping_bag,
                                          statCardWidth,
                                        ),
                                        _buildStatCard(
                                          'Total Orders',
                                          _quickStatsData['totalOrders']
                                              .toString(),
                                          Icons.receipt,
                                          statCardWidth,
                                        ),
                                        _buildStatCard(
                                          'Pending Orders',
                                          _quickStatsData['pendingOrders']
                                              .toString(),
                                          Icons.pending_actions,
                                          statCardWidth,
                                        ),
                                        _buildStatCard(
                                          'Total Sale Amount',
                                          _quickStatsData['totalSaleAmount']
                                              .toString(),
                                          Icons.money,
                                          statCardWidth,
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Recent Reports Section
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

  // Helper method to build a single report item
}
