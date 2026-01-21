import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/submission_provider.dart';
import 'providers/application_provider.dart';
import 'utils/app_theme.dart';
import 'screens/pdf_download_screen.dart';

/// Quick test entry point - goes directly to PDF download screen
/// Run with: flutter run -t lib/main_pdf_test.dart
void main() {
  runApp(const PdfTestApp());
}

class PdfTestApp extends StatelessWidget {
  const PdfTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = SubmissionProvider();
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
      ],
      child: MaterialApp(
        title: 'PDF Download Test',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: const PdfDownloadScreen(),
      ),
    );
  }
}
