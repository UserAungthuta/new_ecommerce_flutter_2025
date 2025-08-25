import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class DeviceUtils {
  // Device type enumeration
  static DeviceType getDeviceType(BuildContext context) {
    if (kIsWeb) {
      return _getWebDeviceType(context);
    } else {
      return _getMobileDeviceType(context);
    }
  }

  // Check if current device is mobile
  static bool isMobile(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.of(context).size.width < 768;
    }
    return !isTablet(context);
  }

  // Check if current device is tablet
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diagonal = _calculateDiagonal(size);

    if (kIsWeb) {
      return size.width >= 768 && size.width < 1024;
    }

    // For mobile platforms, use diagonal size
    return diagonal >= 7.0 && diagonal < 12.0;
  }

  // Check if current device is desktop
  static bool isDesktop(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.of(context).size.width >= 1024;
    }
    return false; // Mobile platforms don't have desktop
  }

  // Get responsive padding based on device type
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 32);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    }
  }

  // Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context,
    double baseFontSize,
  ) {
    if (isDesktop(context)) {
      return baseFontSize * 1.2;
    } else if (isTablet(context)) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize;
    }
  }

  // Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    if (isDesktop(context)) {
      return baseSize * 1.3;
    } else if (isTablet(context)) {
      return baseSize * 1.15;
    } else {
      return baseSize;
    }
  }

  // Get number of columns for grid layouts
  static int getGridColumns(BuildContext context) {
    if (isDesktop(context)) {
      return 4;
    } else if (isTablet(context)) {
      return 3;
    } else {
      return 2;
    }
  }

  // Get responsive card width
  static double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isDesktop(context)) {
      return screenWidth * 0.3;
    } else if (isTablet(context)) {
      return screenWidth * 0.45;
    } else {
      return screenWidth * 0.9;
    }
  }

  // Check if device supports hover (typically desktop)
  static bool supportsHover() {
    return kIsWeb; // Simplified - in practice, you might want more sophisticated detection
  }

  // Get appropriate layout orientation
  static bool shouldUseWideLayout(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  // Private helper methods
  static DeviceType _getWebDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1024) {
      return DeviceType.desktop;
    } else if (width >= 768) {
      return DeviceType.tablet;
    } else {
      return DeviceType.mobile;
    }
  }

  static DeviceType _getMobileDeviceType(BuildContext context) {
    if (isTablet(context)) {
      return DeviceType.tablet;
    }
    return DeviceType.mobile;
  }

  static double _calculateDiagonal(Size size) {
    final pixelRatio = WidgetsBinding.instance.window.devicePixelRatio;
    final width = size.width * pixelRatio;
    final height = size.height * pixelRatio;

    // Assume ~160 DPI for calculation
    const dpi = 160.0;
    final diagonal = (width * width + height * height) / (dpi * dpi);
    return diagonal;
  }
}

// Device type enumeration
enum DeviceType { mobile, tablet, desktop }

// Screen size breakpoints
class ScreenBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}

// Responsive helper widget
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, DeviceUtils.getDeviceType(context));
  }
}

// Layout helper for different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (DeviceUtils.isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (DeviceUtils.isTablet(context) && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}
