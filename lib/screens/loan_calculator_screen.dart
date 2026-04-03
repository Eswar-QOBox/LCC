import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // NOTE: Do not use `late` here. During hot reload, `initState()` is not called,
  // and late fields would crash with LateInitializationError.
  final TextEditingController _loanAmountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _tenureMonthsController = TextEditingController();
  bool _isProgrammaticTextUpdate = false;

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
  double get _monthlyRatePercent => _interestRate / 12.0;

  String _formatRupees(num amount) => '₹ ${_formatNumber(amount.round())}';

  List<_AmortizationRow> _buildAmortizationSchedule() {
    final principal = _loanAmount;
    final months = _tenureMonths.round();
    if (principal <= 0 || months <= 0) return const [];

    final monthlyRate = _interestRate / 12 / 100;
    final emi = _monthlyEMI;

    double balance = principal;
    final rows = <_AmortizationRow>[];

    for (int i = 1; i <= months; i++) {
      final interest = monthlyRate == 0 ? 0.0 : balance * monthlyRate;
      double principalPaid = emi - interest;
      if (principalPaid < 0) principalPaid = 0;

      balance -= principalPaid;
      if (balance < 0) balance = 0;

      rows.add(
        _AmortizationRow(
          month: i,
          emi: emi,
          interest: interest,
          principal: principalPaid,
          balance: balance,
        ),
      );

      if (balance <= 0) break;
    }

    return rows;
  }

  Future<void> _showRepaymentSchedule(BuildContext context) async {
    final rows = _buildAmortizationSchedule(); // compute once per open
    if (rows.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Repayment Schedule',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'EMI: ${_formatRupees(_monthlyEMI)} • Tenure: ${_tenureMonths.round()} months • Rate: ${_interestRate.toStringAsFixed(1)}% p.a.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 1),
                    itemBuilder: (context, index) {
                      final r = rows[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${r.month}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        title: Text(
                          'EMI: ${_formatRupees(r.emi)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Principal: ${_formatRupees(r.principal)}  •  Interest: ${_formatRupees(r.interest)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatRupees(r.balance),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'balance',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
  void initState() {
    super.initState();
    _setControllerText(_loanAmountController, _formatNumber(_loanAmount.round()));
    _setControllerText(_interestRateController, _interestRate.toStringAsFixed(1));
    _setControllerText(_tenureMonthsController, _tenureMonths.round().toString());
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload: keep text fields in sync with state.
    _setControllerText(_loanAmountController, _formatNumber(_loanAmount.round()));
    _setControllerText(_interestRateController, _interestRate.toStringAsFixed(1));
    _setControllerText(_tenureMonthsController, _tenureMonths.round().toString());
  }

  @override
  void dispose() {
    _loanAmountController.dispose();
    _interestRateController.dispose();
    _tenureMonthsController.dispose();
    super.dispose();
  }

  void _setControllerText(TextEditingController controller, String text) {
    _isProgrammaticTextUpdate = true;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _isProgrammaticTextUpdate = false;
  }

  double? _parseNumber(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void _applyLoanAmountFromText({bool formatAfter = false}) {
    final parsed = _parseNumber(_loanAmountController.text);
    if (parsed == null) return;
    final next = parsed.clamp(10000, 10000000).toDouble();
    setState(() => _loanAmount = next);
    if (formatAfter) _setControllerText(_loanAmountController, _formatNumber(_loanAmount.round()));
  }

  void _applyInterestRateFromText({bool formatAfter = false}) {
    final parsed = _parseNumber(_interestRateController.text);
    if (parsed == null) return;
    final next = parsed.clamp(1, 30).toDouble();
    setState(() => _interestRate = next);
    if (formatAfter) _setControllerText(_interestRateController, _interestRate.toStringAsFixed(1));
  }

  void _applyTenureFromText({bool formatAfter = false}) {
    final parsed = _parseNumber(_tenureMonthsController.text);
    if (parsed == null) return;
    final next = parsed.clamp(3, 360).toDouble();
    setState(() => _tenureMonths = next);
    if (formatAfter) _setControllerText(_tenureMonthsController, _tenureMonths.round().toString());
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
                      controller: _loanAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                      onTextChanged: () {
                        if (_isProgrammaticTextUpdate) return;
                        _applyLoanAmountFromText(formatAfter: false);
                      },
                      onTextEditingComplete: () => _applyLoanAmountFromText(formatAfter: true),
                      onChanged: (value) {
                        setState(() {
                          _loanAmount = value;
                        });
                        _setControllerText(_loanAmountController, _formatNumber(_loanAmount.round()));
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
                      displayValue:
                          '${_interestRate.toStringAsFixed(1)}% p.a.  •  ${_monthlyRatePercent.toStringAsFixed(2)}% p.m.',
                      minLabel: '1%',
                      maxLabel: '30%',
                      prefix: '%',
                      suffix: '% per annum',
                      controller: _interestRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onTextChanged: () {
                        if (_isProgrammaticTextUpdate) return;
                        _applyInterestRateFromText(formatAfter: false);
                      },
                      onTextEditingComplete: () => _applyInterestRateFromText(formatAfter: true),
                      onChanged: (value) {
                        setState(() {
                          _interestRate = value;
                        });
                        _setControllerText(_interestRateController, _interestRate.toStringAsFixed(1));
                      },
                      badgeColor: const Color(0xFFDBEAFE),
                      badgeTextColor: AppTheme.primaryColor,
                      isPrefixIcon: true,
                      helperText:
                          'That is about ${_monthlyRatePercent.toStringAsFixed(2)}% per month (p.m.).',
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
                      controller: _tenureMonthsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onTextChanged: () {
                        if (_isProgrammaticTextUpdate) return;
                        _applyTenureFromText(formatAfter: false);
                      },
                      onTextEditingComplete: () => _applyTenureFromText(formatAfter: true),
                      onChanged: (value) {
                        setState(() {
                          _tenureMonths = value;
                        });
                        _setControllerText(_tenureMonthsController, _tenureMonths.round().toString());
                      },
                      badgeColor: const Color(0xFFF3E8FF),
                      badgeTextColor: const Color(0xFF9333EA),
                      isPrefixIcon: true,
                    ),
                    const SizedBox(height: 32),

                    // Loan Summary Section
                    _buildLoanSummary(context),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _showRepaymentSchedule(context),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text(
                          'View Repayment Schedule',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          elevation: 0,
                          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'EMI shown is an estimate. Actual EMI may vary based on bank charges.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
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
    required TextEditingController controller,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
    required VoidCallback onTextChanged,
    required VoidCallback onTextEditingComplete,
    required ValueChanged<double> onChanged,
    required Color badgeColor,
    required Color badgeTextColor,
    int? divisions,
    bool isPrefixIcon = false,
    String? helperText,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    onChanged: (_) => onTextChanged(),
                    onEditingComplete: onTextEditingComplete,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
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
        if (helperText != null) ...[
          const SizedBox(height: 10),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

class _AmortizationRow {
  final int month;
  final double emi;
  final double interest;
  final double principal;
  final double balance;

  const _AmortizationRow({
    required this.month,
    required this.emi,
    required this.interest,
    required this.principal,
    required this.balance,
  });
}
