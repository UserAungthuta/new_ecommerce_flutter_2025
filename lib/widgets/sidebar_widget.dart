import 'package:flutter/material.dart';

class WebSuperAdminSidebar extends StatelessWidget {
  final bool isOpen;
  final double width;
  final VoidCallback onDashboardTap;
  final VoidCallback onUsersTap;
  final VoidCallback onProductsTap;
  final VoidCallback onOrdersTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onBannerTap;

  const WebSuperAdminSidebar({
    super.key,
    required this.isOpen,
    required this.width,
    required this.onDashboardTap,
    required this.onUsersTap,
    required this.onProductsTap,
    required this.onOrdersTap,
    required this.onCategoryTap,
    required this.onBannerTap,
  });

  // Helper method for building sidebar items
  Widget _buildSidebarItem(
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
      selectedTileColor: const Color(0xFF2563EB), // Equivalent to blue-600
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Standard AppBar height for the custom sidebar header
    const double kAppBarHeight = kToolbarHeight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), // Smooth animation
      width: isOpen ? width : 0.0, // Toggle width
      color: const Color(0xFF1E293B), // Equivalent to bg-gray-800
      child:
          isOpen // Only render content if sidebar is open
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar Header (can be customized if needed)
                Container(
                  height: kAppBarHeight, // Match custom header height
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildSidebarItem(
                        Icons.dashboard,
                        'Dashboard',
                        onDashboardTap,
                      ),
                      _buildSidebarItem(Icons.people, 'Users', onUsersTap),
                      _buildSidebarItem(
                        Icons.shopping_bag,
                        'Products',
                        onProductsTap,
                      ),
                      _buildSidebarItem(Icons.receipt, 'Orders', onOrdersTap),
                      _buildSidebarItem(
                        Icons.category,
                        'Category',
                        onCategoryTap,
                      ),
                      _buildSidebarItem(Icons.image, 'Banner', onBannerTap),
                    ],
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(), // Hide content when sidebar is closed
    );
  }
}
