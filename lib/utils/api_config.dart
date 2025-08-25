// lib/utils/api_config.dart
class ApiConfig {
  // Base URL for your API
  static const String baseUrl = 'https://gmmshoppingmall.com/api';

  // For local development, use:
  // static const String baseUrl = 'http://localhost/your-project/api';
  // static const String baseUrl = 'http://10.0.2.2/your-project/api'; // For Android emulator

  // API Endpoints
  static const String loginEndpoint = '$baseUrl/auth/login';

  // Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  // Common headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers with authorization token
  static Map<String, String> getAuthHeaders(String token) => {
    ...headers,
    'Authorization': 'Bearer $token',
  };
}
