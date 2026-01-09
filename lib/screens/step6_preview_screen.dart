import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../models/document_submission.dart';
import '../utils/app_routes.dart';
import '../widgets/platform_image.dart';

class Step6PreviewScreen extends StatelessWidget {
  const Step6PreviewScreen({super.key});

  void _editStep(BuildContext context, String route) {
    context.go(route);
  }

  Future<void> _submit(BuildContext context) async {
    final provider = context.read<SubmissionProvider>();
    
    if (!provider.submission.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all steps before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await provider.submit();
      if (context.mounted) {
        context.go(AppRoutes.submissionSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubmissionProvider>();
    final submission = provider.submission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & Confirm'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: submission.isComplete
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      submission.isComplete
                          ? Icons.check_circle
                          : Icons.warning,
                      color: submission.isComplete ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        submission.isComplete
                            ? 'All documents are ready for submission'
                            : 'Please complete all steps',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: 'Step 1: Selfie / Photo',
              isComplete: submission.selfiePath != null,
              onEdit: () => _editStep(context, AppRoutes.step1Selfie),
              child: submission.selfiePath != null
                  ? Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PlatformImage(
                          imagePath: submission.selfiePath!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : const Text('Not uploaded'),
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Step 2: Aadhaar Card',
              isComplete: submission.aadhaar?.isComplete ?? false,
              onEdit: () => _editStep(context, AppRoutes.step2Aadhaar),
              child: submission.aadhaar?.isComplete == true
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildDocumentPreview(
                            submission.aadhaar!.frontPath!,
                            'Front',
                            submission.aadhaar!.isPdf,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDocumentPreview(
                            submission.aadhaar!.backPath!,
                            'Back',
                            submission.aadhaar!.isPdf,
                          ),
                        ),
                      ],
                    )
                  : const Text('Not uploaded'),
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Step 3: PAN Card',
              isComplete: submission.pan?.isComplete ?? false,
              onEdit: () => _editStep(context, AppRoutes.step3Pan),
              child: submission.pan?.isComplete == true
                  ? _buildDocumentPreview(
                      submission.pan!.frontPath!,
                      'Front',
                      submission.pan!.isPdf,
                    )
                  : const Text('Not uploaded'),
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Step 4: Bank Statement',
              isComplete: submission.bankStatement?.isComplete ?? false,
              onEdit: () => _editStep(context, AppRoutes.step4BankStatement),
              child: submission.bankStatement?.isComplete == true
                  ? Text(
                      '${submission.bankStatement!.pages.length} page(s) uploaded',
                    )
                  : const Text('Not uploaded'),
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Step 5: Personal Data',
              isComplete: submission.personalData?.isComplete ?? false,
              onEdit: () => _editStep(context, AppRoutes.step5PersonalData),
              child: submission.personalData != null
                  ? _buildPersonalDataPreview(submission.personalData!)
                  : const Text('Not filled'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: submission.isComplete
                  ? () => _submit(context)
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: submission.isComplete
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              child: const Text('Confirm & Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required bool isComplete,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isComplete ? Icons.check_circle : Icons.circle_outlined,
                      color: isComplete ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(String path, String label, bool isPdf) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isPdf
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, size: 32),
                    SizedBox(height: 4),
                    Text('PDF', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            : PlatformImage(imagePath: path, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildPersonalDataPreview(PersonalData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow('Name', data.fullName ?? ''),
        _buildDataRow('DOB', data.dateOfBirth != null
            ? data.dateOfBirth!.toString().split(' ')[0]
            : ''),
        _buildDataRow('Mobile', data.mobile ?? ''),
        _buildDataRow('Email', data.email ?? ''),
        _buildDataRow('Address', data.address ?? ''),
        _buildDataRow('Employment', data.employmentStatus ?? ''),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

