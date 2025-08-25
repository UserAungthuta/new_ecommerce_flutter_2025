// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for API calls
import 'dart:convert'; // Import for JSON decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException

import '../../../models/user_model.dart'; // Ensure this path is correct
import '../../../utils/shared_prefs.dart'; // For fetching user data and token
import '../../../utils/api_config.dart'; // For API base URL
import '../../../utils/device_utils.dart'; // For ResponsiveBuilder

import 'order_detail.dart';
import 'payment_screen.dart';

enum ProfileSection { details, orders, address } // Enum to manage sections

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  bool _isLoading = true;
  String? _authToken; // To store the user's authentication token

  List<dynamic> _orders = []; // State for order history
  bool _isOrdersLoading = true; // State for order history loading

  ProfileSection _currentSection = ProfileSection.details; // Default section

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndOrders(); // Load user and then orders
  }

  Future<void> _loadCurrentUserAndOrders() async {
    // First, try to load user and token from SharedPrefs
    final userFromPrefs = await SharedPrefs.getUser(); //
    final token = await SharedPrefs.getToken(); //

    if (mounted) {
      setState(() {
        _authToken = token; //
      });
    }

    // Only proceed if a user and token are available from SharedPrefs
    if (userFromPrefs != null && _authToken != null) {
      // Fetch the most up-to-date user data from the API
      await _fetchCurrentUserDetails(
        userFromPrefs.id,
      ); // Call new method to fetch details

      // If user details were successfully fetched and updated, proceed with orders
      if (_currentUser != null) {
        //
        _fetchOrderHistory(); // Fetch orders only if user is logged in and data is updated
      } else {
        // If API fetch failed, revert to SharedPrefs user or handle as logged out
        if (mounted) {
          setState(() {
            _currentUser = userFromPrefs; // Use SharedPrefs user if API failed
            _isLoading = false; //
            _isOrdersLoading =
                false; // No orders if user data couldn't be confirmed
          });
        }
      }
    } else {
      // No user or token in SharedPrefs, treat as logged out
      if (mounted) {
        setState(() {
          _isLoading = false; //
          _isOrdersLoading = false; //
          _currentUser =
              null; // Ensure current user is null for logged out state
        });
      }
    }
  }

  /// Fetches the current user's complete details from the backend API.
  Future<void> _fetchCurrentUserDetails(int userId) async {
    //
    if (_authToken == null) {
      //
      _showSnackBar(
        //
        'Authentication token missing for fetching user details.', //
        color: Colors.orange, //
      ); //
      return; //
    } //

    if (mounted) {
      //
      setState(() {
        //
        _isLoading = true; // Indicate loading for user details
      }); //
    } //

    try {
      //
      final response =
          await http //
              .get(
                //
                Uri.parse('${ApiConfig.baseUrl}/users/read/$userId'), //
                headers: {
                  //
                  'Content-Type': 'application/json', //
                  'Authorization': 'Bearer $_authToken', //
                }, //
              ) //
              .timeout(
                //
                const Duration(seconds: 10), //
                onTimeout: () {
                  //
                  throw Exception(
                    'Request timeout - Server not responding for user details',
                  ); //
                }, //
              ); //

      final data = json.decode(response.body); //

      if (response.statusCode == 200) {
        //
        if (mounted) {
          //
          setState(() {
            //
            // Update _currentUser with the fresh data from the API
            _currentUser = User.fromJson(
              data['data'],
            ); // Assuming 'data' directly contains the user map
          }); //
        } //
      } else {
        //
        _showSnackBar(
          //
          data['message'] ??
              'Failed to load user details. Please try again.', //
          color: Colors.red, //
        ); //
      } //
    } on SocketException {
      //
      _showSnackBar(
        //
        'Network error. Check your internet connection.', //
        color: Colors.red, //
      ); //
    } on TimeoutException {
      //
      _showSnackBar(
        //
        'Request timed out. Server is not responding for user details.', //
        color: Colors.red, //
      ); //
    } on FormatException {
      //
      _showSnackBar(
        'Invalid response from server for user details.',
        color: Colors.red,
      ); //
    } catch (e) {
      //
      _showSnackBar(
        //
        'An unexpected error occurred while fetching user details: ${e.toString()}', //
        color: Colors.red, //
      ); //
    } finally {
      //
      if (mounted) {
        //
        setState(() {
          //
          _isLoading = false; // Loading is complete for user details
        }); //
      } //
    } //
  } //

  void _showSnackBar(String message, {Color color = Colors.black}) {
    //
    if (!mounted) return; //
    ScaffoldMessenger.of(context).showSnackBar(
      //
      SnackBar(
        //
        content: Text(message), //
        backgroundColor: color, //
        duration: const Duration(seconds: 2), //
      ), //
    ); //
  } //

  // Shows a full-screen loading dialog
  void _showLoadingDialog() {
    //
    showDialog(
      //
      context: context, //
      barrierDismissible: false, //
      builder: (BuildContext context) {
        //
        return const Dialog(
          //
          backgroundColor: Colors.transparent, //
          elevation: 0, //
          child: Center(
            //
            child: CircularProgressIndicator(color: Color(0xFF00BF63)), //
          ), //
        ); //
      }, //
    ); //
  } //

  // Hides the full-screen loading dialog
  void _hideLoadingDialog() {
    //
    if (Navigator.of(context).canPop()) {
      //
      Navigator.of(context).pop(); //
    } //
  } //

  // Placeholder for future edit functionality
  void _editProfile() {
    //
    _showSnackBar(
      //
      'Edit Profile functionality coming soon!', //
      color: Colors.blue, //
    ); //
    // Navigator.pushNamed(context, '/edit_profile'); //
  } //

  /// Fetches the current user's order history.
  Future<void> _fetchOrderHistory() async {
    //
    if (_authToken == null) {
      //
      _showSnackBar(
        //
        'Authentication required to view order history.', //
        color: Colors.orange, //
      ); //
      if (mounted) {
        //
        setState(() {
          //
          _isOrdersLoading = false; //
        }); //
      } //
      return; //
    } //

    setState(() {
      //
      _isOrdersLoading = true; //
    }); //

    try {
      //
      final response =
          await http //
              .get(
                //
                Uri.parse(
                  //
                  '${ApiConfig.baseUrl}/orders/readall', //
                ), // Backend endpoint for reading all user orders
                headers: {
                  //
                  'Content-Type': 'application/json', //
                  'Authorization': 'Bearer $_authToken', // Pass the auth token
                }, //
              ) //
              .timeout(
                //
                const Duration(seconds: 10), //
                onTimeout: () {
                  //
                  throw Exception('Request timeout - Server not responding'); //
                }, //
              ); //

      final data = json.decode(response.body); //

      if (response.statusCode == 200 && data['success'] == true) {
        //
        if (mounted) {
          //
          setState(() {
            //
            _orders = //
                data['data'] ?? //
                []; // Assuming 'data' contains the list of orders
          }); //
        } //
      } else {
        //
        _showSnackBar(
          //
          data['message'] ??
              'Failed to load order history. Please try again.', //
          color: Colors.red, //
        ); //
      } //
    } on SocketException {
      //
      _showSnackBar(
        //
        'Network error. Check your internet connection.', //
        color: Colors.red, //
      ); //
    } on TimeoutException {
      //
      _showSnackBar(
        //
        'Request timed out. Server is not responding.', //
        color: Colors.red, //
      ); //
    } on FormatException {
      //
      _showSnackBar('Invalid response from server.', color: Colors.red); //
    } catch (e) {
      //
      _showSnackBar(
        //
        'An unexpected error occurred while fetching orders: ${e.toString()}', //
        color: Colors.red, //
      ); //
    } finally {
      //
      if (mounted) {
        //
        setState(() {
          //
          _isOrdersLoading = false; //
        }); //
      } //
    } //
  } //

  @override
  Widget build(BuildContext context) {
    //
    return Scaffold(
      //
      appBar: AppBar(
        //
        title: const Text('My Profile'), //
        backgroundColor: const Color(0xFF00BF63), //
        foregroundColor: Colors.white, //
        actions: [
          //
          IconButton(
            //
            icon: const Icon(Icons.edit), //
            tooltip: 'Edit Profile', //
            onPressed: _editProfile, //
          ), //
        ], //
      ), //
      body:
          _isLoading //
          ? const Center(child: CircularProgressIndicator()) //
          : _currentUser ==
                null //
          ? Center(
              //
              child: Column(
                //
                mainAxisAlignment: MainAxisAlignment.center, //
                children: [
                  //
                  Icon(Icons.person_off, size: 80, color: Colors.grey[400]), //
                  const SizedBox(height: 20), //
                  Text(
                    //
                    'No user data found. Please log in.', //
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]), //
                  ), //
                  const SizedBox(height: 20), //
                  ElevatedButton(
                    //
                    onPressed: () {
                      //
                      Navigator.pushReplacementNamed(context, '/login'); //
                    }, //
                    style: ElevatedButton.styleFrom(
                      //
                      backgroundColor: const Color(0xFF00BF63), //
                      foregroundColor: Colors.white, //
                      padding: const EdgeInsets.symmetric(
                        //
                        horizontal: 30, //
                        vertical: 15, //
                      ), //
                      shape: RoundedRectangleBorder(
                        //
                        borderRadius: BorderRadius.circular(10), //
                      ), //
                    ), //
                    child: const Text('Go to Login'), //
                  ), //
                ], //
              ), //
            ) //
          : ResponsiveBuilder(
              //
              builder: (context, deviceType) {
                //
                bool isLargeScreen = //
                    deviceType == DeviceType.desktop || //
                    deviceType == DeviceType.tablet; //

                return isLargeScreen //
                    ? _buildDesktopLayout(deviceType) //
                    : _buildMobileTabletLayout(deviceType); //
              }, //
            ), //
    ); //
  } //

  // Desktop/Tablet Layout with Sidebar
  Widget _buildDesktopLayout(DeviceType deviceType) {
    //
    double padding = 40.0; //
    return Row(
      //
      crossAxisAlignment: CrossAxisAlignment.start, //
      children: [
        //
        // Sidebar Navigation
        Container(
          //
          width: 250, // Fixed width for sidebar
          padding: EdgeInsets.all(padding / 2), //
          decoration: BoxDecoration(
            //
            color: Colors.white, //
            borderRadius: BorderRadius.circular(15), //
            boxShadow: [
              //
              BoxShadow(
                //
                color: Colors.black.withOpacity(0.05), //
                blurRadius: 5, //
                offset: const Offset(2, 0), //
              ), //
            ], //
          ), //
          child: Column(
            //
            crossAxisAlignment: CrossAxisAlignment.start, //
            children: [
              //
              _buildSidebarItem(
                //
                Icons.person, //
                'Profile Details', //
                ProfileSection.details, //
              ), //
              _buildSidebarItem(
                //
                Icons.history, //
                'Order History', //
                ProfileSection.orders, //
              ), //
              _buildSidebarItem(
                //
                Icons.location_on, //
                'Address', //
                ProfileSection.address, //
              ), //
            ], //
          ), //
        ), //
        SizedBox(width: padding), //
        // Main Content Area
        Expanded(
          //
          child: SingleChildScrollView(
            //
            padding: EdgeInsets.all(padding), //
            child: Container(
              //
              decoration: BoxDecoration(
                //
                color: Colors.white, //
                borderRadius: BorderRadius.circular(15), //
                boxShadow: [
                  //
                  BoxShadow(
                    //
                    color: Colors.black.withOpacity(0.1), //
                    blurRadius: 10, //
                    offset: const Offset(0, 5), //
                  ), //
                ], //
              ), //
              child: _buildCurrentSectionContent(deviceType), //
            ), //
          ), //
        ), //
      ], //
    ); //
  } //

  // Mobile/Tablet Layout with Tabs
  Widget _buildMobileTabletLayout(DeviceType deviceType) {
    //
    double padding = 20.0; //
    return Column(
      //
      children: [
        //
        // Tab Bar
        Container(
          //
          color: Colors.white, //
          child: TabBar(
            //
            controller: DefaultTabController.of(
              //
              context, //
            ), // Requires DefaultTabController
            labelColor: const Color(0xFF00BF63), //
            unselectedLabelColor: Colors.grey, //
            indicatorColor: const Color(0xFF00BF63), //
            tabs: const [
              //
              Tab(icon: Icon(Icons.person), text: 'Profile'), //
              Tab(icon: Icon(Icons.history), text: 'Orders'), //
              Tab(icon: Icon(Icons.location_on), text: 'Address'), //
            ], //
            onTap: (index) {
              //
              setState(() {
                //
                _currentSection = ProfileSection.values[index]; //
              }); //
            }, //
          ), //
        ), //
        Expanded(
          //
          child: SingleChildScrollView(
            //
            padding: EdgeInsets.all(padding), //
            child: Container(
              //
              decoration: BoxDecoration(
                //
                color: Colors.white, //
                borderRadius: BorderRadius.circular(15), //
                boxShadow: [
                  //
                  BoxShadow(
                    //
                    color: Colors.black.withOpacity(0.1), //
                    blurRadius: 10, //
                    offset: const Offset(0, 5), //
                  ), //
                ], //
              ), //
              child: _buildCurrentSectionContent(deviceType), //
            ), //
          ), //
        ), //
      ], //
    ); //
  } //

  // Helper for Sidebar items
  Widget _buildSidebarItem(
    //
    IconData icon, //
    String title, //
    ProfileSection section, //
  ) {
    //
    bool isSelected = _currentSection == section; //
    return ListTile(
      //
      leading: Icon(
        //
        icon, //
        color: isSelected ? const Color(0xFF00BF63) : Colors.grey[700], //
      ), //
      title: Text(
        //
        title, //
        style: TextStyle(
          //
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, //
          color: isSelected ? const Color(0xFF00BF63) : Colors.black87, //
        ), //
      ), //
      selected: isSelected, //
      selectedTileColor: const Color(0xFF00BF63).withOpacity(0.1), //
      onTap: () {
        //
        setState(() {
          //
          _currentSection = section; //
        }); //
      }, //
    ); //
  } //

  // Renders the content based on the current selected section
  Widget _buildCurrentSectionContent(DeviceType deviceType) {
    //
    switch (_currentSection) {
      //
      case ProfileSection.details: //
        return _buildProfileDetailsSection(
          //
          deviceType == DeviceType.desktop ||
              deviceType == DeviceType.tablet, //
        ); //
      case ProfileSection.orders: //
        return _buildOrderHistorySection(
          //
          deviceType == DeviceType.desktop ||
              deviceType == DeviceType.tablet, //
        ); //
      case ProfileSection.address: //
        return _buildAddressSection(
          //
          deviceType == DeviceType.desktop ||
              deviceType == DeviceType.tablet, //
        ); //
      default: //
        return const Center(child: Text('Select a section')); //
    } //
  } //

  // New Widget to build the Profile Details Section
  Widget _buildProfileDetailsSection(bool isLargeScreen) {
    //
    double avatarRadius = isLargeScreen ? 60 : 40; //
    double spacing = isLargeScreen ? 30 : 20; //

    return Padding(
      //
      padding: EdgeInsets.all(
        //
        isLargeScreen ? 40.0 : 20.0, //
      ), // Consistent padding
      child: Column(
        //
        crossAxisAlignment: CrossAxisAlignment.start, //
        children: [
          //
          Center(
            //
            child: CircleAvatar(
              //
              radius: avatarRadius, //
              backgroundColor: const Color(0xFF00BF63), //
              child: Icon(
                //
                Icons.person, //
                size: isLargeScreen ? 70 : 50, //
                color: Colors.white, //
              ), //
            ), //
          ), //
          SizedBox(height: spacing), //
          _buildProfileInfoRow('Username', _currentUser!.username), //
          _buildDivider(), //
          _buildProfileInfoRow('Full Name', _currentUser!.fullname), //
          _buildDivider(), //
          _buildProfileInfoRow('Email', _currentUser!.email), //
          _buildDivider(), //
          _buildProfileInfoRow('Phone', _currentUser!.phone), //
          _buildDivider(), //
          _buildProfileInfoRow('Date of Birth', _currentUser!.dob), //
          _buildDivider(), //
          _buildProfileInfoRow('Role', _currentUser!.user_role), //
        ], //
      ), //
    ); //
  } //

  // New Widget to build the Address Section
  Widget _buildAddressSection(bool isLargeScreen) {
    //
    return Padding(
      //
      padding: EdgeInsets.all(
        //
        isLargeScreen ? 40.0 : 20.0, //
      ), // Consistent padding
      child: Column(
        //
        crossAxisAlignment: CrossAxisAlignment.start, //
        children: [
          //
          const Text(
            //
            'My Address', //
            style: TextStyle(
              //
              fontSize: 22, //
              fontWeight: FontWeight.bold, //
              color: Colors.black87, //
            ), //
          ), //
          const SizedBox(height: 20), //
          _buildProfileInfoRow(
            //
            'Address Line', //
            _currentUser!.address_line ?? 'N/A', //
          ), // Assuming address_line is now 'address'
          _buildDivider(), //
          _buildProfileInfoRow('City', _currentUser!.city ?? 'N/A'), //
          _buildDivider(), //
          _buildProfileInfoRow('Township', _currentUser!.township ?? 'N/A'), //
          _buildDivider(), //
          _buildProfileInfoRow(
            //
            'Postal Code', //
            _currentUser!.postal_code ?? 'N/A', //
          ), //
          const SizedBox(height: 30), //
          Center(
            //
            child: ElevatedButton.icon(
              //
              onPressed: () {
                //
                _showSnackBar(
                  //
                  'Edit Address functionality coming soon!', //
                  color: Colors.blue, //
                ); //
              }, //
              icon: const Icon(Icons.edit_location_alt), //
              label: const Text('Edit Address'), //
              style: ElevatedButton.styleFrom(
                //
                backgroundColor: const Color(0xFF00BF63), //
                foregroundColor: Colors.white, //
                padding: const EdgeInsets.symmetric(
                  //
                  horizontal: 25, //
                  vertical: 12, //
                ), //
                shape: RoundedRectangleBorder(
                  //
                  borderRadius: BorderRadius.circular(10), //
                ), //
              ), //
            ), //
          ), //
        ], //
      ), //
    ); //
  } //

  // Modified _buildProfileInfoRow to accept nullable String and handle empty/null
  Widget _buildProfileInfoRow(String label, String? value) {
    //
    // Determine the display value: if null or empty, show 'N/A', otherwise show the value
    final displayValue = (value == null || value.isEmpty) ? 'N/A' : value; //

    return Padding(
      //
      padding: const EdgeInsets.symmetric(vertical: 8.0), //
      child: Column(
        //
        crossAxisAlignment: CrossAxisAlignment.start, //
        children: [
          //
          Text(
            //
            label, //
            style: TextStyle(
              //
              fontSize: 14, //
              fontWeight: FontWeight.bold, //
              color: Colors.grey[600], //
            ), //
          ), //
          const SizedBox(height: 4), //
          Text(
            //
            displayValue, // Use the determined displayValue
            style: const TextStyle(fontSize: 18, color: Colors.black87), //
          ), //
        ], //
      ), //
    ); //
  } //

  Widget _buildDivider() {
    //
    return Divider(color: Colors.grey[300], thickness: 1); //
  } //

  // Existing Widget to build the Order History Section
  Widget _buildOrderHistorySection(bool isLargeScreen) {
    //
    return Padding(
      //
      padding: EdgeInsets.all(
        //
        isLargeScreen ? 40.0 : 20.0, //
      ), // Consistent padding
      child: Column(
        //
        crossAxisAlignment: CrossAxisAlignment.start, //
        children: [
          //
          const Text(
            //
            'Order History', //
            style: TextStyle(
              //
              fontSize: 22, //
              fontWeight: FontWeight.bold, //
              color: Colors.black87, //
            ), //
          ), //
          const SizedBox(height: 15), //
          _isOrdersLoading //
              ? const Center(child: CircularProgressIndicator()) //
              : _orders
                    .isEmpty //
              ? Center(
                  //
                  child: Text(
                    //
                    'No orders found.', //
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]), //
                  ), //
                ) //
              : ListView.builder(
                  //
                  shrinkWrap: true, //
                  physics: //
                      const NeverScrollableScrollPhysics(), // To allow parent SingleChildScrollView to scroll
                  itemCount:
                      _orders.length >
                          3 //
                      ? 3 //
                      : _orders.length, // Show max 3 recent orders
                  itemBuilder: (context, index) {
                    //
                    final order = _orders[index]; //
                    return Card(
                      //
                      margin: const EdgeInsets.symmetric(vertical: 8.0), //
                      elevation: 2, //
                      shape: RoundedRectangleBorder(
                        //
                        borderRadius: BorderRadius.circular(10), //
                      ), //
                      child: Padding(
                        //
                        padding: const EdgeInsets.all(12.0), //
                        child: Column(
                          //
                          crossAxisAlignment: CrossAxisAlignment.start, //
                          children: [
                            //
                            Text(
                              //
                              'Order ID: ${order['order_id'] ?? 'N/A'}', // Assuming 'id' from your backend JSON
                              style: const TextStyle(
                                //
                                fontWeight: FontWeight.bold, //
                                fontSize: 16, //
                              ), //
                            ), //
                            const SizedBox(height: 5), //
                            Text(
                              //
                              'Total Amount: ${double.tryParse(order['total_amount'].toString())?.toStringAsFixed(2) ?? '0.00'} Kyats', // Assuming final_total_price
                              style: const TextStyle(
                                //
                                color: Colors.green, //
                                fontSize: 15, //
                              ), //
                            ), //
                            const SizedBox(height: 5), //
                            Text(
                              //
                              'Status: ${order['status'] ?? 'N/A'}', //
                              style: TextStyle(
                                //
                                color:
                                    order['status'] ==
                                        'done' //
                                    ? Colors
                                          .green //
                                    : Colors.orange, //
                                fontSize: 15, //
                              ), //
                            ), //
                            const SizedBox(height: 5), //
                            Text(
                              //
                              'Date: ${order['created_date'] != null ? (order['created_date'] as String).split(' ')[0] : 'N/A'}', //
                              style: TextStyle(
                                //
                                fontSize: 14, //
                                color: Colors.grey[700], //
                              ), //
                            ), //
                            // Add this conditional rendering for the "Pay Now" button
                            if (order['status'] == 'approved') //
                              Align(
                                //
                                alignment: Alignment.bottomRight, //
                                child: ElevatedButton(
                                  //
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PaymentScreen(
                                          orderId: order['order_id']!,
                                          amount: order['total_amount']!,
                                        ),
                                      ),
                                    );
                                  }, //
                                  style: ElevatedButton.styleFrom(
                                    //
                                    backgroundColor: //
                                    const Color(
                                      0xFF00BF63,
                                    ), //
                                    foregroundColor: Colors.white, //
                                  ), //
                                  child: const Text('Pay Now'), //
                                ), //
                              ), //
                            Align(
                              //
                              alignment: Alignment.bottomRight, //
                              child: TextButton(
                                //
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrderDetailScreen(
                                        orderId: order['order_id']!,
                                      ),
                                    ),
                                  );
                                }, //
                                child: const Text('View Details'), //
                              ), //
                            ), //
                          ], //
                        ), //
                      ), //
                    ); //
                  }, //
                ), //
          if (_orders.length > //
              3) // Show "View All" button only if more than 3 orders
            Padding(
              //
              padding: const EdgeInsets.only(top: 15.0), //
              child: Center(
                //
                child: ElevatedButton(
                  //
                  onPressed: () {
                    //
                    _showSnackBar(
                      //
                      'View All Orders functionality coming soon!', //
                      color: Colors.blue, //
                    ); //
                    // Navigator.pushNamed(context, '/orders_list'); // Navigate to a dedicated orders list page
                  }, //
                  style: ElevatedButton.styleFrom(
                    //
                    backgroundColor: const Color(0xFF00BF63), //
                    foregroundColor: Colors.white, //
                    padding: const EdgeInsets.symmetric(
                      //
                      horizontal: 25, //
                      vertical: 12, //
                    ), //
                    shape: RoundedRectangleBorder(
                      //
                      borderRadius: BorderRadius.circular(10), //
                    ), //
                  ), //
                  child: const Text('View All Orders'), //
                ), //
              ), //
            ), //
        ], //
      ), //
    ); //
  } //
}
