// lib/screens/web/web_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

// No dart:html import here
// Still needed for conditional logic, but not for html direct use
import '../../../models/user_model.dart'; // Adjust path as necessary
import '../../../utils/shared_prefs.dart'; // Adjust path as necessary
import '../../../utils/api_config.dart'; // Adjust path as necessary
import '../../../utils/device_utils.dart'; // Added for ResponsiveBuilder

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  final bool _rememberMe = false;
  // Removed unused _isHoveringLogin and _isHoveringRegister as they were not utilized

  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // _setWebPageTitle(); // Removed as it relied on dart:html
    //_loadRememberedCredentials(); // Updated to use SharedPrefs
    _startAnimations();
  }

  /// Initializes all animation controllers and tweens for the login screen.
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

  /// Starts the animations for the background elements and then the form.
  void _startAnimations() async {
    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _formAnimationController.forward();
  }

  // _setWebPageTitle() method removed as it directly uses dart:html.
  // For web, the title is usually set in web/index.html or via MaterialApp title.

  /// Loads previously remembered email credentials from local storage.
  /// Now uses SharedPrefs for cross-platform compatibility.

  @override
  void dispose() {
    _animationController.dispose();
    _formAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles the user login process.
  /// Validates input, sends a POST request to the API, and handles the response.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // "Remember Me" now uses SharedPrefs, which is cross-platform

      print('Attempting login to: ${ApiConfig.baseUrl}/auth/login');

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'unique': _emailController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - Server not responding');
            },
          );

      final data = json.decode(response.body);

      // Define a map of user roles to their respective dashboard routes
      final Map<String, String> roleRoutes = {
        'admin': '/admin_home',
        'customer': '/customer_home',
      };

      // Process successful login response
      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        final String token = data['token']?.toString() ?? '';

        await SharedPrefs.saveUser(user, token);
        await SharedPrefs.saveToken(token);

        // Always show the success snackbar if login was successful
        _showSuccessSnackBar(
          'Login successful! Welcome ${user.fullname ?? user.username}',
        );

        String? route = roleRoutes[user.user_role];
        if (route != null) {
          // Dynamic web page title update removed as it relied on dart:html.
          // Consider using a package like 'flutter_web_plugins' if dynamic title is critical
          // and you still want platform separation without direct dart:html.
          Navigator.pushReplacementNamed(context, route);
        } else {
          // If login was successful but no route is defined for the role,
          // show a specific message about the routing issue, not a login failure.
          _showErrorSnackBar(
            'Login successful, but no dashboard found for your role: ${user.user_role}. Please contact support.',
          );
        }
      } else {
        // Handle unsuccessful login due to credentials or other API-reported issues
        _showErrorSnackBar(
          data['message'] ?? 'Login failed. Please try again.',
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

  /// Displays a success message using a SnackBar.
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

  /// Displays an error message using a SnackBar.
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

  /// Validates the email or username input field.
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email or username is required';
    }
    if (value.contains('@')) {
      if (!RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(value.trim())) {
        return 'Please enter a valid email address';
      }
    } else {
      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value.trim())) {
        return 'Please enter a valid username';
      }
    }
    return null;
  }

  /// Validates the password input field.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Builds the login form widgets.
  Widget _buildLoginForm() {
    return FadeTransition(
      opacity: _formFadeAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign in to your account',
              style: TextStyle(fontSize: 18, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              cursorColor: Colors.blue[600],
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Email / Username',
                hintText: 'Enter your email or username',
                labelStyle: TextStyle(color: Colors.grey[700]),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.person, color: const Color(0xFF00BF63)),
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
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: _validatePassword,
              cursorColor: Colors.blue[600],
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                labelStyle: TextStyle(color: Colors.grey[700]),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.lock, color: const Color(0xFF00BF63)),
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
              ),
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
                    Navigator.pushNamed(context, '/register');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00BF63),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Register'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
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
                      'Sign In',
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
            'Welcome to Su Store - Ecommerce',
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
            'Your gateway to effortless shopping and powerful features. Log in to start your journey.',
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
      'Browse thousands of products easily',
      'Track your orders in real-time',
      'Secure checkout and payment options',
      'Get exclusive deals and discounts',
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
              child: SingleChildScrollView(child: _buildLoginForm()),
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
              // For tablet, we can still include a simplified header or logo
              // without the full marketing text.
              Image.network(
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                fit: BoxFit.contain,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if the asset image cannot be loaded
                  return const Icon(Icons.error, size: 50, color: Colors.white);
                },
              ),
              const SizedBox(height: 20),
              _buildLoginForm(),
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
              // Simplified header for mobile as well
              Image.network(
                '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                fit: BoxFit.contain,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if the asset image cannot be loaded
                  return const Icon(Icons.error, size: 50, color: Colors.white);
                },
              ),
              const SizedBox(height: 20),
              _buildLoginForm(),
            ],
          ),
        ),
      ),
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
