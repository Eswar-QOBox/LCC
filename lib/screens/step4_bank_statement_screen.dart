import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/platform_image.dart';

class Step4BankStatementScreen extends StatefulWidget {
  const Step4BankStatementScreen({super.key});

  @override
  State<Step4BankStatementScreen> createState() =>
      _Step4BankStatementScreenState();
}

class _Step4BankStatementScreenState extends State<Step4BankStatementScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  List<String> _pages = [];
  String? _pdfPassword;
  bool _isPdf = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _pages = List.from(provider.submission.bankStatement?.pages ?? []);
    _isPdf = provider.submission.bankStatement?.isPdf ?? false;
    _pdfPassword = provider.submission.bankStatement?.pdfPassword;
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _pages = [path];
        _isPdf = true;
      });
      context
          .read<SubmissionProvider>()
          .setBankStatementPages([path], isPdf: true);
      _showPasswordDialogIfNeeded();
    }
  }

  Future<void> _capturePage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _pages.add(image.path);
        _isPdf = false;
      });
      context.read<SubmissionProvider>().addBankStatementPage(image.path);
    }
  }

  Future<void> _selectFromGallery() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _pages.addAll(images.map((e) => e.path));
        _isPdf = false;
      });
      for (final image in images) {
        context.read<SubmissionProvider>().addBankStatementPage(image.path);
      }
    }
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
    });
    context
        .read<SubmissionProvider>()
        .setBankStatementPages(_pages, isPdf: _isPdf);
  }

  void _showPasswordDialogIfNeeded() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Is this PDF password protected?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'PDF Password (if required)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onChanged: (value) => _pdfPassword = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pdfPassword = null;
              Navigator.of(context).pop();
            },
            child: const Text('Not Required'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_pdfPassword != null && _pdfPassword!.isNotEmpty) {
                context
                    .read<SubmissionProvider>()
                    .setBankStatementPassword(_pdfPassword!);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _proceedToNext() {
    if (_pages.isNotEmpty) {
      context.go(AppRoutes.step5PersonalData);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload bank statement (last 6 months)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 4: Bank Statement'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requirements',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text('• Must be last 6 months'),
                    const Text('• If PDF locked → password entry supported'),
                    const Text('• Support multi-page capture'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_pages.isEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploadPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Upload PDF'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _capturePage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _selectFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select from Gallery'),
              ),
            ] else ...[
              Text(
                'Uploaded Pages (${_pages.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _isPdf && index == 0
                              ? const Center(
                                  child: Icon(Icons.picture_as_pdf, size: 48),
                                )
                              : PlatformImage(
                                  imagePath: _pages[index],
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.red,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: Colors.white,
                            onPressed: () => _removePage(index),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Page ${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isPdf ? _uploadPdf : _capturePage,
                icon: Icon(_isPdf ? Icons.picture_as_pdf : Icons.add),
                label: Text(_isPdf ? 'Change PDF' : 'Add More Pages'),
              ),
            ],
            if (_pdfPassword != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('PDF Password: ${'*' * _pdfPassword!.length}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _proceedToNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Next: Personal Data'),
            ),
          ],
        ),
      ),
    );
  }
}

