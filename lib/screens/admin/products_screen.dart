import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Required for MultipartFile
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path; // To get the file extension

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import '../../../widgets/sidebar_widget.dart';

// The enum to manage the current view state of the screen
enum ProductView { list, create, edit, read }

class WebProductsScreen extends StatefulWidget {
  const WebProductsScreen({super.key});

  @override
  State<WebProductsScreen> createState() => _WebProductsScreenState();
}

class _WebProductsScreenState extends State<WebProductsScreen> {
  static const double _kSidebarWidth = 256.0;
  static const double _kAppBarHeight = kToolbarHeight;

  ProductView _currentView = ProductView.list;
  int? _editingProductId;
  final List<Map<String, dynamic>> _products = [];
  bool _productsLoading = true;
  bool _isFetchingProduct = false;
  final List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  // Key for Scaffold to control the Drawer (only used for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar on large screens
  bool _isSidebarOpen = true;

  // Placeholder for user details
  String? _currentUserRole;

  // Text controllers for the product form
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _inStockController = TextEditingController();
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchCategories();
    _fetchProducts();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _salePriceController.dispose();
    _inStockController.dispose();
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
        _currentUserRole = user?.user_role;
      });
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/category/readall'),
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
              _categories.addAll(
                List<Map<String, dynamic>>.from(data['data']).cast(),
              );
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error fetching categories: ${e.toString()}',
          color: Colors.red,
        );
      }
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _productsLoading = true;
      _products.clear();
    });
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/product/readall'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          if (mounted) {
            setState(() {
              _products.addAll(
                List<Map<String, dynamic>>.from(data['data']).cast(),
              );
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(
              context,
              data['message'] ?? 'Failed to load products.',
            );
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ?? 'Failed to load products.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error fetching products: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _productsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchProductDetails(int productId) async {
    setState(() {
      _isFetchingProduct = true;
      _resetForm();
    });
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/product/read/$productId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          final product = Map<String, dynamic>.from(data['data']);
          _populateFormWithProduct(product);
          if (mounted) {
            setState(() {
              _currentView = ProductView.read;
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(context, 'Product not found.', color: Colors.red);
            setState(() {
              _currentView = ProductView.list;
            });
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ?? 'Failed to fetch product.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error fetching product: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingProduct = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _createProduct() async {
    if (_productNameController.text.isEmpty ||
        _salePriceController.text.isEmpty ||
        _inStockController.text.isEmpty ||
        _selectedCategoryId == null ||
        _pickedFile == null) {
      _showSnackBar(
        context,
        'Please fill in all required fields and upload an image.',
        color: Colors.orange,
      );
      return;
    }

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      var uri = Uri.parse('${ApiConfig.baseUrl}/product/create');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Authorization': 'Bearer $token'});

      request.fields['product_name'] = _productNameController.text;
      request.fields['product_description'] =
          _productDescriptionController.text;
      request.fields['category_id'] = _selectedCategoryId!.toString();
      request.fields['sale_price'] = _salePriceController.text;
      request.fields['in_stock'] = _inStockController.text;

      if (_pickedFile != null && _pickedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'product_image',
            _pickedFile!.bytes!,
            filename: _pickedFile!.name,
            contentType: MediaType(
              'image',
              path.extension(_pickedFile!.name).substring(1),
            ),
          ),
        );
      }

      var response = await request.send();

      if (response.statusCode == 201) {
        _showSnackBar(
          context,
          'Product created successfully!',
          color: Colors.green,
        );
        _fetchProducts();
        setState(() {
          _resetForm();
          _currentView = ProductView.list;
        });
      } else {
        var responseBody = await response.stream.bytesToString();
        final errorData = json.decode(responseBody);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to create product.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error creating product: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  Future<void> _updateProduct() async {
    if (_productNameController.text.isEmpty ||
        _salePriceController.text.isEmpty ||
        _inStockController.text.isEmpty ||
        _selectedCategoryId == null ||
        _editingProductId == null) {
      _showSnackBar(
        context,
        'Please fill in all required fields.',
        color: Colors.orange,
      );
      return;
    }

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      var uri = Uri.parse(
        '${ApiConfig.baseUrl}/product/update/$_editingProductId',
      );
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({'Authorization': 'Bearer $token'});

      request.fields['product_name'] = _productNameController.text;
      request.fields['product_description'] =
          _productDescriptionController.text;
      request.fields['category_id'] = _selectedCategoryId!.toString();
      request.fields['sale_price'] = _salePriceController.text;
      request.fields['in_stock'] = _inStockController.text;

      if (_pickedFile != null && _pickedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'product_image',
            _pickedFile!.bytes!,
            filename: _pickedFile!.name,
            contentType: MediaType(
              'image',
              path.extension(_pickedFile!.name).substring(1),
            ),
          ),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'Product updated successfully!',
          color: Colors.green,
        );
        _fetchProducts();
        setState(() {
          _resetForm();
          _currentView = ProductView.list;
        });
      } else {
        var responseBody = await response.stream.bytesToString();
        final errorData = json.decode(responseBody);
        _showSnackBar(
          context,
          errorData['message'] ?? 'Failed to update product.',
          color: Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error updating product: ${e.toString()}',
        color: Colors.red,
      );
    }
  }

  Future<void> _deleteProduct(int productId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null) return;

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/product/delete/$productId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _showSnackBar(
          context,
          'Product deleted successfully!',
          color: Colors.green,
        );
        _fetchProducts();
      } else {
        if (mounted) {
          _showSnackBar(
            context,
            json.decode(response.body)['message'] ??
                'Failed to delete product.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error deleting product: ${e.toString()}',
          color: Colors.red,
        );
      }
    }
  }

  void _resetForm() {
    _editingProductId = null;
    _productNameController.clear();
    _productDescriptionController.clear();
    _salePriceController.clear();
    _inStockController.clear();
    _selectedCategoryId = null;
    _pickedFile = null;
  }

  void _populateFormWithProduct(Map<String, dynamic> product) {
    _editingProductId = product['id'];
    _productNameController.text = product['product_name'] ?? '';
    _productDescriptionController.text = product['product_description'] ?? '';
    // Corrected line: convert the price to a string
    _salePriceController.text = product['sale_price']?.toString() ?? '';
    _inStockController.text = product['in_stock']?.toString() ?? '';
    _selectedCategoryId = product['category_id'];
    _pickedFile = null; // Clear the picked file when populating
  }

  void _handleViewDetails(int productId) async {
    await _fetchProductDetails(productId);
  }

  void _handleEditProduct(Map<String, dynamic> product) {
    _populateFormWithProduct(product);
    setState(() {
      _currentView = ProductView.edit;
    });
  }

  void _handleDeleteProduct(int productId) {
    _showConfirmationDialog(
      context,
      title: 'Delete Product',
      content: 'Are you sure you want to delete this product?',
      onConfirm: () async {
        await _deleteProduct(productId);
      },
    );
  }

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

  void _submitForm() async {
    if (_editingProductId == null) {
      await _createProduct();
    } else {
      await _updateProduct();
    }
  }

  Widget _buildProductTable() {
    if (_productsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No products found.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {
                _resetForm();
                _currentView = ProductView.create;
              }),
              child: const Text("Create Product"),
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
                      _currentView = ProductView.create;
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text("Create Product"),
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
                      DataColumn(label: Text('Product Image')),
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('In Stock')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _products.map((product) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Image.network(
                              '${ApiConfig.baseUrl}/${product['product_image']}' ??
                                  'https://via.placeholder.com/150', // Use a placeholder if no image URL is available
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                            ),
                          ),
                          DataCell(Text(product['product_name'] ?? 'N/A')),
                          DataCell(Text(product['category_name'] ?? 'N/A')),
                          DataCell(Text(product['sale_price'] ?? 'N/A')),
                          DataCell(
                            Text(product['in_stock']?.toString() ?? 'N/A'),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  tooltip: 'View Details',
                                  onPressed: () =>
                                      _handleViewDetails(product['id']!),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit Product',
                                  onPressed: () => _handleEditProduct(product),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete Product',
                                  onPressed: () =>
                                      _handleDeleteProduct(product['id']!),
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

  Widget _buildForm() {
    final isReadOnly = _currentView == ProductView.read;
    final formTitle = _currentView == ProductView.create
        ? 'Create New Product'
        : _currentView == ProductView.edit
        ? 'Edit Product'
        : 'Product Details';

    if (_isFetchingProduct) {
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
                controller: _productNameController,
                readOnly: isReadOnly,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _productDescriptionController,
                readOnly: isReadOnly,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Product Description',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _salePriceController,
                readOnly: isReadOnly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sale Price'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inStockController,
                readOnly: isReadOnly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'In Stock'),
              ),
              const SizedBox(height: 16),
              if (isReadOnly)
                Text(
                  'Category: ${_categories.firstWhere((cat) => cat['id'] == _selectedCategoryId, orElse: () => {'category_name': 'N/A'})['category_name']}',
                  style: Theme.of(context).textTheme.titleMedium,
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  hint: const Text('Select Category'),
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedCategoryId = newValue;
                    });
                  },
                  items: _categories.map<DropdownMenuItem<int>>((
                    Map<String, dynamic> category,
                  ) {
                    return DropdownMenuItem<int>(
                      value: category['id'],
                      child: Text(category['category_name']),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              if (!isReadOnly)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('Select Product Image'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _pickedFile?.name ?? 'No file selected',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (_currentView == ProductView.read &&
                  _products.firstWhere(
                        (p) => p['id'] == _editingProductId,
                      )['product_image'] !=
                      null)
                Image.network(
                  '${ApiConfig.baseUrl}/${_products.firstWhere((p) => p['id'] == _editingProductId)['product_image']}',
                  height: 200,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_currentView == ProductView.read) {
                        setState(() {
                          _resetForm();
                          _currentView = ProductView.list;
                        });
                      } else {
                        _submitForm();
                      }
                    },
                    child: Text(
                      _currentView == ProductView.read
                          ? 'Back to List'
                          : (_editingProductId == null
                                ? 'Create Product'
                                : 'Update Product'),
                    ),
                  ),
                  if (_currentView != ProductView.read) ...[
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _resetForm();
                          _currentView = ProductView.list;
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
                      child: _currentView == ProductView.list
                          ? _productsLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _products.isEmpty
                                ? const Center(
                                    child: Text('No products found.'),
                                  )
                                : _buildProductTable()
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
}
