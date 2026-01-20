import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../widgets/premium_card.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final TextEditingController _loanAmountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _tenureController = TextEditingController();

  double _loanAmount = 500000; // Default: 5 Lakh
  double _interestRate = 12.0; // Default: 12%
  int _tenure = 60; // Default: 60 months (5 years)

  @override
  void initState() {
    super.initState();
    _loanAmountController.text = _formatAmount(_loanAmount);
    _interestRateController.text = _interestRate.toStringAsFixed(1);
    _tenureController.text = _tenure.toString();
    _loanAmountController.addListener(_onLoanAmountChanged);
    _interestRateController.addListener(_onInterestRateChanged);
    _tenureController.addListener(_onTenureChanged);
  }

  @override
  void dispose() {
    _loanAmountController.dispose();
    _interestRateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _onLoanAmountChanged() {
    final text = _loanAmountController.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (text.isNotEmpty) {
      final value = double.tryParse(text) ?? 0;
      if (value != _loanAmount && value >= 10000 && value <= 100000000) {
        setState(() {
          _loanAmount = value;
        });
      }
    }
  }

  void _onInterestRateChanged() {
    final text = _interestRateController.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (text.isNotEmpty) {
      final value = double.tryParse(text) ?? 0;
      if (value != _interestRate && value >= 1 && value <= 30) {
        setState(() {
          _interestRate = value;
        });
      }
    }
  }

  void _onTenureChanged() {
    final text = _tenureController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.isNotEmpty) {
      final value = int.tryParse(text) ?? 0;
      if (value != _tenure && value >= 3 && value <= 360) {
        setState(() {
          _tenure = value;
        });
      }
    }
  }

  void _updateLoanAmountFromSlider(double value) {
    setState(() {
      _loanAmount = value;
      _loanAmountController.text = _formatAmount(_loanAmount);
    });
  }

  void _updateInterestRateFromSlider(double value) {
    setState(() {
      _interestRate = value;
      _interestRateController.text = _interestRate.toStringAsFixed(1);
    });
  }

  void _updateTenureFromSlider(double value) {
    setState(() {
      _tenure = value.toInt();
      _tenureController.text = _tenure.toString();
    });
  }

  double _calculateEMI() {
    if (_loanAmount <= 0 || _interestRate <= 0 || _tenure <= 0) {
      return 0;
    }
    final monthlyRate = _interestRate / 12 / 100;
    if (monthlyRate == 0) {
      return _loanAmount / _tenure;
    }
    final emi = _loanAmount *
        monthlyRate *
        math.pow(1 + monthlyRate, _tenure) /
        (math.pow(1 + monthlyRate, _tenure) - 1);
    return emi;
  }

  double _calculateTotalAmount() {
    final emi = _calculateEMI();
    return emi * _tenure;
  }

  double _calculateTotalInterest() {
    return _calculateTotalAmount() - _loanAmount;
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final emi = _calculateEMI();
    final totalAmount = _calculateTotalAmount();
    final totalInterest = _calculateTotalInterest();

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calculate,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Loan Calculator',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Calculate your EMI and total amount',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Loan Amount Section
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Loan Amount',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatCurrency(_loanAmount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Slider
                      Slider(
                        value: _loanAmount.clamp(10000, 100000000),
                        min: 10000,
                        max: 100000000,
                        divisions: 99,
                        activeColor: colorScheme.primary,
                        onChanged: _updateLoanAmountFromSlider,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹10K',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '₹10Cr',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Numeric Input
                      TextField(
                        controller: _loanAmountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Enter loan amount',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          suffixText: 'INR',
                        ),
                        onChanged: (value) {
                          final text = value.replaceAll(RegExp(r'[^\d.]'), '');
                          if (text.isNotEmpty) {
                            final numValue = double.tryParse(text) ?? 0;
                            if (numValue >= 10000 && numValue <= 100000000) {
                              setState(() {
                                _loanAmount = numValue;
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Interest Rate Section
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rate of Interest',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_interestRate.toStringAsFixed(1)}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Slider
                      Slider(
                        value: _interestRate.clamp(1.0, 30.0),
                        min: 1.0,
                        max: 30.0,
                        divisions: 290,
                        activeColor: colorScheme.secondary,
                        onChanged: _updateInterestRateFromSlider,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '30%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Numeric Input
                      TextField(
                        controller: _interestRateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Enter interest rate',
                          prefixIcon: const Icon(Icons.percent),
                          suffixText: '% per annum',
                        ),
                        onChanged: (value) {
                          final text = value.replaceAll(RegExp(r'[^\d.]'), '');
                          if (text.isNotEmpty) {
                            final numValue = double.tryParse(text) ?? 0;
                            if (numValue >= 1 && numValue <= 30) {
                              setState(() {
                                _interestRate = numValue;
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tenure Section
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tenure',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_tenure months',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Slider
                      Slider(
                        value: _tenure.clamp(3, 360).toDouble(),
                        min: 3,
                        max: 360,
                        divisions: 357,
                        activeColor: colorScheme.tertiary,
                        onChanged: _updateTenureFromSlider,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '3 months',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '30 years',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Numeric Input
                      TextField(
                        controller: _tenureController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Enter tenure',
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixText: 'months',
                        ),
                        onChanged: (value) {
                          final text = value.replaceAll(RegExp(r'[^\d]'), '');
                          if (text.isNotEmpty) {
                            final numValue = int.tryParse(text) ?? 0;
                            if (numValue >= 3 && numValue <= 360) {
                              setState(() {
                                _tenure = numValue;
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Results Section
                PremiumCard(
                  gradientColors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loan Summary',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // EMI
                      _buildResultRow(
                        context,
                        label: 'Monthly EMI',
                        value: _formatCurrency(emi),
                        icon: Icons.payment,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(height: 16),
                      // Total Amount
                      _buildResultRow(
                        context,
                        label: 'Total Amount',
                        value: _formatCurrency(totalAmount),
                        icon: Icons.account_balance_wallet,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      // Total Interest
                      _buildResultRow(
                        context,
                        label: 'Total Interest',
                        value: _formatCurrency(totalInterest),
                        icon: Icons.trending_up,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(height: 8),
                      Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
                      const SizedBox(height: 8),
                      // Principal Amount
                      _buildResultRow(
                        context,
                        label: 'Principal Amount',
                        value: _formatCurrency(_loanAmount),
                        icon: Icons.money,
                        color: colorScheme.onSurfaceVariant,
                        isSecondary: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isSecondary = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSecondary
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isSecondary ? colorScheme.onSurfaceVariant : color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
