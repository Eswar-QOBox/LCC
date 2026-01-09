import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/submission_provider.dart';
import '../models/document_submission.dart';
import '../utils/app_routes.dart';

class Step5PersonalDataScreen extends StatefulWidget {
  const Step5PersonalDataScreen({super.key});

  @override
  State<Step5PersonalDataScreen> createState() =>
      _Step5PersonalDataScreenState();
}

class _Step5PersonalDataScreenState extends State<Step5PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _employmentStatusController = TextEditingController();
  final _incomeDetailsController = TextEditingController();
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    final data = provider.submission.personalData;
    if (data != null) {
      _fullNameController.text = data.fullName ?? '';
      _addressController.text = data.address ?? '';
      _mobileController.text = data.mobile ?? '';
      _emailController.text = data.email ?? '';
      _employmentStatusController.text = data.employmentStatus ?? '';
      _incomeDetailsController.text = data.incomeDetails ?? '';
      _dateOfBirth = data.dateOfBirth;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _employmentStatusController.dispose();
    _incomeDetailsController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  void _saveAndProceed() {
    if (_formKey.currentState!.validate()) {
      final personalData = PersonalData(
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirth,
        address: _addressController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        employmentStatus: _employmentStatusController.text.trim(),
        incomeDetails: _incomeDetailsController.text.trim(),
      );

      context.read<SubmissionProvider>().setPersonalData(personalData);
      context.go(AppRoutes.step6Preview);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 5: Personal Data'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Please fill in all required fields',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dateOfBirth != null
                        ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!)
                        : 'Select date',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your mobile number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _employmentStatusController,
                decoration: const InputDecoration(
                  labelText: 'Employment Status *',
                  prefixIcon: Icon(Icons.work),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Employed, Self-employed, Unemployed',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your employment status';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _incomeDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Income Details',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(),
                  hintText: 'Optional: Monthly/annual income',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveAndProceed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Next: Preview & Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

