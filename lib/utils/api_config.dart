class ApiConfig {
  // 🚀 PRODUCTION: Base URL for authentication and main API
  static const String baseUrl = 'https://ai-lazycallagent.qualityoutsidethebox.org';
  
  // API endpoints (these are appended to baseUrl for auth/main API)
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String refreshEndpoint = '/api/v1/auth/refresh';
  static const String meEndpoint = '/api/v1/auth/me';
  static const String usersEndpoint = '/api/v1/users';
  static const String leadsEndpoint = '/api/v1/leads';
}
