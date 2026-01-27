import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  double _loanAmount = 500000;
  double _interestRate = 12.0;
  double _tenureMonths = 60;

  // Calculate EMI using the formula: EMI = P * r * (1+r)^n / ((1+r)^n - 1)
  double get _monthlyEMI {
    double principal = _loanAmount;
    double monthlyRate = _interestRate / 12 / 100;
    double n = _tenureMonths;

    if (monthlyRate == 0) {
      return principal / n;
    }

    double emi = principal *
        monthlyRate *
        math.pow(1 + monthlyRate, n) /
        (math.pow(1 + monthlyRate, n) - 1);
    return emi;
  }

  double get _totalAmount => _monthlyEMI * _tenureMonths;
  double get _totalInterest => _totalAmount - _loanAmount;
  double get _principalPercentage => _loanAmount / _totalAmount;

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹ ${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '₹ ${(amount / 100000).toStringAsFixed(2)} L';
    } else {
      return '₹ ${_formatNumber(amount.round())}';
    }
  }

  String _formatNumber(int number) {
    String numStr = number.toString();
    String result = '';
    int count = 0;

    for (int i = numStr.length - 1; i >= 0; i--) {
      count++;
      result = numStr[i] + result;
      if (count == 3 && i != 0) {
        result = ',$result';
        count = 0;
      } else if (count > 3 && (count - 3) % 2 == 0 && i != 0) {
        result = ',$result';
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Loan Amount Section
                    _buildSliderSection(
                      context,
                      label: 'Loan Amount',
                      value: _loanAmount,
                      min: 10000,
                      max: 10000000,
                      displayValue: '₹ ${_formatNumber(_loanAmount.round())}',
                      minLabel: '₹ 10k',
                      maxLabel: '₹ 1Cr',
                      prefix: '₹',
                      suffix: 'INR',
                      inputValue: _formatNumber(_loanAmount.round()),
                      onChanged: (value) {
                        setState(() {
                          _loanAmount = value;
                        });
                      },
                      badgeColor: const Color(0xFFDBEAFE),
                      badgeTextColor: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Interest Rate Section
                    _buildSliderSection(
                      context,
                      label: 'Interest Rate',
                      value: _interestRate,
                      min: 1,
                      max: 30,
                      divisions: 58,
                      displayValue: '${_interestRate.toStringAsFixed(1)}%',
                      minLabel: '1%',
                      maxLabel: '30%',
                      prefix: '%',
                      suffix: '% per annum',
                      inputValue: _interestRate.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _interestRate = value;
                        });
                      },
                      badgeColor: const Color(0xFFDBEAFE),
                      badgeTextColor: AppTheme.primaryColor,
                      isPrefixIcon: true,
                    ),
                    const SizedBox(height: 24),

                    // Tenure Section
                    _buildSliderSection(
                      context,
                      label: 'Tenure',
                      value: _tenureMonths,
                      min: 3,
                      max: 360,
                      displayValue: '${_tenureMonths.round()} months',
                      minLabel: '3 months',
                      maxLabel: '30 years',
                      prefix: 'calendar',
                      suffix: 'months',
                      inputValue: _tenureMonths.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _tenureMonths = value;
                        });
                      },
                      badgeColor: const Color(0xFFF3E8FF),
                      badgeTextColor: const Color(0xFF9333EA),
                      isPrefixIcon: true,
                    ),
                    const SizedBox(height: 32),

                    // Loan Summary Section
                    _buildLoanSummary(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            const Color(0xFF0052CC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => context.go(AppRoutes.home),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Loan Calculator',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 20),
              onPressed: () {
                _showInfoDialog(context);
              },
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('EMI Calculator'),
          ],
        ),
        content: const Text(
          'EMI (Equated Monthly Installment) is calculated using the formula:\n\n'
          'EMI = P × r × (1+r)ⁿ / ((1+r)ⁿ - 1)\n\n'
          'Where:\n'
          '• P = Principal loan amount\n'
          '• r = Monthly interest rate\n'
          '• n = Loan tenure in months',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required String minLabel,
    required String maxLabel,
    required String prefix,
    required String suffix,
    required String inputValue,
    required ValueChanged<double> onChanged,
    required Color badgeColor,
    required Color badgeTextColor,
    int? divisions,
    bool isPrefixIcon = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: AppTheme.primaryColor,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 12,
              elevation: 4,
            ),
            overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            trackHeight: 8,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                maxLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: isPrefixIcon
                    ? Icon(
                        prefix == 'calendar' ? Icons.calendar_month : Icons.percent,
                        color: Colors.grey.shade400,
                        size: 20,
                      )
                    : Text(
                        prefix,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  child: Text(
                    inputValue,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loan Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),

          // Donut Chart
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: DonutChartPainter(
                      principalPercentage: _principalPercentage,
                      principalColor: AppTheme.primaryColor,
                      interestColor: const Color(0xFFF59E0B),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(_totalAmount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: AppTheme.primaryColor,
                label: 'Principal',
                value: _formatCurrency(_loanAmount),
              ),
              const SizedBox(width: 32),
              _buildLegendItem(
                color: const Color(0xFFF59E0B),
                label: 'Interest',
                value: _formatCurrency(_totalInterest),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          const Divider(color: Color(0xFFBFDBFE)),
          const SizedBox(height: 16),

          // Summary Items
          _buildSummaryItem(
            icon: Icons.payments,
            iconBgColor: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            label: 'Monthly EMI',
            value: '₹ ${_formatNumber(_monthlyEMI.round())}',
            valueColor: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            icon: Icons.account_balance_wallet,
            iconBgColor: const Color(0xFFDBEAFE),
            iconColor: AppTheme.primaryColor,
            label: 'Total Amount',
            value: '₹ ${_formatNumber(_totalAmount.round())}',
            valueColor: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            icon: Icons.trending_up,
            iconBgColor: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFEA580C),
            label: 'Total Interest',
            value: '₹ ${_formatNumber(_totalInterest.round())}',
            valueColor: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final double principalPercentage;
  final Color principalColor;
  final Color interestColor;

  DonutChartPainter({
    required this.principalPercentage,
    required this.principalColor,
    required this.interestColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.25;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw interest (background arc)
    paint.color = interestColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi,
      false,
      paint,
    );

    // Draw principal (foreground arc)
    paint.color = principalColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi * principalPercentage,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.principalPercentage != principalPercentage;
  }
}
