import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/submission_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/application_provider.dart';
import 'utils/app_theme.dart';
import 'utils/app_routes.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_home_screen.dart';
import 'screens/instructions_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/step1_selfie_screen.dart';
import 'screens/step2_aadhaar_screen.dart';
import 'screens/step3_pan_screen.dart';
import 'screens/step4_bank_statement_screen.dart';
import 'screens/step5_personal_data_screen.dart';
import 'screens/step5_1_salary_slips_screen.dart';
import 'screens/step6_preview_screen.dart';
import 'screens/submission_success_screen.dart';
import 'screens/pdf_download_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = SubmissionProvider();
            // Initialize draft loading asynchronously
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
      ],
      child: MaterialApp.router(
        title: 'JSEE Solutions',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.instructions,
      builder: (context, state) {
        final loanType = state.uri.queryParameters['loanType'];
        return InstructionsScreen(loanType: loanType);
      },
    ),
    GoRoute(
      path: AppRoutes.termsAndConditions,
      builder: (context, state) => const TermsScreen(),
    ),
    GoRoute(
      path: AppRoutes.step1Selfie,
      builder: (context, state) => const Step1SelfieScreen(),
    ),
    GoRoute(
      path: AppRoutes.step2Aadhaar,
      builder: (context, state) => const Step2AadhaarScreen(),
    ),
    GoRoute(
      path: AppRoutes.step3Pan,
      builder: (context, state) => const Step3PanScreen(),
    ),
    GoRoute(
      path: AppRoutes.step4BankStatement,
      builder: (context, state) => const Step4BankStatementScreen(),
    ),
    GoRoute(
      path: AppRoutes.step5PersonalData,
      builder: (context, state) => const Step5PersonalDataScreen(),
    ),
    GoRoute(
      path: AppRoutes.step5_1SalarySlips,
      builder: (context, state) => const Step5_1SalarySlipsScreen(),
    ),
    GoRoute(
      path: AppRoutes.step6Preview,
      builder: (context, state) => const Step6PreviewScreen(),
    ),
    GoRoute(
      path: AppRoutes.submissionSuccess,
      builder: (context, state) => const SubmissionSuccessScreen(),
    ),
    GoRoute(
      path: AppRoutes.pdfDownload,
      builder: (context, state) => const PdfDownloadScreen(),
    ),
  ],
);
