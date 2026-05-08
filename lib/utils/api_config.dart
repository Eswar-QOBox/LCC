class ApiConfig {
  // JHipster Spring Boot backend
  // Change to your server IP for LAN testing: 'http://192.168.1.100:8080'
  static const String baseUrl = 'http://192.168.1.5:8080';

  static const List<String> supportedLoanTypes = [
    'Personal Loan',
    'Business Loan',
    'Professional Loan',
    'Education Loan',
    'Home Loan',
    'Car Loan',
    'Mortgage',
    'Loan Against Property',
    'Emergency Loan',
  ];

  // JHipster API endpoints
  static const String loginEndpoint = '/api/authenticate';
  static const String meEndpoint = '/api/account';
  static const String usersEndpoint = '/api/admin/users';
  static const String leadsEndpoint = '/api/leads';
  static const String loanSubmissionsEndpoint = '/api/loan-submissions';
  static const String leadDocumentsEndpoint = '/api/lead-documents';
  // Multipart upload endpoint — use this for all file uploads from Flutter
  static const String leadDocumentsUploadEndpoint = '/api/lead-documents/upload';
  static const String activityLogsEndpoint = '/api/activity-logs';
  static const String forgotPasswordEndpoint = '/api/account/reset-password/init';
}
