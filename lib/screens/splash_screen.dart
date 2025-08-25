// lib/screens/web/web_splash_screen.dart
import 'package:flutter/material.dart';
import '../../utils/shared_prefs.dart';
import '../../utils/api_config.dart';
// Assuming this is needed for responsive text sizing

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
    _checkAuthStatus();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  // Removed _setWebPageTitle() method as it's no longer needed here.

  void _startAnimation() async {
    _animationController.forward();
  }

  Future<void> _checkAuthStatus() async {
    // Ensure the splash screen is visible for at least 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    final user = await SharedPrefs.getUser();

    if (!mounted) return;

    // Browser tab title update (after splash) will be managed by MaterialApp's title property
    // or a Title widget on subsequent screens if you need dynamic titles.

    if (user != null) {
      final Map<String, String> roleRoutes = {
        'admin': '/admin_home',
        'customer': '/customer_home',
      };

      String? route = roleRoutes[user.user_role];

      if (route != null) {
        Navigator.pushReplacementNamed(context, route);
      } else {
        Navigator.pushReplacementNamed(context, '/guest_home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/guest_home');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orangeAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            spreadRadius: 5,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.network(
                            '${ApiConfig.baseUrl}/assets/logo.png', // Path to your local asset image
                            fit: BoxFit.contain,
                            width: 80,
                            height: 80,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if the asset image cannot be loaded
                              return const Icon(
                                Icons.error,
                                size: 50,
                                color: Colors.white,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Su Store E-commerce Web',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 246, 247, 247),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Comprehensive Support for Modern eCommerce',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 254, 255, 255),
                ),
              ),
            ),
            const SizedBox(height: 50),
            FadeTransition(
              opacity: _fadeAnimation,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
