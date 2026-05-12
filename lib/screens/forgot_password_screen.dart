import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_toast.dart';
import '../widgets/auth_theme_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSuccess = false;
  String? _tempPassword;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final result = await authProvider.forgotPassword(
        _emailController.text.trim(),
      );

      if (mounted) {
        if (result != null) {
          setState(() {
            _isSuccess = true;
            _successMessage = result['message'] as String?;
            _tempPassword = result['tempPassword'] as String?;
          });
        } else {
          PremiumToast.showError(
            context,
            authProvider.errorMessage ?? 'Failed to process request',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthThemedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AuthGlassCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => context.go(AppRoutes.login),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.white,
                          ),
                        ),
                        const Center(child: AuthLogoBadge(size: 78)),
                        const SizedBox(height: 14),
                        Text(
                          _isSuccess ? 'Request Submitted' : 'Forgot Password',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSuccess
                              ? (_successMessage ??
                                    'Password reset request processed')
                              : 'Enter your email or phone to get a temporary password',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (!_isSuccess) ...[
                          _buildInputLabel('Email or Phone'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              hintText: 'Enter email or phone number',
                              prefix: Icons.person_outline_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email or phone';
                              }
                              final isEmail =
                                  value.contains('@') && value.contains('.');
                              final isPhone = RegExp(
                                r'^\d{10,}$',
                              ).hasMatch(value);
                              if (!isEmail && !isPhone) {
                                return 'Please enter a valid email or phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return AuthLightCtaButton(
                                label: 'Send Reset Request',
                                isLoading: authProvider.isLoading,
                                height: 58,
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleForgotPassword,
                              );
                            },
                          ),
                        ] else ...[
                          if (_tempPassword != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Temporary Password',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    _tempPassword!,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 18),
                          AuthLightCtaButton(
                            label: 'Back to Login',
                            height: 58,
                            onPressed: () => context.go(AppRoutes.login),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xB3FFFFFF),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
      prefixIcon: Icon(prefix, color: Colors.white.withValues(alpha: 0.70)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.8),
      ),
    );
  }
}
