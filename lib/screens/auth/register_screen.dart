// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

// Adjust path as necessary - might not need User model initially for registration
// Adjust path as necessary
import '../../../utils/api_config.dart'; // Adjust path as necessary
import '../../../utils/device_utils.dart'; // Added for ResponsiveBuilder

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // New controllers for registration fields
  final _usernameController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); // Already exists
  final _dobController = TextEditingController(); // For Date of Birth
  final _passwordController = TextEditingController(); // Already exists
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _townshipController = TextEditingController();
  final _postalCodeController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.elasticOut,
          ),
        );
    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _startAnimations() async {
    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _formAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _formAnimationController.dispose();
    _usernameController.dispose();
    _fullnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _townshipController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  /// Handles the user registration process.
  Future<void> _register() async {
    // Renamed from _login
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print(
        'Attempting registration to: ${ApiConfig.baseUrl}/auth/register',
      ); // Updated endpoint

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/register'), // Updated endpoint
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': _usernameController.text.trim(),
              'fullname': _fullnameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'email': _emailController.text.trim(),
              'dob': _dobController.text.trim(), // Date of Birth
              'password': _passwordController.text,
              'address': _addressController.text.trim(),
              'city': _cityController.text.trim(),
              'township': _townshipController.text.trim(),
              'postal_code': _postalCodeController.text.trim(),
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - Server not responding');
            },
          );

      final data = json.decode(response.body);

      if (data['success'] == true) {
        // Typically 201 for resource creation
        _showSuccessSnackBar(
          'Registration successful! Please verify your email.',
        );
        // Navigate to register verify page, passing the email
        Navigator.pushReplacementNamed(
          context,
          '/register_verify', // Assuming this is your verify page route
          arguments: _emailController.text.trim(), // Pass email as argument
        );
      } else {
        _showErrorSnackBar(
          data['message'] ?? 'Registration failed. Please try again.',
        );
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      _showErrorSnackBar(
        'Cannot connect to server. Check your internet connection.',
      );
    } on TimeoutException catch (e) {
      print('TimeoutException: $e');
      _showErrorSnackBar('Request timeout. Server is not responding.');
    } on FormatException catch (e) {
      print('FormatException: $e');
      _showErrorSnackBar('Invalid response from server.');
    } catch (e) {
      print('General Exception: $e');
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // (SnackBar methods remain the same)
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // New validation methods for additional fields
  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, underscores, and dots.';
    }
    return null;
  }

  String? _validateFullname(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full Name is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    // Simple regex for phone number, adjust as needed for specific formats
    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'Please enter a valid phone number (digits only).';
    }
    return null;
  }

  // _validateEmail remains the same as it's general for email/username
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Address is required';
    }
    return null;
  }

  String? _validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'City is required';
    }
    return null;
  }

  String? _validateTownship(String? value) {
    if (value == null || value.isEmpty) {
      return 'Township is required';
    }
    return null;
  }

  String? _validatePostalCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Postal Code is required';
    }
    // You might want a more specific regex for postal codes
    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'Please enter a valid postal code (digits only).';
    }
    return null;
  }

  /// Builds the registration form widgets.
  Widget _buildRegistrationForm() {
    return FadeTransition(
      opacity: _formFadeAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Your Account!', // Updated text
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign up to get started', // Updated text
              style: TextStyle(fontSize: 18, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // New TextFormFields for registration
            TextFormField(
              controller: _usernameController,
              validator: _validateUsername,
              decoration: _inputDecoration('Username', Icons.person_outline),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _fullnameController,
              validator: _validateFullname,
              decoration: _inputDecoration('Full Name', Icons.person),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              decoration: _inputDecoration('Phone Number', Icons.phone),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              decoration: _inputDecoration('Email Address', Icons.email),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            // DOB field (can use a date picker)
            TextFormField(
              controller: _dobController,
              keyboardType: TextInputType.datetime,
              decoration: _inputDecoration(
                'Date of Birth (YYYY-MM-DD)',
                Icons.calendar_today,
              ),
              readOnly: true, // Make it read-only and use a date picker
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  setState(() {
                    _dobController.text =
                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                  });
                }
              },
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: _validatePassword,
              decoration: _inputDecorationWithToggle('Password', Icons.lock),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _addressController,
              validator: _validateAddress,
              decoration: _inputDecoration('Address', Icons.location_on),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _cityController,
              validator: _validateCity,
              decoration: _inputDecoration('City', Icons.location_city),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _townshipController,
              validator: _validateTownship,
              decoration: _inputDecoration(
                'Township',
                Icons.location_on_outlined,
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _postalCodeController,
              keyboardType: TextInputType.number,
              validator: _validatePostalCode,
              decoration: _inputDecoration(
                'Postal Code',
                Icons.local_post_office,
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/guest_home');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00BF63),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Back to Home'),
                ),
                TextButton(
                  onPressed: () {
                    // This button should now navigate to the login screen if the user has an account
                    Navigator.pushNamed(context, '/login');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00BF63),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _register, // Call _register
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BF63),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: Colors.black.withOpacity(0.2),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Sign Up', // Updated text
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method for common InputDecoration
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: 'Enter your $label',
      labelStyle: TextStyle(color: Colors.grey[700]),
      hintStyle: TextStyle(color: Colors.grey[500]),
      prefixIcon: Icon(icon, color: const Color(0xFF00BF63)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[200]!, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  // Helper method for password InputDecoration with toggle
  InputDecoration _inputDecorationWithToggle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: 'Enter your $label',
      labelStyle: TextStyle(color: Colors.grey[700]),
      hintStyle: TextStyle(color: Colors.grey[500]),
      prefixIcon: Icon(icon, color: const Color(0xFF00BF63)),
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[200]!, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  // (Marketing Header, Features List, Desktop/Tablet/Mobile Layouts remain largely the same,
  // but ensure they call _buildRegistrationForm() instead of _buildLoginForm())

  // Desktop layout with two columns (similar to Forgot Password Screen)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Panel - Branding/Marketing
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(60),
            child: _buildMarketingHeader(),
          ),
        ),
        // Right Panel - Login Form
        Expanded(
          flex: 2,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: _buildRegistrationForm(),
              ), // Changed
            ),
          ),
        ),
      ],
    );
  }

  // Tablet layout (single column, centered form, similar to Forgot Password Screen)
  Widget _buildTabletLayout() {
    return Center(
      child: Container(
        width: 600, // Fixed width for tablet form container
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 5,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                fit: BoxFit.contain,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 50, color: Colors.white);
                },
              ),
              const SizedBox(height: 20),
              _buildRegistrationForm(), // Changed
            ],
          ),
        ),
      ),
    );
  }

  // Mobile layout (single column, centered form with scroll, similar to Forgot Password Screen)
  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Image.network(
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                fit: BoxFit.contain,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 50, color: Colors.white);
                },
              ),
              const SizedBox(height: 20),
              _buildRegistrationForm(), // Changed
            ],
          ),
        ),
      ),
    );
  }

  // Header for marketing panel on desktop (similar to Forgot Password Screen)
  Widget _buildMarketingHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                '${ApiConfig.baseUrl}/assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 40, color: Colors.grey);
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Join Su Store - Ecommerce', // Updated text
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 4,
                  color: Color.fromRGBO(0, 0, 0, 0.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Unlock a world of products and exclusive offers. Create your account today!', // Updated text
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _buildFeaturesList(),
        ],
      ),
    );
  }

  // Features list (reused from forgot password screen for consistency)
  Widget _buildFeaturesList() {
    final features = [
      'Access thousands of products', // Updated text
      'Track your orders easily',
      'Secure and seamless shopping experience',
      'Receive exclusive discounts and updates', // Updated text
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features
          .map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    feature,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.orangeAccent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepOrangeAccent, Colors.orangeAccent],
          ),
        ),
        child: ResponsiveBuilder(
          builder: (context, deviceType) {
            switch (deviceType) {
              case DeviceType.desktop:
                return _buildDesktopLayout();
              case DeviceType.tablet:
                return _buildTabletLayout();
              case DeviceType.mobile:
              default:
                return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }
}
