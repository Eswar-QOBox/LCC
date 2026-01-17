import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/submission_provider.dart';
import '../providers/application_provider.dart';
import '../models/document_submission.dart';
import '../utils/app_routes.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_toast.dart';
import '../utils/app_theme.dart';

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
  bool _isDraftSaved = false;
  bool _isSavingDraft = false;
  
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
  static final RegExp _phoneRegex = RegExp(
    r'^[0-9]{10}$',
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
  
  final _phoneFormatter = FilteringTextInputFormatter.digitsOnly;
  
  // Basic Information Controllers
  final _nameAsPerAadhaarController = TextEditingController();
  final _panNoController = TextEditingController();
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
        _loanTenureController.text = stepData['loanTenure'] ?? stepData['loanAmountTenure']?.split('/').length == 2 ? stepData['loanAmountTenure']?.split('/')[1].trim() ?? '' : '';
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
        // Validate the form field after date selection
        _formKey.currentState?.validate();
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
        nameAsPerAadhaar: _nameAsPerAadhaarController.text.trim(),
        dateOfBirth: _dateOfBirth,
        panNo: _panNoController.text.trim().toUpperCase(),
        mobileNumber: _mobileNumberController.text.trim(),
        personalEmailId: _personalEmailIdController.text.trim().toLowerCase(),
        countryOfResidence: _countryOfResidenceController.text.trim(),
        residenceAddress: _residenceAddressController.text.trim(),
        residenceType: _residenceTypeController.text.trim(),
        residenceStability: _residenceStabilityController.text.trim(),
        companyName: _companyNameController.text.trim(),
        companyAddress: _companyAddressController.text.trim(),
        nationality: _nationalityController.text.trim(),
        countryOfBirth: _countryOfBirthController.text.trim(),
        occupation: _occupationController.text.trim(),
        educationalQualification: _educationalQualificationController.text.trim(),
        workType: _workTypeController.text.trim(),
        industry: _industryController.text.trim(),
        annualIncome: _annualIncomeController.text.trim(),
        totalWorkExperience: _totalWorkExperienceController.text.trim(),
        currentCompanyExperience: _currentCompanyExperienceController.text.trim(),
        loanAmount: _loanAmountController.text.trim().isEmpty ? null : _loanAmountController.text.trim(),
        loanTenure: _loanTenureController.text.trim().isEmpty ? null : _loanTenureController.text.trim(),
        loanAmountTenure: _loanAmountController.text.trim().isNotEmpty && _loanTenureController.text.trim().isNotEmpty
            ? '${_loanAmountController.text.trim()}/${_loanTenureController.text.trim()}'
            : (_loanAmountController.text.trim().isNotEmpty ? _loanAmountController.text.trim() : null),
        maritalStatus: _maritalStatus,
        spouseName: _spouseNameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        reference1Name: _reference1NameController.text.trim(),
        reference1Address: _reference1AddressController.text.trim(),
        reference1Contact: _reference1ContactController.text.trim(),
        reference2Name: _reference2NameController.text.trim(),
        reference2Address: _reference2AddressController.text.trim(),
        reference2Contact: _reference2ContactController.text.trim(),
      );

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

  Future<void> _saveDraft() async {
    if (_isSavingDraft || _isDraftSaved) return;

    setState(() {
      _isSavingDraft = true;
    });

    final provider = context.read<SubmissionProvider>();
    
    // Save current form data to provider (even if incomplete - it's a draft)
    try {
      final personalData = PersonalData(
        nameAsPerAadhaar: _nameAsPerAadhaarController.text.trim().isEmpty 
            ? null 
            : _nameAsPerAadhaarController.text.trim(),
        dateOfBirth: _dateOfBirth,
        panNo: _panNoController.text.trim().isEmpty 
            ? null 
            : _panNoController.text.trim().toUpperCase(),
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
        loanAmount: _loanAmountController.text.trim().isEmpty 
            ? null 
            : _loanAmountController.text.trim(),
        loanTenure: _loanTenureController.text.trim().isEmpty 
            ? null 
            : _loanTenureController.text.trim(),
        loanAmountTenure: _loanAmountController.text.trim().isNotEmpty && _loanTenureController.text.trim().isNotEmpty
            ? '${_loanAmountController.text.trim()}/${_loanTenureController.text.trim()}'
            : (_loanAmountController.text.trim().isNotEmpty ? _loanAmountController.text.trim() : null),
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

      // Save to provider
      if (mounted) {
        provider.setPersonalData(personalData);
      }

      final success = await provider.saveDraft();
      
      if (mounted) {
        if (success) {
          setState(() {
            _isDraftSaved = true;
            _isSavingDraft = false;
          });
          PremiumToast.showSuccess(
            context,
            'Draft saved successfully!',
            duration: const Duration(seconds: 2),
          );
        } else {
          setState(() {
            _isSavingDraft = false;
          });
          PremiumToast.showError(
            context,
            'Failed to save draft. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
        PremiumToast.showError(
          context,
          'Error saving draft: $e',
        );
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
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.08),
                colorScheme.secondary.withValues(alpha: 0.04),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      colorScheme.primary.withValues(alpha: 0.03),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AppBar(
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person,
                          color: colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: _isSaving ? null : () {
                        if (mounted && context.mounted) {
                          try {
                            context.go(AppRoutes.step4BankStatement);
                          } catch (e) {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          }
                        }
                      },
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            StepProgressIndicator(currentStep: 5, totalSteps: 6),
            Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PremiumCard(
                          gradientColors: [
                            Colors.white,
                            colorScheme.primary.withValues(alpha: 0.03),
                          ],
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Personal Information',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please fill in all required fields',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Section 1: Basic Information
                      _buildExpandableSection(
                        context: context,
                        title: 'Basic Information',
                        icon: Icons.person,
                        summary: _getBasicInfoSummary(),
                        isExpanded: _basicInfoExpanded,
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
                              icon: Icons.badge,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter name as per Aadhaar Card';
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
                              controller: _mobileNumberController,
                              label: 'Mobile Number',
                              icon: Icons.phone,
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
                              icon: Icons.email,
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
                        icon: Icons.work,
                        summary: _getWorkInfoSummary(),
                        isExpanded: _workInfoExpanded,
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
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildPremiumTextField(
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
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildPremiumTextField(
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
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section 5: Family Information
                      _buildExpandableSection(
                        context: context,
                        title: 'Family Information',
                        icon: Icons.family_restroom,
                        summary: _getFamilyInfoSummary(),
                        isExpanded: _familyInfoExpanded,
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
                              ),
                            if (_maritalStatus == 'Married') const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _fatherNameController,
                              label: 'Father Name',
                              icon: Icons.person,
                              isRequired: false,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(
                              context,
                              controller: _motherNameController,
                              label: 'Mother Name',
                              icon: Icons.person,
                              isRequired: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section 6: Reference Details
                      _buildExpandableSection(
                        context: context,
                        title: 'Two Reference Details',
                        icon: Icons.contacts,
                        summary: _getReferenceInfoSummary(),
                        isExpanded: _referenceInfoExpanded,
                        onExpansionChanged: () {
                          setState(() {
                            _referenceInfoExpanded = !_referenceInfoExpanded;
                          });
                        },
                        expandedContent: Column(
                          children: [
                            PremiumCard(
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.05),
                                colorScheme.secondary.withValues(alpha: 0.02),
                              ],
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
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            PremiumCard(
                              gradientColors: [
                                colorScheme.primary.withValues(alpha: 0.05),
                                colorScheme.secondary.withValues(alpha: 0.02),
                              ],
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
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Save as Draft button
                      Builder(
                        builder: (context) {
                          final colorScheme = Theme.of(context).colorScheme;
                          return OutlinedButton.icon(
                            onPressed: (_isSaving || _isDraftSaved) ? null : _saveDraft,
                            icon: _isDraftSaved
                                ? const Icon(Icons.check_circle)
                                : (_isSavingDraft
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined)),
                            label: Text(_isDraftSaved
                                ? 'Draft Saved'
                                : (_isSavingDraft ? 'Saving...' : 'Save as Draft')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              foregroundColor: _isDraftSaved
                                  ? AppTheme.successColor
                                  : null,
                              side: BorderSide(
                                color: _isDraftSaved
                                    ? AppTheme.successColor
                                    : colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      PremiumButton(
                        label: _isSaving ? 'Saving...' : 'Next: Preview',
                        icon: _isSaving ? null : Icons.arrow_forward_rounded,
                        isPrimary: true,
                        onPressed: _isSaving ? null : _saveAndProceed,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: Theme.of(context).textTheme.bodyLarge,
        enabled: !_isSaving,
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          prefixText: prefixText,
          suffixText: suffixText,
          filled: true,
          fillColor: colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
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
      child: InkWell(
        onTap: _selectDateOfBirth,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  Icons.calendar_today_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date of Birth *',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateOfBirth != null
                          ? DateFormat('MMMM dd, yyyy').format(_dateOfBirth!)
                          : 'Select date',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _dateOfBirth != null
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: _dateOfBirth != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
    if (_educationalQualificationController.text.isNotEmpty) {
      parts.add(_educationalQualificationController.text);
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
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasData = summary != 'Not filled';

    return PremiumCard(
      gradientColors: [
        Colors.white,
        colorScheme.primary.withValues(alpha: 0.02),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onExpansionChanged,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: hasData 
                                  ? colorScheme.onSurfaceVariant 
                                  : colorScheme.error.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    height: 24,
                    thickness: 1,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  expandedContent,
                ],
              ),
            ),
            crossFadeState: isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
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
                      color: colorScheme.onSurfaceVariant,
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
