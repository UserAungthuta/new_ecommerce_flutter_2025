import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
// Note: This example assumes a sidebar widget exists, but for simplicity,
// the full sidebar from products_screen.dart is not included here.
// You can integrate it as needed.

// Enum to manage the current view state of the screen
enum OrderView { list, edit }

class WebOrdersScreen extends StatefulWidget {
  const WebOrdersScreen({super.key});

  @override
  State<WebOrdersScreen> createState() => _WebOrdersScreenState();
}

class _WebOrdersScreenState extends State<WebOrdersScreen> {
  static const double _kSidebarWidth = 256.0;
  static const double _kAppBarHeight = kToolbarHeight;

  OrderView _currentView = OrderView.list;
  int? _editingOrderId;
  final List<Map<String, dynamic>> _orders = [];
  bool _ordersLoading = true;
  Map<String, dynamic>? _editingOrderDetails;

  // Key for Scaffold to control the Drawer (for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar
  bool _isSidebarOpen = true;

  // Placeholder for user details
  String? _currentUserRole;

  // State variables for payment details
  Map<String, dynamic>? _paymentDetails;
  bool _paymentDetailsLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchOrders();
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

  // Fetches all orders from the API
  Future<void> _fetchOrders() async {
    setState(() {
      _ordersLoading = true;
      _orders.clear();
    });
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/orders/admin-orders'),
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
              _orders.addAll(
                List<Map<String, dynamic>>.from(data['data']).cast(),
              );
            });
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ?? 'Failed to load orders.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error fetching orders: ${e.toString()}',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _ordersLoading = false;
        });
      }
    }
  }

  // Fetches payment details for a specific order
  Future<void> _fetchPaymentDetails(int orderId) async {
    setState(() {
      _paymentDetailsLoading = true;
    });
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/payment/order/$orderId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _paymentDetails = data['data'];
          });
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _paymentDetails = {}; // No payment found
          });
        }
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ??
                'Failed to load payment details.',
            color: Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error fetching payment details: ${e.toString()}',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _paymentDetailsLoading = false;
        });
      }
    }
  }

  // Updates an existing order's status via API
  Future<void> _updateOrderStatus(String newStatus) async {
    if (_editingOrderId == null || newStatus.isEmpty) {
      _showSnackBar(context, 'Invalid order or status.', color: Colors.orange);
      return;
    }

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/orders/status/$_editingOrderId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'Order status updated successfully!',
          color: Colors.green,
        );
        _fetchOrders();
        setState(() {
          _resetForm();
          _currentView = OrderView.list;
        });
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ??
                'Failed to update order status.',
            color: Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error updating order status: ${e.toString()}',
          color: Colors.red,
        );
      }
    }
  }

  // Deletes an order via API
  Future<void> _deleteOrder(int orderId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/order/delete/$orderId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'Order deleted successfully!',
          color: Colors.green,
        );
        _fetchOrders();
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ?? 'Failed to delete order.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error deleting order: ${e.toString()}',
          color: Colors.red,
        );
      }
    }
  }

  // Resets the form to its initial state
  void _resetForm() {
    _editingOrderId = null;
    _editingOrderDetails = null;
    _paymentDetails = null;
  }

  // Action handler for editing an order
  void _handleEditOrder(Map<String, dynamic> order) {
    setState(() {
      _editingOrderId = order['order_id'];
      _editingOrderDetails = order;
      _currentView = OrderView.edit;
      _paymentDetails = null; // Clear previous details
    });
    // Conditionally fetch payment details
    if (order['status'] != 'pending' && order['status'] != 'approved') {
      _fetchPaymentDetails(order['order_id']);
    }
  }

  // Action handler for deleting an order
  void _handleDeleteOrder(int orderId) {
    _showConfirmationDialog(
      context,
      title: 'Delete Order',
      content: 'Are you sure you want to delete this order?',
      onConfirm: () async {
        await _deleteOrder(orderId);
      },
    );
  }

  // Builds the table view for orders
  Widget _buildOrderTable() {
    if (_ordersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return const Center(child: Text('No orders found.'));
    }

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Order ID')),
                  DataColumn(label: Text('Customer Name')),
                  DataColumn(label: Text('Total Amount')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _orders.map((order) {
                  return DataRow(
                    cells: [
                      DataCell(Text(order['order_id']?.toString() ?? 'N/A')),
                      DataCell(Text(order['username'] ?? 'N/A')),
                      DataCell(
                        Text(order['total_amount']?.toString() ?? 'N/A'),
                      ),
                      DataCell(
                        Chip(
                          label: Text(
                            order['status'] ?? 'N/A',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _getStatusColor(order['status']),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit Order',
                              onPressed: () => _handleEditOrder(order),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Order',
                              onPressed: () =>
                                  _handleDeleteOrder(order['order_id']!),
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
        ),
      ),
    );
  }

  // Helper to get a color for the order status chip
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'paid':
        return Colors.lime;
      case 'pending':
        return Colors.orange;
      case 'prepare':
        return Colors.blue;
      case 'deliver':
        return Colors.purple;
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Builds the form view for editing orders
  Widget _buildForm() {
    if (_editingOrderDetails == null) {
      return const Center(child: Text('No order selected.'));
    }

    final order = _editingOrderDetails!;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order Details for ID: ${order['order_id']}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              _buildReadOnlyField('Customer', order['username']),
              _buildReadOnlyField('Email', order['email']),
              _buildReadOnlyField(
                'Total Amount',
                '${order['total_amount']}MMK',
              ),
              _buildReadOnlyField('Order Date', order['created_date']),
              _buildReadOnlyField('Current Status', order['status']),
              const SizedBox(height: 24),

              // Display payment details if not pending or approved
              if (order['status'] != 'pending' && order['status'] != 'approved')
                _buildPaymentDetails(),

              const SizedBox(height: 24),
              Text(
                'Update Status:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildStatusButtons(order['status']),
              const SizedBox(height: 24),
              Text(
                'Order Items:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ..._buildOrderItemsList(order['items']),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _resetForm();
                        _currentView = OrderView.list;
                      });
                    },
                    child: const Text('Back to Orders'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds action buttons based on the current order status
  Widget _buildStatusButtons(String? status) {
    if (status == null) {
      return const SizedBox.shrink();
    }

    // Define button configurations for each status
    final Map<String, List<Widget>> buttonActions = {
      'pending': [
        ElevatedButton(
          onPressed: () => _updateOrderStatus('approved'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Approve', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _updateOrderStatus('cancel'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
      ],
      'approved': [
        ElevatedButton(
          onPressed: () => _updateOrderStatus('paid'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.lime),
          child: const Text('Paid', style: TextStyle(color: Colors.white)),
        ),
      ],
      'paid': [
        ElevatedButton(
          onPressed: () => _updateOrderStatus('prepare'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('Prepare', style: TextStyle(color: Colors.white)),
        ),
      ],
      'prepare': [
        ElevatedButton(
          onPressed: () => _updateOrderStatus('deliver'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: const Text('Deliver', style: TextStyle(color: Colors.white)),
        ),
      ],
      'deliver': [
        ElevatedButton(
          onPressed: () => _updateOrderStatus('done'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Done', style: TextStyle(color: Colors.white)),
        ),
      ],
    };

    // Return the configured buttons for the current status,
    // or an empty row if no actions are defined
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: buttonActions[status] ?? [],
    );
  }

  // Builds the payment details section
  Widget _buildPaymentDetails() {
    if (_paymentDetailsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_paymentDetails == null || _paymentDetails!.isEmpty) {
      return const Text('No payment details found for this order.');
    }
    final payment = _paymentDetails!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Payment Details:', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _buildReadOnlyField('Payment Type', payment['payment_type']),
        _buildReadOnlyField('Status', payment['payment_status']),
        _buildReadOnlyField(
          'OTP Verified',
          payment['otp_verified'] ? 'Yes' : 'No',
        ),
        _buildReadOnlyField('Payment Date', payment['created_date']),
        if (payment['payment_transaction_image'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Transaction Image:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Center(
                child: Image.network(
                  '${ApiConfig.baseUrl}/${payment['payment_transaction_image']}',
                  width: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // Helper for read-only fields in the form
  Widget _buildReadOnlyField(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value ?? 'N/A'),
        ],
      ),
    );
  }

  // Helper to build the list of order items
  List<Widget> _buildOrderItemsList(List<dynamic>? items) {
    if (items == null || items.isEmpty) {
      return [const Text('No items in this order.')];
    }
    return items.map((item) {
      return ListTile(
        leading: Image.network(
          '${ApiConfig.baseUrl}/${item['product_image']}',
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image),
        ),
        title: Text('${item['product_name']} x ${item['quantity']}'),
        trailing: Text('${item['item_price']}MMK'),
      );
    }).toList();
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
                  foregroundColor: Colors.blue, // Highlight current screen
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
                      child: _currentView == OrderView.list
                          ? _ordersLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _orders.isEmpty
                                ? const Center(child: Text('No orders found.'))
                                : _buildOrderTable()
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
