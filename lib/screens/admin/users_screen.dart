import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // For the arrow icons
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'dart:async'; // For TimeoutException
import 'dart:io'; // For SocketException
import 'package:intl/intl.dart'; // Import for date formatting

import '../../../models/user_model.dart'; // Assuming you have this model
import '../../../utils/shared_prefs.dart'; // Assuming you have this utility
import '../../../utils/api_config.dart'; // Assuming you have this utility
import '../../../widgets/sidebar_widget.dart'; // Import the new sidebar widget

// The enum to manage the current view state of the screen
enum UserView { list, create, edit, read }

class WebUsersScreen extends StatefulWidget {
  const WebUsersScreen({super.key});

  @override
  State<WebUsersScreen> createState() => _WebUsersScreenState();
}

class _WebUsersScreenState extends State<WebUsersScreen> {
  // Constants for layout
  static const double _kSidebarWidth = 256.0;
  static const double _kContentHorizontalPadding = 20.0;
  static const double _kAppBarHeight = kToolbarHeight;

  // State variables for the user management screen
  UserView _currentView = UserView.list;
  String? _editingUserId;
  final List<String> _userRoles = ['admin', 'customer'];
  final List<Map<String, dynamic>> _users = [];
  bool _usersLoading = true;
  bool _isFetchingUser = false; // New state variable for fetching a single user
  String? _selectedRole;

  // Key for Scaffold to control the Drawer (only used for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar on large screens
  bool _isSidebarOpen = true;

  // Placeholder for user details (will be fetched)
  User? _currentUser;
  String get userRole => _currentUser?.user_role ?? 'guest';

  // Text controllers for the user form
  final _usernameController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _cityController = TextEditingController();
  final _townshipController = TextEditingController();
  final _postalCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Fetch user data on init
    _fetchUsers(); // Fetch users on init
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    _townshipController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

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

  Future<void> _logout() async {
    await SharedPrefs.clearAll();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  Future<void> _fetchUserData() async {
    final user = await SharedPrefs.getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  // API call to fetch all users
  Future<void> _fetchUsers() async {
    setState(() {
      _usersLoading = true;
      _users.clear();
    });
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
          context,
          'Authentication token missing. Please log in again.',
          color: Colors.red,
        );
        return;
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/users/readall'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Server not responding.'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          if (mounted) {
            setState(() {
              _users.addAll(List<Map<String, dynamic>>.from(data['data']));
            });
          }
        } else {
          _showSnackBar(
            context,
            data['message'] ?? 'Failed to load users.',
            color: Colors.red,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to load users. Server error.',
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
          _usersLoading = false;
        });
      }
    }
  }

  // API call to fetch a single user's details
  Future<void> _fetchUserDetails(int userId) async {
    setState(() {
      _isFetchingUser = true;
      _resetForm();
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
          context,
          'Authentication token missing.',
          color: Colors.red,
        );
        return;
      }

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/users/read/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          final user = Map<String, dynamic>.from(data['data']);
          _populateFormWithUser(user);
          if (mounted) {
            setState(() {
              _currentView = UserView.read;
            });
          }
        } else {
          _showSnackBar(context, 'User not found.', color: Colors.red);
          if (mounted) {
            setState(() {
              _currentView = UserView.list;
            });
          }
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to fetch user.',
          color: Colors.red,
        );
      }
    } on Exception catch (e) {
      _showSnackBar(
        context,
        'Error fetching user: ${e.toString()}',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingUser = false;
        });
      }
    }
  }

  // API call to create a new user
  Future<void> _createUser() async {
    // Basic form validation
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedRole == null) {
      _showSnackBar(
        context,
        'Please fill in all required fields.',
        color: Colors.orange,
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar(context, 'Passwords do not match.', color: Colors.orange);
      return;
    }

    final userData = {
      "username": _usernameController.text,
      "fullname": _fullnameController.text,
      "email": _emailController.text,
      "phone": _phoneController.text,
      "dob": _dobController.text,
      "password": _passwordController.text,
      "address_line": _addressLineController.text,
      "city": _cityController.text,
      "township": _townshipController.text,
      "postal_code": _postalCodeController.text,
      "role": _selectedRole,
    };

    try {
      final String? token = await SharedPrefs.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        _showSnackBar(
          context,
          'User created successfully!',
          color: Colors.green,
        );
        _fetchUsers(); // Refresh the user list
        setState(() {
          _resetForm();
          _currentView = UserView.list;
        });
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to create user.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error creating user: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  // API call to update an existing user
  Future<void> _updateUser() async {
    final userData = {
      "username": _usernameController.text,
      "fullname": _fullnameController.text,
      "email": _emailController.text,
      "phone": _phoneController.text,
      "dob": _dobController.text,
      "address_line": _addressLineController.text,
      "city": _cityController.text,
      "township": _townshipController.text,
      "postal_code": _postalCodeController.text,
      "role": _selectedRole,
    };

    try {
      final String? token = await SharedPrefs.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/users/update/$_editingUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'User updated successfully!',
          color: Colors.green,
        );
        _fetchUsers(); // Refresh the user list
        setState(() {
          _resetForm();
          _currentView = UserView.list;
        });
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to update user.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error updating user: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  // API call to delete a user
  Future<void> _deleteUser(int userId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/users/delete/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'User deleted successfully!',
          color: Colors.green,
        );
        _fetchUsers(); // Refresh the user list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to delete user.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error deleting user: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  // Resets all form fields and state
  void _resetForm() {
    _editingUserId = null;
    _usernameController.clear();
    _fullnameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _dobController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _addressLineController.clear();
    _cityController.clear();
    _townshipController.clear();
    _postalCodeController.clear();
    _selectedRole = null;
  }

  // Populates form fields with user data
  void _populateFormWithUser(Map<String, dynamic> user) {
    // Convert the integer id to a string before assigning it
    _editingUserId = user['id']?.toString();
    _usernameController.text = user['username'] ?? '';
    _fullnameController.text = user['fullname'] ?? '';
    _emailController.text = user['email'] ?? '';
    _phoneController.text = user['phone'] ?? '';
    _dobController.text = user['dob'] ?? '';
    _addressLineController.text = user['address_line'] ?? '';
    _cityController.text = user['city'] ?? '';
    _townshipController.text = user['township'] ?? '';
    _postalCodeController.text = user['postal_code'] ?? '';
    _selectedRole = user['user_role'];
  }

  // Handles the "View Details" action by fetching a user from the API
  void _handleViewDetails(int userId) async {
    await _fetchUserDetails(userId);
    // The fetchUserDetails method will set the view to read
  }

  // Handles the "Edit User" action
  void _handleEditUser(Map<String, dynamic> user) {
    _populateFormWithUser(user);
    setState(() {
      _currentView = UserView.edit;
    });
  }

  // Handles the "Delete User" action
  void _handleDeleteUser(int userId) {
    _showConfirmationDialog(
      context,
      title: 'Delete User',
      content: 'Are you sure you want to delete this user?',
      onConfirm: () async {
        await _deleteUser(userId);
      },
    );
  }

  // Shows a custom confirmation dialog
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

  // Handles the form submission (create or update)
  void _submitForm() async {
    if (_editingUserId == null) {
      await _createUser();
    } else {
      await _updateUser();
    }
  }

  // Shows a date picker dialog and formats the selected date
  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // The user table for displaying all users
  Widget _buildUserTable() {
    if (_usersLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No users found.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {
                _resetForm();
                _currentView = UserView.create;
              }),
              child: const Text("Create User"),
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
                      _currentView = UserView.create;
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text("Create User"),
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
                  padding: const EdgeInsets.all(8.0),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Username')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _users.map((user) {
                      return DataRow(
                        cells: [
                          DataCell(Text(user['username'] ?? 'N/A')),
                          DataCell(Text(user['user_role'] ?? 'N/A')),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  tooltip: 'View Details',
                                  onPressed: () =>
                                      _handleViewDetails(user['id']!),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit User',
                                  onPressed: () => _handleEditUser(user),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete User',
                                  onPressed: () =>
                                      _handleDeleteUser(user['id']!),
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

  // The form for creating, editing, and viewing users
  Widget _buildForm() {
    // Determine if the form should be read-only
    final isReadOnly = _currentView == UserView.read;

    // Determine the title based on the view
    final formTitle = _currentView == UserView.create
        ? 'Create New User'
        : _currentView == UserView.edit
        ? 'Edit User'
        : 'User Details';

    if (_isFetchingUser) {
      return const Center(child: CircularProgressIndicator());
    }

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
              TextField(
                controller: _usernameController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _fullnameController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                readOnly: isReadOnly,
                onTap: isReadOnly ? null : () => _selectDateOfBirth(context),
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),
              if (_currentView != UserView.read) ...[
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _addressLineController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Address Line'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _townshipController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Township'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _postalCodeController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Postal Code'),
              ),
              const SizedBox(height: 16),
              // Show role as a DropdownButtonFormField for create/edit, but as text for view
              if (isReadOnly)
                Text(
                  'Role: ${_selectedRole ?? 'N/A'}',
                  style: Theme.of(context).textTheme.titleMedium,
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  hint: const Text('Select Role'),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue;
                    });
                  },
                  items: _userRoles.map<DropdownMenuItem<String>>((
                    String value,
                  ) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_currentView == UserView.read) {
                        setState(() {
                          _resetForm();
                          _currentView = UserView.list;
                        });
                      } else {
                        _submitForm();
                      }
                    },
                    child: Text(
                      _currentView == UserView.read
                          ? 'Back to List'
                          : (_editingUserId == null
                                ? 'Create User'
                                : 'Update User'),
                    ),
                  ),
                  if (_currentView != UserView.read) ...[
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _resetForm();
                          _currentView = UserView.list;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
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
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
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
          if (isLargeScreen)
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
                Navigator.of(context).pushNamed('/banners');
              },
            ),
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
                      child: _currentView == UserView.list
                          ? _usersLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _users.isEmpty
                                ? const Center(child: Text('No users found.'))
                                : _buildUserTable()
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

  // Helper method for building a single user item in the list
  // This method is used for the mobile drawer.
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
