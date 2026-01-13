class ApiConfig {
  // Base URL for the API
  // Update this to match your production backend URL
  // Note: If your backend serves API at root, use 'http://localhost:8081'
  // If your backend serves API at /api/v1, use 'http://localhost:8081/api/v1'
  static const String baseUrl =
      'https://ai-lazycallagent.qualityoutsidethebox.org';

  // API endpoints (these are appended to baseUrl)
  // If baseUrl includes /api/v1, use '/auth/login'
  // If baseUrl doesn't include /api/v1, use '/api/v1/auth/login'
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String refreshEndpoint = '/api/v1/auth/refresh';
  static const String meEndpoint = '/api/v1/auth/me';
  static const String usersEndpoint = '/api/v1/users';
  static const String leadsEndpoint = '/api/v1/leads';
}
