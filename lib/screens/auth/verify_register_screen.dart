// lib/screens/auth/verify_register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/api_config.dart'; // Ensure this path is correct
import '../../../utils/device_utils.dart'; // For ResponsiveBuilder
// Import UserModel
// Import SharedPrefs

class VerifyRegisterScreen extends StatefulWidget {
  final String email;

  const VerifyRegisterScreen({super.key, required this.email});

  @override
  State<VerifyRegisterScreen> createState() => _VerifyRegisterScreenState();
}

class _VerifyRegisterScreenState extends State<VerifyRegisterScreen>
    with TickerProviderStateMixin {
  final _otpController = TextEditingController(); // New controller for OTP
  bool _isSendingOtp = false; // Renamed from _isResending
  bool _isVerifyingOtp = false; // New state for OTP verification

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    // Removed: Automatically send OTP when the screen loads
    // _sendOtp(); // This line is now commented out/removed
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
  }

  void _startAnimations() async {
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _otpController.dispose(); // Dispose OTP controller
    super.dispose();
  }

  /// Handles sending the OTP to the user's email.
  Future<void> _sendOtp() async {
    if (_isSendingOtp) return;

    setState(() {
      _isSendingOtp = true;
    });

    try {
      print('Attempting to send OTP to: ${widget.email}');
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/auth/send-otp',
            ), // API endpoint for sending OTP
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': widget.email}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - Server not responding');
            },
          );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccessSnackBar('OTP sent successfully to your email!');
      } else {
        _showErrorSnackBar(
          data['message'] ?? 'Failed to send OTP. Please try again.',
        );
      }
    } on SocketException {
      _showErrorSnackBar(
        'Cannot connect to server. Check your internet connection.',
      );
    } on TimeoutException {
      _showErrorSnackBar('Request timeout. Server is not responding.');
    } on FormatException {
      _showErrorSnackBar('Invalid response from server.');
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
    } finally {
      setState(() {
        _isSendingOtp = false;
      });
    }
  }

  /// Handles the verification of the OTP.
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      _showErrorSnackBar('Please enter the OTP.');
      return;
    }
    if (_isVerifyingOtp) return;

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      print(
        'Attempting to verify OTP for: ${widget.email} using ${ApiConfig.baseUrl}/auth/verify-register',
      ); // Updated print statement
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/auth/verify-register',
            ), // Updated API endpoint for verifying OTP
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': widget.email,
              'otpcode': _otpController.text.trim(),
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
        _showSuccessSnackBar('Email successfully verified!');

        // Assuming the backend returns user data and token upon successful OTP verification
        // final userData = data['user'];
        //final token = data['token'];

        // If no user data or token, navigate to login
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showErrorSnackBar(
          data['message'] ?? 'OTP verification failed. Please try again.',
        );
      }
    } on SocketException {
      _showErrorSnackBar(
        'Cannot connect to server. Check your internet connection.',
      );
    } on TimeoutException {
      _showErrorSnackBar('Request timeout. Server is not responding.');
    } on FormatException {
      _showErrorSnackBar('Invalid response from server.');
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
    } finally {
      setState(() {
        _isVerifyingOtp = false;
      });
    }
  }

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

  String? _validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (value.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Please enter a 6-digit OTP';
    }
    return null;
  }

  Widget _buildContent(double padding, DeviceType deviceType) {
    return Center(
      child: Container(
        width: deviceType == DeviceType.desktop ? 600 : double.infinity,
        margin: EdgeInsets.all(padding),
        padding: EdgeInsets.all(padding),
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
                width: 70,
                height: 70,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 70, color: Colors.grey);
                },
              ),
              const SizedBox(height: 30),
              const Text(
                'Verify Your Email with OTP', // Updated title
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'An OTP has been sent to:',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00BF63), // Highlight email
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Please enter the 6-digit OTP received in your inbox (and spam folder) to activate your account.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // OTP Input Field
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                validator: _validateOtp,
                decoration: _inputDecoration('OTP', Icons.vpn_key),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8, // Spacing for OTP digits
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isVerifyingOtp
                    ? null
                    : _verifyOtp, // Call _verifyOtp
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 30,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: Colors.black.withOpacity(0.2),
                ),
                child: _isVerifyingOtp
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Verify OTP', // Updated button text
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: _isSendingOtp ? null : _sendOtp, // Call _sendOtp
                style: TextButton.styleFrom(
                  foregroundColor:
                      Colors.blueAccent, // Different color for resend
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _isSendingOtp
                    ? const CircularProgressIndicator(color: Colors.blueAccent)
                    : const Text('Resend OTP'), // Updated button text
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Back to Login'),
              ),
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
            double padding;
            switch (deviceType) {
              case DeviceType.desktop:
                padding = 60.0;
                return SlideTransition(
                  position: _slideAnimation,
                  child: _buildContent(padding, deviceType),
                );
              case DeviceType.tablet:
                padding = 40.0;
                return SlideTransition(
                  position: _slideAnimation,
                  child: _buildContent(padding, deviceType),
                );
              case DeviceType.mobile:
              default:
                padding = 20.0;
                return SafeArea(
                  child: SingleChildScrollView(
                    child: _buildContent(padding, deviceType),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
