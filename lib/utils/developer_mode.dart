import 'package:shared_preferences/shared_preferences.dart';

const String _developerModeKey = 'developer_mode';
const String _professionalLoanAppIdKey = 'professional_loan_application_id';

/// Returns true when developer mode is on (allows multiple applications).
Future<bool> isDeveloperModeEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_developerModeKey) ?? false;
}

/// Turn developer mode on or off.
Future<void> setDeveloperModeEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_developerModeKey, value);
}

/// Store application ID when we create a Professional Loan (backend stores it as Personal Loan).
Future<void> setProfessionalLoanApplicationId(String? applicationId) async {
  final prefs = await SharedPreferences.getInstance();
  if (applicationId == null || applicationId.isEmpty) {
    await prefs.remove(_professionalLoanAppIdKey);
  } else {
    await prefs.setString(_professionalLoanAppIdKey, applicationId);
  }
}

/// Check if this application was created as Professional Loan (so we can restore loanType when loading from backend).
Future<bool> isProfessionalLoanApplicationId(String applicationId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_professionalLoanAppIdKey) == applicationId;
}
