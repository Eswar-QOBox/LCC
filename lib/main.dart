import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/submission_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/application_provider.dart';
import 'utils/app_theme.dart';
import 'utils/app_theme_mode.dart';
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
import 'screens/view_submitted_screen.dart';
import 'screens/loan_calculator_screen.dart';
import 'screens/business_loan_type_screen.dart';
import 'screens/professional_loan_type_screen.dart';
import 'screens/step5_business_docs_screen.dart';
import 'screens/step5_professional_docs_screen.dart';
import 'screens/step5_student_docs_screen.dart';
import 'screens/step5_property_details_screen.dart';
import 'screens/step4_spouse_aadhaar_screen.dart';
import 'screens/step5_spouse_pan_screen.dart';
import 'screens/step6_msme_screen.dart';
import 'screens/step7_ohp_screen.dart';
import 'screens/partner_count_screen.dart';
import 'screens/partner_aadhaar_screen.dart';
import 'screens/partner_pan_screen.dart';
import 'screens/co_applicant_choice_screen.dart';
import 'screens/co_applicant_firm_docs_screen.dart';
import 'screens/co_applicant_firm_kyc_screen.dart';
import 'screens/support_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
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
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeModeNotifier,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            title: 'JSEE Solutions',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  final router = GoRouter.of(context);
                  // Use GoRouter's stack so back from e.g. Personal Loan → Instructions returns to home
                  if (router.canPop()) {
                    router.pop();
                  } else {
                    // No route to pop — go to home instead of exiting the app
                    router.go(AppRoutes.home);
                  }
                },
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
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
        final businessLoanType = state.uri.queryParameters['businessLoanType'];
        final professionalLoanType = state.uri.queryParameters['professionalLoanType'];
        final withCoApplicant = state.uri.queryParameters['withCoApplicant'] == 'true';
        final coApplicantFirmType = state.uri.queryParameters['coApplicantFirmType'];
        return InstructionsScreen(
          loanType: loanType,
          businessLoanType: businessLoanType,
          professionalLoanType: professionalLoanType,
          withCoApplicant: withCoApplicant,
          coApplicantFirmType: coApplicantFirmType,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.businessLoanType,
      builder: (context, state) => const BusinessLoanTypeScreen(),
    ),
    GoRoute(
      path: AppRoutes.professionalLoanType,
      builder: (context, state) => const ProfessionalLoanTypeScreen(),
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
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step2AadhaarScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step3Pan,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step3PanScreen(
          backRouteOverride: fromPreview ? AppRoutes.step6Preview : null,
          nextRouteOverride: fromPreview ? AppRoutes.step6Preview : null,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.step4SpouseAadhaar,
      builder: (context, state) => const Step4SpouseAadhaarScreen(),
    ),
    GoRoute(
      path: AppRoutes.step5SpousePan,
      builder: (context, state) => const Step5SpousePanScreen(),
    ),
    GoRoute(
      path: AppRoutes.step4BankStatement,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step4BankStatementScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.coApplicantChoice,
      builder: (context, state) => const CoApplicantChoiceScreen(),
    ),
    GoRoute(
      path: AppRoutes.coApplicantAadhaar,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step2AadhaarScreen(
          isCoApplicant: true,
          fromPreview: fromPreview,
          backRouteOverride:
              fromPreview ? AppRoutes.step6Preview : AppRoutes.step5_1SalarySlips,
          nextRouteOverride: AppRoutes.coApplicantPan,
          progressStepOverride: 6,
          totalStepsOverride: 12,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.coApplicantPan,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step3PanScreen(
          isCoApplicant: true,
          backRouteOverride:
              fromPreview ? AppRoutes.step6Preview : AppRoutes.coApplicantAadhaar,
          nextRouteOverride: fromPreview
              ? AppRoutes.step6Preview
              : AppRoutes.coApplicantBankStatement,
          progressStepOverride: 7,
          totalStepsOverride: 12,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.coApplicantBankStatement,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step4BankStatementScreen(
          fromPreview: fromPreview,
          isCoApplicant: true,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.coApplicantSalarySlips,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step5_1SalarySlipsScreen(
          fromPreview: fromPreview,
          isCoApplicant: true,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.coApplicantFirmDocs,
      builder: (context, state) {
        final firmType =
            state.uri.queryParameters['firmType'] ?? 'partnership';
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return CoApplicantFirmDocsScreen(
          firmType: firmType,
          fromPreview: fromPreview,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.coApplicantFirmKyc,
      builder: (context, state) {
        final firmType =
            state.uri.queryParameters['firmType'] ?? 'partnership';
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return CoApplicantFirmKycScreen(
          firmType: firmType,
          fromPreview: fromPreview,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.partnerCount,
      builder: (context, state) => const PartnerCountScreen(),
    ),
    GoRoute(
      path: AppRoutes.partnerAadhaar,
      builder: (context, state) {
        final i = int.tryParse(state.uri.queryParameters['i'] ?? '') ?? 1;
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return PartnerAadhaarScreen(partnerIndex: i, fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.partnerPan,
      builder: (context, state) {
        final i = int.tryParse(state.uri.queryParameters['i'] ?? '') ?? 1;
        return PartnerPanScreen(partnerIndex: i);
      },
    ),
    GoRoute(
      path: AppRoutes.step5PersonalData,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step5PersonalDataScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step5_1SalarySlips,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step5_1SalarySlipsScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step5BusinessDocs,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step5BusinessDocsScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step5ProfessionalDocs,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step5ProfessionalDocsScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step5StudentDocs,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step5StudentDocsScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step5PropertyDetails,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step5PropertyDetailsScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step6Msme,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step6MsmeScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step7Ohp,
      builder: (context, state) {
        final fromPreview = state.uri.queryParameters['from'] == 'preview';
        return Step7OhpScreen(fromPreview: fromPreview);
      },
    ),
    GoRoute(
      path: AppRoutes.step6Preview,
      builder: (context, state) => Step6PreviewScreen(
        mode: state.uri.queryParameters['mode'],
        backRouteOverride: state.uri.queryParameters['back'],
      ),
    ),
    GoRoute(
      path: AppRoutes.submissionSuccess,
      builder: (context, state) => const SubmissionSuccessScreen(),
    ),
    GoRoute(
      path: AppRoutes.pdfDownload,
      builder: (context, state) => const PdfDownloadScreen(),
    ),
    GoRoute(
      path: AppRoutes.viewSubmitted,
      builder: (context, state) => const ViewSubmittedScreen(),
    ),
    GoRoute(
      path: AppRoutes.loanCalculator,
      builder: (context, state) => const LoanCalculatorScreen(),
    ),
    GoRoute(
      path: AppRoutes.support,
      builder: (context, state) => const SupportScreen(),
    ),
  ],
);
