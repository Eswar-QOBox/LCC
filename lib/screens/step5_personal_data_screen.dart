import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../models/document_submission.dart';
import '../utils/app_routes.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';
import '../widgets/app_header.dart';

void main() {
  runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SubmissionProvider()),
      ChangeNotifierProvider(create: (_) => ApplicationProvider()),
    ],
    child: MaterialApp(
      home: Step5PersonalDataScreen(),
      ),
    ),
  );
}

class Step5PersonalDataScreen extends StatefulWidget {
  const Step5PersonalDataScreen({super.key});

  @override
  State<Step5PersonalDataScreen> createState() =>
      _Step5PersonalDataScreenState();
}

class _Step5PersonalDataScreenState extends State<Step5PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  
  // Track expanded sections - first section expanded by default
  bool _basicInfoExpanded = true;
  bool _residenceInfoExpanded = false;
  bool _workInfoExpanded = false;
  bool _personalDetailsExpanded = false;
  bool _familyInfoExpanded = false;
  bool _referenceInfoExpanded = false;
  
  // Validation patterns
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _panRegex = RegExp(
    r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
  );
  static final RegExp _aadhaarRegex = RegExp(
    r'^\d{12}$',
  );
  static final RegExp _phoneRegex = RegExp(
    r'^[0-9]{10}$',
  );
  static final RegExp _nameRegex = RegExp(
    r'^[a-zA-Z\s.]+$',
  );
  
  // Input formatters
  final _panFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) {
      final text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (text.length <= 10) {
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      return oldValue;
    },
  );
  
  final _aadhaarFormatter = FilteringTextInputFormatter.digitsOnly;
  final _phoneFormatter = FilteringTextInputFormatter.digitsOnly;
  
  // Basic Information Controllers
  final _nameAsPerAadhaarController = TextEditingController();
  final _panNoController = TextEditingController();
  final _aadhaarNumberController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _personalEmailIdController = TextEditingController();
  DateTime? _dateOfBirth;
  
  // Residence Information Controllers
  final _countryOfResidenceController = TextEditingController();
  final _residenceAddressController = TextEditingController();
  final _residenceTypeController = TextEditingController();
  final _residenceStabilityController = TextEditingController();
  
  // Work Info Controllers (formerly Company Information)
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _workTypeController = TextEditingController();
  final _industryController = TextEditingController();
  final _annualIncomeController = TextEditingController();
  final _totalWorkExperienceController = TextEditingController();
  final _currentCompanyExperienceController = TextEditingController();
  
  // Personal Details Controllers
  final _nationalityController = TextEditingController();
  final _countryOfBirthController = TextEditingController();
  final _occupationController = TextEditingController();
  final _educationalQualificationController = TextEditingController();
  
  // Loan Details Controllers
  final _loanAmountController = TextEditingController();
  final _loanTenureController = TextEditingController();
  final _currentEmiController = TextEditingController();
  final _existingLoansController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _creditScoreController = TextEditingController();
  
  // Family Information Controllers
  String? _maritalStatus;
  final _spouseNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  
  // Reference 1 Controllers
  final _reference1NameController = TextEditingController();
  final _reference1AddressController = TextEditingController();
  final _reference1ContactController = TextEditingController();
  
  // Reference 2 Controllers
  final _reference2NameController = TextEditingController();
  final _reference2AddressController = TextEditingController();
  final _reference2ContactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _addTextControllersListeners();
  }

  void _addTextControllersListeners() {
    // Add listeners to update summaries in real-time
    void updateSummary() {
      if (mounted) {
        setState(() {});
      }
    }

    _nameAsPerAadhaarController.addListener(updateSummary);
    _panNoController.addListener(updateSummary);
    _aadhaarNumberController.addListener(updateSummary);
    _mobileNumberController.addListener(updateSummary);
    _personalEmailIdController.addListener(updateSummary);
    _countryOfResidenceController.addListener(updateSummary);
    _residenceAddressController.addListener(updateSummary);
    _residenceTypeController.addListener(updateSummary);
    _residenceStabilityController.addListener(updateSummary);
    _companyNameController.addListener(updateSummary);
    _companyAddressController.addListener(updateSummary);
    _nationalityController.addListener(updateSummary);
    _countryOfBirthController.addListener(updateSummary);
    _occupationController.addListener(updateSummary);
    _educationalQualificationController.addListener(updateSummary);
    _workTypeController.addListener(updateSummary);
    _industryController.addListener(updateSummary);
    _annualIncomeController.addListener(updateSummary);
    _totalWorkExperienceController.addListener(updateSummary);
    _currentCompanyExperienceController.addListener(updateSummary);
    _loanAmountController.addListener(updateSummary);
    _loanTenureController.addListener(updateSummary);
    _currentEmiController.addListener(updateSummary);
    _existingLoansController.addListener(updateSummary);
    _monthlyIncomeController.addListener(updateSummary);
    _creditScoreController.addListener(updateSummary);
    _spouseNameController.addListener(updateSummary);
    _fatherNameController.addListener(updateSummary);
    _motherNameController.addListener(updateSummary);
    _reference1NameController.addListener(updateSummary);
    _reference1AddressController.addListener(updateSummary);
    _reference1ContactController.addListener(updateSummary);
    _reference2NameController.addListener(updateSummary);
    _reference2AddressController.addListener(updateSummary);
    _reference2ContactController.addListener(updateSummary);
  }

  void _loadExistingData() {
    try {
      // First try to load from backend
      final appProvider = context.read<ApplicationProvider>();
      if (appProvider.hasApplication && appProvider.currentApplication!.step5PersonalData != null) {
        final stepData = appProvider.currentApplication!.step5PersonalData as Map<String, dynamic>;
        _nameAsPerAadhaarController.text = stepData['nameAsPerAadhaar'] ?? '';
        _panNoController.text = stepData['panNo'] ?? '';
        _aadhaarNumberController.text = stepData['aadhaarNumber'] ?? '';
        _mobileNumberController.text = stepData['mobileNumber'] ?? '';
        _personalEmailIdController.text = stepData['personalEmailId'] ?? '';
        if (stepData['dateOfBirth'] != null) {
          _dateOfBirth = DateTime.parse(stepData['dateOfBirth']);
        }
        _countryOfResidenceController.text = stepData['countryOfResidence'] ?? '';
        _residenceAddressController.text = stepData['residenceAddress'] ?? '';
        _residenceTypeController.text = stepData['residenceType'] ?? '';
        _residenceStabilityController.text = stepData['residenceStability'] ?? '';
        _companyNameController.text = stepData['companyName'] ?? '';
        _companyAddressController.text = stepData['companyAddress'] ?? '';
        _nationalityController.text = stepData['nationality'] ?? '';
        _countryOfBirthController.text = stepData['countryOfBirth'] ?? '';
        _occupationController.text = stepData['occupation'] ?? '';
        _educationalQualificationController.text = stepData['educationalQualification'] ?? '';
        _workTypeController.text = stepData['workType'] ?? '';
        _industryController.text = stepData['industry'] ?? '';
        _annualIncomeController.text = stepData['annualIncome'] ?? '';
        _totalWorkExperienceController.text = stepData['totalWorkExperience'] ?? '';
        _currentCompanyExperienceController.text = stepData['currentCompanyExperience'] ?? '';
        _loanAmountController.text = stepData['loanAmount'] ?? stepData['loanAmountTenure']?.split('/')[0].trim() ?? '';
        _loanTenureController.text = stepData['loanTenure'] ?? (stepData['loanAmountTenure']?.split('/').length == 2 ? stepData['loanAmountTenure']?.split('/')[1].trim() ?? '' : '');
        _monthlyIncomeController.text = stepData['monthlyIncome'] ?? '';
        _currentEmiController.text = stepData['currentEmi'] ?? '';
        _existingLoansController.text = stepData['existingLoans']?.toString() ?? '';
        _creditScoreController.text = stepData['creditScore']?.toString() ?? '';
        _maritalStatus = stepData['maritalStatus'];
        _spouseNameController.text = stepData['spouseName'] ?? '';
        _fatherNameController.text = stepData['fatherName'] ?? '';
        _motherNameController.text = stepData['motherName'] ?? '';
        _reference1NameController.text = stepData['reference1Name'] ?? '';
        _reference1AddressController.text = stepData['reference1Address'] ?? '';
        _reference1ContactController.text = stepData['reference1Contact'] ?? '';
        _reference2NameController.text = stepData['reference2Name'] ?? '';
        _reference2AddressController.text = stepData['reference2Address'] ?? '';
        _reference2ContactController.text = stepData['reference2Contact'] ?? '';
        return;
      }
      
      // Fallback to provider
      final provider = context.read<SubmissionProvider>();
      final data = provider.submission.personalData;
      if (data != null) {
      _nameAsPerAadhaarController.text = data.nameAsPerAadhaar ?? '';
      _panNoController.text = data.panNo ?? '';
      _aadhaarNumberController.text = data.aadhaarNumber ?? '';
      _mobileNumberController.text = data.mobileNumber ?? '';
      _personalEmailIdController.text = data.personalEmailId ?? '';
      _dateOfBirth = data.dateOfBirth;
      
      _countryOfResidenceController.text = data.countryOfResidence ?? '';
      _residenceAddressController.text = data.residenceAddress ?? '';
      _residenceTypeController.text = data.residenceType ?? '';
      _residenceStabilityController.text = data.residenceStability ?? '';
      
      _companyNameController.text = data.companyName ?? '';
      _companyAddressController.text = data.companyAddress ?? '';
      
      _nationalityController.text = data.nationality ?? '';
      _countryOfBirthController.text = data.countryOfBirth ?? '';
      _occupationController.text = data.occupation ?? '';
      _educationalQualificationController.text = data.educationalQualification ?? '';
      _workTypeController.text = data.workType ?? '';
      _industryController.text = data.industry ?? '';
      _annualIncomeController.text = data.annualIncome ?? '';
      _totalWorkExperienceController.text = data.totalWorkExperience ?? '';
      _currentCompanyExperienceController.text = data.currentCompanyExperience ?? '';
      _loanAmountController.text = data.loanAmount ?? (data.loanAmountTenure?.split('/')[0].trim() ?? '');
      _loanTenureController.text = data.loanTenure ?? (data.loanAmountTenure?.split('/').length == 2 ? data.loanAmountTenure?.split('/')[1].trim() ?? '' : '');
      _monthlyIncomeController.text = data.monthlyIncome ?? '';
      _currentEmiController.text = data.currentEmi ?? '';
      _existingLoansController.text = data.existingLoans ?? '';
      _creditScoreController.text = data.creditScore ?? '';
      
      _maritalStatus = data.maritalStatus;
      _spouseNameController.text = data.spouseName ?? '';
      _fatherNameController.text = data.fatherName ?? '';
      _motherNameController.text = data.motherName ?? '';
      
      _reference1NameController.text = data.reference1Name ?? '';
      _reference1AddressController.text = data.reference1Address ?? '';
      _reference1ContactController.text = data.reference1Contact ?? '';
      
      _reference2NameController.text = data.reference2Name ?? '';
      _reference2AddressController.text = data.reference2Address ?? '';
      _reference2ContactController.text = data.reference2Contact ?? '';
      }
    } catch (e) {
      // Silently handle errors during data loading
      // Data will remain empty if loading fails
    }
  }

  @override
  void dispose() {
    _nameAsPerAadhaarController.dispose();
    _panNoController.dispose();
    _aadhaarNumberController.dispose();
    _mobileNumberController.dispose();
    _personalEmailIdController.dispose();
    _countryOfResidenceController.dispose();
    _residenceAddressController.dispose();
    _residenceTypeController.dispose();
    _residenceStabilityController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _nationalityController.dispose();
    _countryOfBirthController.dispose();
    _occupationController.dispose();
    _educationalQualificationController.dispose();
    _workTypeController.dispose();
    _industryController.dispose();
    _annualIncomeController.dispose();
    _totalWorkExperienceController.dispose();
    _currentCompanyExperienceController.dispose();
    _loanAmountController.dispose();
    _loanTenureController.dispose();
    _currentEmiController.dispose();
    _existingLoansController.dispose();
    _monthlyIncomeController.dispose();
    _creditScoreController.dispose();
    _spouseNameController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _reference1NameController.dispose();
    _reference1AddressController.dispose();
    _reference1ContactController.dispose();
    _reference2NameController.dispose();
    _reference2AddressController.dispose();
    _reference2ContactController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    if (_isSaving) return;
    
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        helpText: 'Select Date of Birth',
        cancelText: 'Cancel',
        confirmText: 'Select',
      );
      if (picked != null && mounted) {
        setState(() {
          _dateOfBirth = picked;
        });
        // Don't validate all fields - just update the state
        // Validation will happen when user submits the form
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to select date. Please try again.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _selectDateOfBirth,
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveAndProceed() async {
    if (!_formKey.currentState!.validate()) {
      // Scroll to first error field after frame is laid out
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToFirstError();
          }
        });
        PremiumToast.showWarning(
          context,
          'Please correct the errors in the form',
        );
      }
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final personalData = PersonalData(
        nameAsPerAadhaar: _nameAsPerAadhaarController.text.trim().isEmpty 
            ? null 
            : _nameAsPerAadhaarController.text.trim(),
        dateOfBirth: _dateOfBirth,
        panNo: _panNoController.text.trim().isEmpty 
            ? null 
            : _panNoController.text.trim().toUpperCase(),
        aadhaarNumber: _aadhaarNumberController.text.trim().isEmpty
            ? null
            : _aadhaarNumberController.text.trim().replaceAll(' ', '').replaceAll('-', ''),
        mobileNumber: _mobileNumberController.text.trim().isEmpty
            ? null 
            : _mobileNumberController.text.trim(),
        personalEmailId: _personalEmailIdController.text.trim().isEmpty 
            ? null 
            : _personalEmailIdController.text.trim().toLowerCase(),
        countryOfResidence: _countryOfResidenceController.text.trim().isEmpty 
            ? null 
            : _countryOfResidenceController.text.trim(),
        residenceAddress: _residenceAddressController.text.trim().isEmpty 
            ? null 
            : _residenceAddressController.text.trim(),
        residenceType: _residenceTypeController.text.trim().isEmpty 
            ? null 
            : _residenceTypeController.text.trim(),
        residenceStability: _residenceStabilityController.text.trim().isEmpty 
            ? null 
            : _residenceStabilityController.text.trim(),
        companyName: _companyNameController.text.trim().isEmpty 
            ? null 
            : _companyNameController.text.trim(),
        companyAddress: _companyAddressController.text.trim().isEmpty 
            ? null 
            : _companyAddressController.text.trim(),
        nationality: _nationalityController.text.trim().isEmpty 
            ? null 
            : _nationalityController.text.trim(),
        countryOfBirth: _countryOfBirthController.text.trim().isEmpty 
            ? null 
            : _countryOfBirthController.text.trim(),
        occupation: _occupationController.text.trim().isEmpty 
            ? null 
            : _occupationController.text.trim(),
        educationalQualification: _educationalQualificationController.text.trim().isEmpty 
            ? null 
            : _educationalQualificationController.text.trim(),
        workType: _workTypeController.text.trim().isEmpty 
            ? null 
            : _workTypeController.text.trim(),
        industry: _industryController.text.trim().isEmpty 
            ? null 
            : _industryController.text.trim(),
        annualIncome: _annualIncomeController.text.trim().isEmpty 
            ? null 
            : _annualIncomeController.text.trim(),
        totalWorkExperience: _totalWorkExperienceController.text.trim().isEmpty 
            ? null 
            : _totalWorkExperienceController.text.trim(),
        currentCompanyExperience: _currentCompanyExperienceController.text.trim().isEmpty 
            ? null 
            : _currentCompanyExperienceController.text.trim(),
        loanAmount: _loanAmountController.text.trim().isEmpty ? null : _loanAmountController.text.trim(),
        loanTenure: _loanTenureController.text.trim().isEmpty ? null : _loanTenureController.text.trim(),
        loanAmountTenure: _loanAmountController.text.trim().isNotEmpty && _loanTenureController.text.trim().isNotEmpty
            ? '${_loanAmountController.text.trim()}/${_loanTenureController.text.trim()}'
            : (_loanAmountController.text.trim().isNotEmpty ? _loanAmountController.text.trim() : null),
        monthlyIncome: _monthlyIncomeController.text.trim().isEmpty ? null : _monthlyIncomeController.text.trim(),
        currentEmi: _currentEmiController.text.trim().isEmpty ? null : _currentEmiController.text.trim(),
        existingLoans: _existingLoansController.text.trim().isEmpty ? null : _existingLoansController.text.trim(),
        creditScore: _creditScoreController.text.trim().isEmpty ? null : _creditScoreController.text.trim(),
        maritalStatus: _maritalStatus,
        spouseName: _spouseNameController.text.trim().isEmpty 
            ? null 
            : _spouseNameController.text.trim(),
        fatherName: _fatherNameController.text.trim().isEmpty 
            ? null 
            : _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim().isEmpty 
            ? null 
            : _motherNameController.text.trim(),
        reference1Name: _reference1NameController.text.trim().isEmpty 
            ? null 
            : _reference1NameController.text.trim(),
        reference1Address: _reference1AddressController.text.trim().isEmpty 
            ? null 
            : _reference1AddressController.text.trim(),
        reference1Contact: _reference1ContactController.text.trim().isEmpty 
            ? null 
            : _reference1ContactController.text.trim(),
        reference2Name: _reference2NameController.text.trim().isEmpty 
            ? null 
            : _reference2NameController.text.trim(),
        reference2Address: _reference2AddressController.text.trim().isEmpty 
            ? null 
            : _reference2AddressController.text.trim(),
        reference2Contact: _reference2ContactController.text.trim().isEmpty 
            ? null 
            : _reference2ContactController.text.trim(),
      );

      // Debug: Check completeness and log missing fields
      if (!personalData.isComplete) {
        final missingFields = personalData.getMissingFields();
        debugPrint('❌ PERSONAL DATA INCOMPLETE - Missing fields:');
        for (final field in missingFields) {
          debugPrint('   - $field');
        }
        debugPrint('📝 Current values:');
        debugPrint('   Name: "${personalData.nameAsPerAadhaar ?? "null"}"');
        debugPrint('   DOB: ${personalData.dateOfBirth ?? "null"}');
        debugPrint('   PAN: "${personalData.panNo ?? "null"}"');
        debugPrint('   Mobile: "${personalData.mobileNumber ?? "null"}"');
        debugPrint('   Email: "${personalData.personalEmailId ?? "null"}"');
        debugPrint('   Address: "${personalData.residenceAddress ?? "null"}"');
      } else {
        debugPrint('✅ PERSONAL DATA COMPLETE');
      }

      // Save to provider
      if (mounted) {
        context.read<SubmissionProvider>().setPersonalData(personalData);
      }

      // Save to backend
      final appProvider = context.read<ApplicationProvider>();
      if (appProvider.hasApplication) {
        await appProvider.updateApplication(
          currentStep: 6, // Move to preview step
          step5PersonalData: {
            'nameAsPerAadhaar': personalData.nameAsPerAadhaar,
            'dateOfBirth': personalData.dateOfBirth?.toIso8601String(),
            'panNo': personalData.panNo,
            'aadhaarNumber': personalData.aadhaarNumber,
            'mobileNumber': personalData.mobileNumber,
            'personalEmailId': personalData.personalEmailId,
            'countryOfResidence': personalData.countryOfResidence,
            'residenceAddress': personalData.residenceAddress,
            'residenceType': personalData.residenceType,
            'residenceStability': personalData.residenceStability,
            'companyName': personalData.companyName,
            'companyAddress': personalData.companyAddress,
            'nationality': personalData.nationality,
            'countryOfBirth': personalData.countryOfBirth,
            'occupation': personalData.occupation,
            'educationalQualification': personalData.educationalQualification,
            'workType': personalData.workType,
            'industry': personalData.industry,
            'annualIncome': personalData.annualIncome,
            'totalWorkExperience': personalData.totalWorkExperience,
            'currentCompanyExperience': personalData.currentCompanyExperience,
            'loanAmount': personalData.loanAmount,
            'loanTenure': personalData.loanTenure,
            'loanAmountTenure': personalData.loanAmountTenure,
            'monthlyIncome': personalData.monthlyIncome,
            'currentEmi': personalData.currentEmi,
            'existingLoans': personalData.existingLoans,
            'creditScore': personalData.creditScore,
            'maritalStatus': personalData.maritalStatus,
            'spouseName': personalData.spouseName,
            'fatherName': personalData.fatherName,
            'motherName': personalData.motherName,
            'reference1Name': personalData.reference1Name,
            'reference1Address': personalData.reference1Address,
            'reference1Contact': personalData.reference1Contact,
            'reference2Name': personalData.reference2Name,
            'reference2Address': personalData.reference2Address,
            'reference2Contact': personalData.reference2Contact,
            'savedAt': DateTime.now().toIso8601String(),
          },
        );
        
        if (mounted) {
          PremiumToast.showSuccess(
            context,
            'Personal data saved successfully!',
          );
        }
      }

      if (mounted && context.mounted) {
        // Navigate to preview screen
        context.go(AppRoutes.step6Preview);
      }
    } catch (e) {
      if (mounted) {
        PremiumToast.showError(
          context,
          'Error saving data: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: _saveAndProceed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _scrollToFirstError() {
    try {
      // Find first error field and scroll to it
      final formContext = _formKey.currentContext;
      if (formContext != null) {
        // Check if the context has a RenderObject (is laid out)
        final renderObject = formContext.findRenderObject();
        if (renderObject != null && renderObject.attached) {
          Scrollable.ensureVisible(
            formContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1, // Scroll to show field near top
          );
        }
      }
    } catch (e) {
      // Silently handle scroll errors - not critical for functionality
      // The error message is already shown to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            AppHeader(
              title: 'Personal Information',
              icon: Icons.person,
              showBackButton: true,
              onBackPressed: _isSaving ? null : () {
                if (mounted && context.mounted) {
                  try {
                    context.go(AppRoutes.step5_1SalarySlips);
                  } catch (e) {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  }
                }
              },
              showHomeButton: true,
            ),
            // Progress Indicator
            _buildProgressIndicator(context),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info Card
                      _buildInfoCard(context),
                      const SizedBox(height: 16),
                      // Section 1: Basic Information
                      _buildExpandableSection(
                        context: context,
                        title: 'Basic Information',
                        icon: Icons.contact_page,
                        summary: _getBasicInfoSummary(),
                        isExpanded: _basicInfoExpanded,
                        isActive: _basicInfoExpanded,
                        onExpansionChanged: () {
                          setState(() {
                            _basicInfoExpanded = !_basicInfoExpanded;
                          });
                        },
                        expandedContent: Column(
                          children: [
                            _buildPremiumTextField(
                              context,
                              controller: _nameAsPerAadhaarController,
                              label: 'Name as per Aadhaar Card',
                              icon: Icons.person_outline,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter name as per Aadhaar Card';
                                }
                                if (value.trim().length < 3) {
                                  return 'Name must be at least 3 characters';
                                }
                                if (!_nameRegex.hasMatch(value.trim())) {
                                  return 'Name can only contain letters and spaces';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildDatePickerField(context),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _panNoController,
                              label: 'PAN No',
                              icon: Icons.credit_card,
                              isRequired: true,
                              inputFormatters: [_panFormatter],
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter PAN number';
                                }
                                final pan = value.trim().toUpperCase();
                                if (pan.length != 10) {
                                  return 'PAN number must be 10 characters';
                                }
                                if (!_panRegex.hasMatch(pan)) {
                                  return 'Invalid PAN format. Format: ABCDE1234F';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _aadhaarNumberController,
                              label: 'Aadhaar No',
                              icon: Icons.fingerprint,
                              isRequired: true,
                              inputFormatters: [
                                _aadhaarFormatter,
                                LengthLimitingTextInputFormatter(12),
                              ],
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter Aadhaar number';
                                }
                                final aadhaar = value.trim().replaceAll(' ', '').replaceAll('-', '');
                                if (aadhaar.length != 12) {
                                  return 'Aadhaar number must be 12 digits';
                                }
                                if (!_aadhaarRegex.hasMatch(aadhaar)) {
                                  return 'Invalid Aadhaar format. Must be 12 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _mobileNumberController,
                              label: 'Mobile Number',
                              icon: Icons.phone_iphone,
                              isRequired: true,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                _phoneFormatter,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter mobile number';
                                }
                                final phone = value.trim();
                                if (phone.length != 10) {
                                  return 'Mobile number must be 10 digits';
                                }
                                if (!_phoneRegex.hasMatch(phone)) {
                                  return 'Please enter a valid 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _personalEmailIdController,
                              label: 'Personal Email Id',
                              icon: Icons.mail_outline,
                              isRequired: true,
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter personal email';
                                }
                                final email = value.trim().toLowerCase();
                                if (!_emailRegex.hasMatch(email)) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section 2: Residence Information
                      _buildExpandableSection(
                        context: context,
                        title: 'Residence Information',
                        icon: Icons.home,
                        summary: _getResidenceInfoSummary(),
                        isExpanded: _residenceInfoExpanded,
                        isActive: false,
                        onExpansionChanged: () {
                          setState(() {
                            _residenceInfoExpanded = !_residenceInfoExpanded;
                          });
                        },
                        expandedContent: Column(
                          children: [
                            _buildPremiumTextField(
                              context,
                              controller: _countryOfResidenceController,
                              label: 'Country of Residence',
                              icon: Icons.public,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter country of residence';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _residenceAddressController,
                              label: 'Residence Address',
                              icon: Icons.location_on,
                              isRequired: true,
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter residence address';
                                }
                                if (value.trim().length < 10) {
                                  return 'Address must be at least 10 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _residenceTypeController,
                              label: 'Residence Type',
                              icon: Icons.home_work,
                              isRequired: false,
                              hintText: 'e.g., Owned, Rented',
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _residenceStabilityController,
                              label: 'Residence Stability',
                              icon: Icons.calendar_today,
                              isRequired: false,
                              hintText: 'e.g., Years of residence',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section 3: Work Info (formerly Company Information)
                      _buildExpandableSection(
                        context: context,
                        title: 'Work Info',
                        icon: Icons.work_outline,
                        summary: _getWorkInfoSummary(),
                        isExpanded: _workInfoExpanded,
                        isActive: false,
                        onExpansionChanged: () {
                          setState(() {
                            _workInfoExpanded = !_workInfoExpanded;
                          });
                        },
                        expandedContent: Column(
                          children: [
                            _buildPremiumTextField(
                              context,
                              controller: _companyNameController,
                              label: 'Company Name',
                              icon: Icons.business_center,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _companyAddressController,
                              label: 'Company Address',
                              icon: Icons.location_city,
                              isRequired: false,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _workTypeController,
                              label: 'Work Type',
                              icon: Icons.work_outline,
                              isRequired: false,
                              hintText: 'e.g., Full-time, Part-time',
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _industryController,
                              label: 'Industry',
                              icon: Icons.business_center,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _annualIncomeController,
                              label: 'Annual Income',
                              icon: Icons.account_balance_wallet,
                              isRequired: false,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final income = int.tryParse(value.trim());
                                  if (income == null) {
                                    return 'Please enter a valid number';
                                  }
                                  if (income < 50000) {
                                    return 'Annual income should be at least ₹50,000';
                                  }
                                  if (income > 100000000) {
                                    return 'Please enter a valid income amount';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _totalWorkExperienceController,
                              label: 'Total years of experience',
                              icon: Icons.timeline,
                              isRequired: false,
                              hintText: 'e.g., 5 years',
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _currentCompanyExperienceController,
                              label: 'Current Company experience',
                              icon: Icons.business,
                              isRequired: false,
                              hintText: 'e.g., 2 years',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section 4: Personal Details
                      _buildExpandableSection(
                        context: context,
                        title: 'Personal Details',
                        icon: Icons.info,
                        summary: _getPersonalDetailsSummary(),
                        isExpanded: _personalDetailsExpanded,
                        isActive: false,
                        onExpansionChanged: () {
                          setState(() {
                            _personalDetailsExpanded = !_personalDetailsExpanded;
                          });
                        },
                        expandedContent: Column(
                          children: [
                            _buildPremiumTextField(
                              context,
                              controller: _nationalityController,
                              label: 'Nationality',
                              icon: Icons.flag,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _countryOfBirthController,
                              label: 'Country of Birth',
                              icon: Icons.public,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _occupationController,
                              label: 'Occupation',
                              icon: Icons.work,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _educationalQualificationController,
                              label: 'Educational Qualification',
                              icon: Icons.school,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _loanAmountController,
                              label: 'Loan Amount',
                              icon: Icons.account_balance_wallet,
                              isRequired: false,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 500000',
                              prefixText: '₹ ',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final amount = int.tryParse(value.trim());
                                  if (amount == null) {
                                    return 'Please enter a valid amount';
                                  }
                                  if (amount < 10000) {
                                    return 'Minimum loan amount is ₹10,000';
                                  }
                                  if (amount > 50000000) {
                                    return 'Maximum loan amount is ₹5 Crore';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _loanTenureController,
                              label: 'Tenure',
                              icon: Icons.calendar_today,
                              isRequired: false,
                              keyboardType: TextInputType.number,
                              hintText: 'Months',
                              suffixText: ' months',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final months = int.tryParse(value.trim());
                                  if (months == null) {
                                    return 'Please enter valid months';
                                  }
                                  if (months < 6) {
                                    return 'Minimum tenure is 6 months';
                                  }
                                  if (months > 360) {
                                    return 'Maximum tenure is 360 months (30 years)';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _monthlyIncomeController,
                              label: 'Monthly Income',
                              icon: Icons.attach_money,
                              isRequired: false,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 50000',
                              prefixText: '₹ ',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final income = int.tryParse(value.trim());
                                  if (income == null) {
                                    return 'Please enter a valid amount';
                                  }
                                  if (income < 5000) {
                                    return 'Minimum monthly income is ₹5,000';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _currentEmiController,
                              label: 'Current EMI (if any)',
                              icon: Icons.payment,
                              isRequired: false,
                              keyboardType: TextInputType.number,
                              hintText: 'Total monthly EMI',
                              prefixText: '₹ ',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final emi = int.tryParse(value.trim());
                                  if (emi == null) {
                                    return 'Please enter a valid amount';
                                  }
                                  if (emi < 0) {
                                    return 'EMI cannot be negative';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _existingLoansController,
                              label: 'Number of Existing Loans',
                              icon: Icons.format_list_numbered,
                              isRequired: false,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 0, 1, 2',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final count = int.tryParse(value.trim());
                                  if (count == null) {
                                    return 'Please enter a valid number';
                                  }
                                  if (count < 0) {
                                    return 'Cannot be negative';
                                  }
                                  if (count > 10) {
                                    return 'Maximum 10 loans allowed';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _creditScoreController,
                              label: 'Credit Score (CIBIL)',
                              icon: Icons.star_rate,
                              isRequired: false,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 750',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final score = int.tryParse(value.trim());
                                  if (score == null) {
                                    return 'Please enter a valid score';
                                  }
                                  if (score < 300) {
                                    return 'Minimum credit score is 300';
                                  }
                                  if (score > 900) {
                                    return 'Maximum credit score is 900';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section 5: Family Information
                      _buildExpandableSection(
                        context: context,
                        title: 'Family Information',
                        icon: Icons.groups,
                        summary: _getFamilyInfoSummary(),
                        isExpanded: _familyInfoExpanded,
                        isActive: false,
                        onExpansionChanged: () {
                          setState(() {
                            _familyInfoExpanded = !_familyInfoExpanded;
                          });
                        },
                        expandedContent: Column(
                          children: [
                            _buildMaritalStatusField(context),
                            const SizedBox(height: 16),
                            if (_maritalStatus == 'Married')
                              _buildPremiumTextField(
                                context,
                                controller: _spouseNameController,
                                label: 'Spouse Name',
                                icon: Icons.person_outline,
                                isRequired: false,
                                validator: (value) {
                                  if (value != null && value.trim().isNotEmpty) {
                                    if (value.trim().length < 3) {
                                      return 'Name must be at least 3 characters';
                                    }
                                    if (!_nameRegex.hasMatch(value.trim())) {
                                      return 'Name can only contain letters and spaces';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            if (_maritalStatus == 'Married') const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _fatherNameController,
                              label: 'Father Name',
                              icon: Icons.person,
                              isRequired: false,
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  if (value.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  if (!_nameRegex.hasMatch(value.trim())) {
                                    return 'Name can only contain letters and spaces';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _motherNameController,
                              label: 'Mother Name',
                              icon: Icons.person,
                              isRequired: false,
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  if (value.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  if (!_nameRegex.hasMatch(value.trim())) {
                                    return 'Name can only contain letters and spaces';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section 6: Reference Details
                      _buildExpandableSection(
                        context: context,
                        title: 'Two Reference Details',
                        icon: Icons.record_voice_over,
                        summary: _getReferenceInfoSummary(),
                        isExpanded: _referenceInfoExpanded,
                        isActive: false,
                        onExpansionChanged: () {
                          setState(() {
                            _referenceInfoExpanded = !_referenceInfoExpanded;
                          });
                        },
                        expandedContent: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '1',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Reference 1',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    context,
                                    controller: _reference1NameController,
                                    label: 'Name',
                                    icon: Icons.person,
                                    isRequired: false,
                                    validator: (value) {
                                      if (value != null && value.trim().isNotEmpty) {
                                        if (value.trim().length < 3) {
                                          return 'Name must be at least 3 characters';
                                        }
                                        if (!_nameRegex.hasMatch(value.trim())) {
                                          return 'Name can only contain letters and spaces';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    context,
                                    controller: _reference1AddressController,
                                    label: 'Address',
                                    icon: Icons.location_on,
                                    isRequired: false,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    context,
                                    controller: _reference1ContactController,
                                    label: 'Contact Details',
                                    icon: Icons.phone,
                                    isRequired: false,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: (value) {
                                      if (value != null && value.trim().isNotEmpty) {
                                        if (value.trim().length != 10) {
                                          return 'Contact number must be 10 digits';
                                        }
                                        if (!_phoneRegex.hasMatch(value.trim())) {
                                          return 'Please enter a valid 10-digit contact number';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '2',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Reference 2',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    context,
                                    controller: _reference2NameController,
                                    label: 'Name',
                                    icon: Icons.person,
                                    isRequired: false,
                                    validator: (value) {
                                      if (value != null && value.trim().isNotEmpty) {
                                        if (value.trim().length < 3) {
                                          return 'Name must be at least 3 characters';
                                        }
                                        if (!_nameRegex.hasMatch(value.trim())) {
                                          return 'Name can only contain letters and spaces';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    context,
                                    controller: _reference2AddressController,
                                    label: 'Address',
                                    icon: Icons.location_on,
                                    isRequired: false,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    context,
                                    controller: _reference2ContactController,
                                    label: 'Contact Details',
                                    icon: Icons.phone,
                                    isRequired: false,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: (value) {
                                      if (value != null && value.trim().isNotEmpty) {
                                        if (value.trim().length != 10) {
                                          return 'Contact number must be 10 digits';
                                        }
                                        if (!_phoneRegex.hasMatch(value.trim())) {
                                          return 'Please enter a valid 10-digit contact number';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100), // Space for footer
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      color: Colors.white,
      child: Row(
        children: [
          // Steps 1-5: Completed
          for (int i = 1; i <= 5; i++) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Step 6: Current
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '6',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
            ),
          ),
          // Step 7: Pending
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '7',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.badge,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please fill in all required fields',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Next Button
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _isSaving ? null : _saveAndProceed,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSaving ? 'Saving...' : 'Next: Preview',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (!_isSaving) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? prefixText,
    String? suffixText,
    Widget? suffixWidget,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '$label${isRequired ? ' *' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // slate-50
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0), // slate-200
                width: 1,
              ),
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              validator: validator,
              inputFormatters: inputFormatters,
              textCapitalization: textCapitalization,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: const Color(0xFF1E293B),
              ),
              enabled: !_isSaving,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    icon,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                suffixIcon: suffixWidget,
                prefixText: prefixText,
                suffixText: suffixText,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Date of Birth *',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          InkWell(
            onTap: _selectDateOfBirth,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // slate-50
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0), // slate-200
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dateOfBirth != null
                          ? DateFormat('MMMM dd, yyyy').format(_dateOfBirth!)
                          : 'Select date',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: _dateOfBirth != null
                            ? const Color(0xFF1E293B)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods to get summary text for each section
  String _getBasicInfoSummary() {
    final parts = <String>[];
    if (_nameAsPerAadhaarController.text.isNotEmpty) {
      parts.add(_nameAsPerAadhaarController.text);
    }
    if (_panNoController.text.isNotEmpty) {
      parts.add('PAN: ${_panNoController.text}');
    }
    if (_mobileNumberController.text.isNotEmpty) {
      parts.add('Mobile: ${_mobileNumberController.text}');
    }
    if (_personalEmailIdController.text.isNotEmpty) {
      parts.add(_personalEmailIdController.text);
    }
    if (_dateOfBirth != null) {
      parts.add(DateFormat('dd MMM yyyy').format(_dateOfBirth!));
    }
    return parts.isEmpty ? 'Not filled' : parts.join(' • ');
  }

  String _getResidenceInfoSummary() {
    final parts = <String>[];
    if (_countryOfResidenceController.text.isNotEmpty) {
      parts.add(_countryOfResidenceController.text);
    }
    if (_residenceAddressController.text.isNotEmpty) {
      final address = _residenceAddressController.text;
      parts.add(address.length > 30 ? '${address.substring(0, 30)}...' : address);
    }
    if (_residenceTypeController.text.isNotEmpty) {
      parts.add(_residenceTypeController.text);
    }
    return parts.isEmpty ? 'Not filled' : parts.join(' • ');
  }

  String _getWorkInfoSummary() {
    final parts = <String>[];
    if (_companyNameController.text.isNotEmpty) {
      parts.add(_companyNameController.text);
    }
    if (_workTypeController.text.isNotEmpty) {
      parts.add(_workTypeController.text);
    }
    if (_industryController.text.isNotEmpty) {
      parts.add(_industryController.text);
    }
    if (_annualIncomeController.text.isNotEmpty) {
      parts.add('Income: ${_annualIncomeController.text}');
    }
    if (_totalWorkExperienceController.text.isNotEmpty) {
      parts.add('Exp: ${_totalWorkExperienceController.text}');
    }
    return parts.isEmpty ? 'Not filled' : parts.join(' • ');
  }

  String _getPersonalDetailsSummary() {
    final parts = <String>[];
    if (_nationalityController.text.isNotEmpty) {
      parts.add(_nationalityController.text);
    }
    if (_occupationController.text.isNotEmpty) {
      parts.add(_occupationController.text);
    }
    if (_loanAmountController.text.isNotEmpty) {
      parts.add('Loan: ₹${_loanAmountController.text}');
    }
    if (_monthlyIncomeController.text.isNotEmpty) {
      parts.add('Income: ₹${_monthlyIncomeController.text}/mo');
    }
    return parts.isEmpty ? 'Not filled' : parts.join(' • ');
  }

  String _getFamilyInfoSummary() {
    final parts = <String>[];
    if (_maritalStatus != null) {
      parts.add(_maritalStatus!);
    }
    if (_spouseNameController.text.isNotEmpty) {
      parts.add('Spouse: ${_spouseNameController.text}');
    }
    if (_fatherNameController.text.isNotEmpty) {
      parts.add('Father: ${_fatherNameController.text}');
    }
    if (_motherNameController.text.isNotEmpty) {
      parts.add('Mother: ${_motherNameController.text}');
    }
    return parts.isEmpty ? 'Not filled' : parts.join(' • ');
  }

  String _getReferenceInfoSummary() {
    final parts = <String>[];
    if (_reference1NameController.text.isNotEmpty) {
      parts.add('Ref 1: ${_reference1NameController.text}');
    }
    if (_reference2NameController.text.isNotEmpty) {
      parts.add('Ref 2: ${_reference2NameController.text}');
    }
    return parts.isEmpty ? 'Not filled' : parts.join(' • ');
  }

  // Build expandable section widget
  Widget _buildExpandableSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String summary,
    required bool isExpanded,
    required VoidCallback onExpansionChanged,
    required Widget expandedContent,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final isNotFilled = summary == 'Not filled';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border(
                left: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 4,
                ),
              )
            : Border.all(
                color: Colors.grey.shade100,
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onExpansionChanged,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: isActive
                            ? AppTheme.primaryColor
                            : Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isActive
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isNotFilled && isActive
                                  ? const Color(0xFFEF4444) // rose-500
                                  : Colors.grey.shade400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: isActive
                          ? AppTheme.primaryColor
                          : Colors.grey.shade400,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: expandedContent,
            ),
        ],
      ),
    );
  }

  Widget _buildMaritalStatusField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.favorite,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Married / Unmarried',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Married'),
                          selected: _maritalStatus == 'Married',
                          onSelected: (selected) {
                            setState(() {
                              _maritalStatus = selected ? 'Married' : null;
                            });
                          },
                          selectedColor: colorScheme.primary,
                          labelStyle: TextStyle(
                            color: _maritalStatus == 'Married' ? colorScheme.onPrimary : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Unmarried'),
                          selected: _maritalStatus == 'Unmarried',
                          onSelected: (selected) {
                            setState(() {
                              _maritalStatus = selected ? 'Unmarried' : null;
                            });
                          },
                          selectedColor: colorScheme.primary,
                          labelStyle: TextStyle(
                            color: _maritalStatus == 'Unmarried' ? colorScheme.onPrimary : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
