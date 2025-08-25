import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
// Note: This example assumes a sidebar widget exists, but for simplicity,
// the full sidebar from products_screen.dart is not included here.
// You can integrate it as needed.

// Enum to manage the current view state of the screen
enum BannerView { list, create, edit }

class WebBannersScreen extends StatefulWidget {
  const WebBannersScreen({super.key});

  @override
  State<WebBannersScreen> createState() => _WebBannersScreenState();
}

class _WebBannersScreenState extends State<WebBannersScreen> {
  static const double _kSidebarWidth = 256.0;
  static const double _kAppBarHeight = kToolbarHeight;

  BannerView _currentView = BannerView.list;
  int? _editingBannerId;
  final List<Map<String, dynamic>> _banners = [];
  bool _bannersLoading = true;

  // Key for Scaffold to control the Drawer (for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar
  bool _isSidebarOpen = true;

  // Placeholder for user details
  String? _currentUserRole;

  // Text controllers for the banner form (not needed for this specific API, but kept for consistency)
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchBanners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Helper method to show snackbars
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

  // Helper method to handle user logout
  Future<void> _logout() async {
    await SharedPrefs.clearAll();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  // Fetches user role from shared preferences
  Future<void> _fetchUserData() async {
    final user = await SharedPrefs.getUser();
    if (mounted) {
      setState(() {
        _currentUserRole = user?.user_role;
      });
    }
  }

  // Fetches all banners from the API
  Future<void> _fetchBanners() async {
    setState(() {
      _bannersLoading = true;
      _banners.clear();
    });
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/banners/readall'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          if (mounted) {
            setState(() {
              _banners.addAll(
                List<Map<String, dynamic>>.from(data['data']).cast(),
              );
            });
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ?? 'Failed to load banners.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error fetching banners: ${e.toString()}',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _bannersLoading = false;
        });
      }
    }
  }

  // Handles image selection from file picker
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  // Creates a new banner via API
  Future<void> _createBanner() async {
    if (_pickedFile == null) {
      _showSnackBar(
        context,
        'Please upload a banner image.',
        color: Colors.orange,
      );
      return;
    }

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      var uri = Uri.parse('${ApiConfig.baseUrl}/banners/create');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Authorization': 'Bearer $token'});

      if (_pickedFile != null && _pickedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'banner_image',
            _pickedFile!.bytes!,
            filename: _pickedFile!.name,
            contentType: MediaType(
              'image',
              path.extension(_pickedFile!.name).substring(1),
            ),
          ),
        );
      }

      var response = await request.send();

      if (response.statusCode == 201) {
        _showSnackBar(
          context,
          'Banner created successfully!',
          color: Colors.green,
        );
        _fetchBanners();
        setState(() {
          _resetForm();
          _currentView = BannerView.list;
        });
      } else {
        var responseBody = await response.stream.bytesToString();
        final errorData = json.decode(responseBody);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to create banner.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error creating banner: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  // Updates an existing banner via API
  Future<void> _updateBanner() async {
    if (_pickedFile == null || _editingBannerId == null) {
      _showSnackBar(
        context,
        'Please select a new image to update.',
        color: Colors.orange,
      );
      return;
    }

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      var uri = Uri.parse(
        '${ApiConfig.baseUrl}/banners/update/$_editingBannerId',
      );
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Authorization': 'Bearer $token'});

      if (_pickedFile != null && _pickedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'banner_image',
            _pickedFile!.bytes!,
            filename: _pickedFile!.name,
            contentType: MediaType(
              'image',
              path.extension(_pickedFile!.name).substring(1),
            ),
          ),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'Banner updated successfully!',
          color: Colors.green,
        );
        _fetchBanners();
        setState(() {
          _resetForm();
          _currentView = BannerView.list;
        });
      } else {
        var responseBody = await response.stream.bytesToString();
        final errorData = json.decode(responseBody);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to update banner.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error updating banner: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  // Deletes a banner via API
  Future<void> _deleteBanner(int bannerId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/banners/delete/$bannerId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'Banner deleted successfully!',
          color: Colors.green,
        );
        _fetchBanners();
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ?? 'Failed to delete banner.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error deleting banner: ${e.toString()}',
          color: Colors.red,
        );
      }
    }
  }

  // Resets the form to its initial state
  void _resetForm() {
    _editingBannerId = null;
    _pickedFile = null;
  }

  // Populates the form with data from a selected banner
  void _populateFormWithBanner(Map<String, dynamic> banner) {
    _editingBannerId = banner['id'];
    _pickedFile = null; // Clear the picked file
  }

  // Action handler for editing a banner
  void _handleEditBanner(Map<String, dynamic> banner) {
    _populateFormWithBanner(banner);
    setState(() {
      _currentView = BannerView.edit;
    });
  }

  // Action handler for deleting a banner
  void _handleDeleteBanner(int bannerId) {
    _showConfirmationDialog(
      context,
      title: 'Delete Banner',
      content: 'Are you sure you want to delete this banner?',
      onConfirm: () async {
        await _deleteBanner(bannerId);
      },
    );
  }

  // Submits the form (create or update)
  void _submitForm() async {
    if (_editingBannerId == null) {
      await _createBanner();
    } else {
      await _updateBanner();
    }
  }

  // Builds the table view for banners
  Widget _buildBannerTable() {
    if (_bannersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_banners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No banners found.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {
                _resetForm();
                _currentView = BannerView.create;
              }),
              child: const Text("Create Banner"),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _resetForm();
                      _currentView = BannerView.create;
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text("Create Banner"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Banner Image')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _banners.map((banner) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Image.network(
                              '${ApiConfig.baseUrl}/${banner['banner_image']}' ??
                                  'https://via.placeholder.com/150',
                              width: 200,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit Banner',
                                  onPressed: () => _handleEditBanner(banner),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete Banner',
                                  onPressed: () =>
                                      _handleDeleteBanner(banner['id']!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the form view for creating or editing banners
  Widget _buildForm() {
    final formTitle = _currentView == BannerView.create
        ? 'Create New Banner'
        : 'Edit Banner';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Select Banner Image'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _pickedFile?.name ?? 'No file selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: Text(
                      _editingBannerId == null
                          ? 'Create Banner'
                          : 'Update Banner',
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _resetForm();
                        _currentView = BannerView.list;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds a confirmation dialog box
  Future<void> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(children: <Widget>[Text(content)]),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Builds the custom header for large screens
  Widget _buildCustomHeader(bool isLargeScreen) {
    return Container(
      height: _kAppBarHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey, width: 1.0)),
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
                '${ApiConfig.baseUrl}/assets/logo.png',
                fit: BoxFit.contain,
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.error,
                    size: 50,
                    color: Color(0xFF00BF63),
                  );
                },
              ),
            ],
          ),
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
                  foregroundColor: Colors.blue, // Highlight current screen
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Banner'),
              ),
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
                          _currentUserRole ?? 'Admin',
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

  // Builds the drawer for small screens
  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color textColor = Colors.white,
    bool isSubItem = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: isSubItem ? 32.0 : 8.0),
      minLeadingWidth: 0,
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
      tileColor: const Color(0xFF1E293B),
      selectedTileColor: const Color(0xFF2563EB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                '${ApiConfig.baseUrl}/assets/logo.png',
                fit: BoxFit.contain,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
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
                            _currentUserRole ?? 'Admin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
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
                    _buildDrawerItem(Icons.photo, 'Banner', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/banners');
                    }),
                    const Divider(color: Colors.white54),
                    _buildDrawerItem(
                      Icons.logout,
                      'Logout',
                      _logout,
                      textColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
      body: Row(
        children: [
          if (isLargeScreen) ...[
            // The WebSuperAdminSidebar widget from the original code
            // is not available. For this example, we'll use a simplified
            // navigation list similar to the mobile drawer.
            SizedBox(
              width: _kSidebarWidth,
              child: Container(
                color: const Color(0xFF1E293B),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.network(
                        '${ApiConfig.baseUrl}/assets/logo.png',
                        fit: BoxFit.contain,
                        height: 50,
                      ),
                    ),
                    const Divider(color: Colors.white),
                    _buildDrawerItem(
                      Icons.home,
                      'Dashboard',
                      () => Navigator.of(context).pushNamed('/admin_home'),
                    ),
                    _buildDrawerItem(
                      Icons.people,
                      'Users',
                      () => Navigator.of(context).pushNamed('/users'),
                    ),
                    _buildDrawerItem(
                      Icons.shopping_bag,
                      'Products',
                      () => Navigator.of(context).pushNamed('/admin_product'),
                    ),
                    _buildDrawerItem(
                      Icons.receipt,
                      'Orders',
                      () => Navigator.of(context).pushNamed('/admin_order'),
                    ),
                    _buildDrawerItem(
                      Icons.category,
                      'Category',
                      () => Navigator.of(context).pushNamed('/admin_category'),
                    ),
                    _buildDrawerItem(
                      Icons.photo,
                      'Banner',
                      () => Navigator.of(context).pushNamed('/banners'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              children: [
                if (isLargeScreen) _buildCustomHeader(isLargeScreen),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: _currentView == BannerView.list
                          ? _bannersLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _banners.isEmpty
                                ? const Center(child: Text('No banners found.'))
                                : _buildBannerTable()
                          : _buildForm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
