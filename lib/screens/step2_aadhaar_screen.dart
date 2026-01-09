import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/submission_provider.dart';
import '../utils/app_routes.dart';
import '../widgets/platform_image.dart';

class Step2AadhaarScreen extends StatefulWidget {
  const Step2AadhaarScreen({super.key});

  @override
  State<Step2AadhaarScreen> createState() => _Step2AadhaarScreenState();
}

class _Step2AadhaarScreenState extends State<Step2AadhaarScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _frontPath;
  String? _backPath;
  String? _pdfPassword;
  bool _isPdf = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubmissionProvider>();
    _frontPath = provider.submission.aadhaar?.frontPath;
    _backPath = provider.submission.aadhaar?.backPath;
    _isPdf = provider.submission.aadhaar?.isPdf ?? false;
    _pdfPassword = provider.submission.aadhaar?.pdfPassword;
  }

  Future<void> _captureFront() async {
    if (_isPdf) {
      await _pickPdf('front');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() => _frontPath = image.path);
        context.read<SubmissionProvider>().setAadhaarFront(image.path);
      }
    }
  }

  Future<void> _selectFrontFromGallery() async {
    if (_isPdf) {
      await _pickPdf('front');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _frontPath = image.path);
        context.read<SubmissionProvider>().setAadhaarFront(image.path);
      }
    }
  }

  Future<void> _captureBack() async {
    if (_isPdf) {
      await _pickPdf('back');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() => _backPath = image.path);
        context.read<SubmissionProvider>().setAadhaarBack(image.path);
      }
    }
  }

  Future<void> _selectBackFromGallery() async {
    if (_isPdf) {
      await _pickPdf('back');
    } else {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _backPath = image.path);
        context.read<SubmissionProvider>().setAadhaarBack(image.path);
      }
    }
  }

  Future<void> _pickPdf(String side) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      if (side == 'front') {
        setState(() {
          _frontPath = path;
          _isPdf = true;
        });
        context.read<SubmissionProvider>().setAadhaarFront(path, isPdf: true);
      } else {
        setState(() {
          _backPath = path;
          _isPdf = true;
        });
        context.read<SubmissionProvider>().setAadhaarBack(path);
      }

      // Check if PDF might be password protected
      _showPasswordDialogIfNeeded();
    }
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
                context.read<SubmissionProvider>().setAadhaarPassword(_pdfPassword!);
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
    if (_frontPath != null && _backPath != null) {
      context.go(AppRoutes.step3Pan);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both front and back sides of Aadhaar card'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2: Aadhaar Card'),
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
                    const Text('• Must include Front & Back'),
                    const Text('• No blur'),
                    const Text('• No glare'),
                    const Text('• If PDF → password entry supported'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Front Side',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_frontPath != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isPdf
                      ? const Center(
                          child: Icon(Icons.picture_as_pdf, size: 64),
                        )
                      : PlatformImage(imagePath: _frontPath!, fit: BoxFit.cover),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureFront,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectFrontFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery/PDF'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),
            Text(
              'Back Side',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_backPath != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isPdf
                      ? const Center(
                          child: Icon(Icons.picture_as_pdf, size: 64),
                        )
                      : PlatformImage(imagePath: _backPath!, fit: BoxFit.cover),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureBack,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectBackFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery/PDF'),
                    ),
                  ),
                ],
              ),
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
              child: const Text('Next: PAN Card'),
            ),
          ],
        ),
      ),
    );
  }
}

