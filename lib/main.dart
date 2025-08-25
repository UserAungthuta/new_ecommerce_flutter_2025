import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
// Required for WidgetsFlutterBinding
import 'package:flutter/scheduler.dart'; // For debugPrint

// Assuming this is your main login screen
//import 'screens/customer/home_screen.dart;
//import 'screens/admin/home_screen.dart;
import 'package:new_ecommerce/screens/guest/home_screen.dart';
import 'package:new_ecommerce/screens/admin/home_screen.dart';
import 'package:new_ecommerce/screens/admin/users_screen.dart'; // '/users'
import 'package:new_ecommerce/screens/admin/products_screen.dart'; // '/admin_product'
import 'package:new_ecommerce/screens/admin/orders_screen.dart'; // '/admin_order'
import 'package:new_ecommerce/screens/admin/category_screen.dart'; // '/admin_category'
import 'package:new_ecommerce/screens/admin/banners_screen.dart'; // '/banners'
// '/admin_profile'
import 'package:new_ecommerce/screens/customer/home_screen.dart';
import 'package:new_ecommerce/screens/customer/profile_screen.dart';
import 'package:new_ecommerce/screens/customer/payment_success_screen.dart';
import 'package:new_ecommerce/screens/customer/wishlist_screen.dart';
import 'package:new_ecommerce/screens/customer/order_history.dart';
import 'package:new_ecommerce/screens/products/product_details.dart';
import 'package:new_ecommerce/screens/cart/cart_screen.dart';
import 'package:new_ecommerce/screens/auth/login_screen.dart';
import 'package:new_ecommerce/screens/auth/register_screen.dart';
import 'package:new_ecommerce/screens/auth/verify_register_screen.dart';
import 'package:new_ecommerce/screens/splash_screen.dart';

// Ensure this utility is correctly implemented
import 'utils/device_utils.dart'; // Ensure this utility is correctly implemented

// Make main async to allow for platform-specific initialization
void main() async {
  // Ensure that Flutter binding is initialized. This is crucial for services
  // like SharedPreferences (used by SharedPrefs.getUser()).
  WidgetsFlutterBinding.ensureInitialized();

  // Perform any platform-specific initialization if required.
  await PlatformInitializer.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Su Store - E-commmerce',
      theme: _buildTheme(),
      // Use initialRoute to specify the starting point of the app.
      // The actual widget for '/' is defined in the routes map.
      initialRoute: '/',
      // All named routes must be defined in this map.
      routes: _getRoutes(),
      debugShowCheckedModeBanner: false, // Set to true for debugging overlay
    );
  }

  // Device-aware theme configuration
  ThemeData _buildTheme() {
    if (kIsWeb) {
      // Web-optimized theme
      return ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.compact,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      // Mobile-optimized theme
      return ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(elevation: 1),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      );
    }
  }
}

// Consolidated and comprehensive route definition
// Consolidated and comprehensive route definition
Map<String, WidgetBuilder> _getRoutes() {
  final routes = {
    // Initial splash screen route (based on platform)
    '/': (context) => kIsWeb ? const SplashScreen() : const SplashScreen(),

    // Reuse mobile settings for web
    // Update with actual web dashboard screen

    // --- Dashboard Routes ---
    // Uncomment and complete these when you implement your dashboard screens.
    '/guest_home': (context) => const GuestHomeScreen(),
    '/admin_home': (context) => const AdminHomeScreen(),
    '/customer_home': (context) => const CustomerHomeScreen(),
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/register_verify': (context) {
      final email = ModalRoute.of(context)!.settings.arguments as String;
      return VerifyRegisterScreen(email: email);
    },
    '/product_detail': (context) {
      final productData =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return ProductDetailPage(product: productData);
    },
    '/cart': (context) => const CartScreen(),
    '/wishlist': (context) => const WishlistScreen(),
    '/profile': (context) => const ProfileScreen(),
    '/users': (context) => const WebUsersScreen(),
    '/admin_product': (context) => const WebProductsScreen(),
    '/admin_category': (context) => const WebCategoriesScreen(),
    '/banners': (context) => const WebBannersScreen(),
    '/admin_order': (context) => const WebOrdersScreen(),
    '/orders': (context) => const OrderHistoryScreen(),

    // '/admin-dashboard': (context) => const AdminDashboardScreen(),
    // '/mobile_supervisor-dashboard': (context) => const SupervisorDashboardScreen(),
    // '/mobile_engineer-dashboard': (context) => const EngineerDashboardScreen(),
    // '/mobile_member-dashboard': (context) => const MemberDashboardScreen(),
    // '/mobile_champion-dashboard': (context) => const ChampionDashboardScreen(),
    // '/mobile_localcustomer-dashboard': (context) => const LocalCustomerDashboardScreen(),
    // '/customer-home': (context) => const CustomerHomeScreen(),
  };

  // IMPORTANT DEBUG PRINT: This will show you exactly what routes Flutter registers.

  SchedulerBinding.instance.addPostFrameCallback((_) {
    debugPrint('Registered routes: ${routes.keys.toList()}');
  });

  return routes;
}

// Device utility class for runtime checks (unchanged)
class DeviceAwareWidget extends StatelessWidget {
  final Widget mobileWidget;
  final Widget webWidget;
  final Widget? tabletWidget;

  const DeviceAwareWidget({
    super.key,
    required this.mobileWidget,
    required this.webWidget,
    this.tabletWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return webWidget;
    }

    if (tabletWidget != null && DeviceUtils.isTablet(context)) {
      return tabletWidget!;
    }

    return mobileWidget;
  }
}

// Navigation helper that considers device type (unchanged)
class DeviceAwareNavigator {
  static void pushNamed(BuildContext context, String routeName) {
    if (kIsWeb) {
      Navigator.pushNamed(context, routeName);
    } else {
      Navigator.pushNamed(context, routeName);
    }
  }

  static void pushReplacementNamed(BuildContext context, String routeName) {
    if (kIsWeb) {
      Navigator.pushReplacementNamed(context, routeName);
    } else {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  static void pushAndRemoveUntil(BuildContext context, String routeName) {
    if (kIsWeb) {
      Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
    }
  }
}

// Platform-specific initialization (unchanged)
class PlatformInitializer {
  static Future<void> initialize() async {
    if (kIsWeb) {
      await _initializeWeb();
    } else {
      await _initializeMobile();
    }
  }

  static Future<void> _initializeWeb() async {
    print('Initializing for Web platform');
    // Add any web-specific initialization logic here
  }

  static Future<void> _initializeMobile() async {
    print('Initializing for Mobile platform');
    // Add any mobile-specific initialization logic here
  }
}
