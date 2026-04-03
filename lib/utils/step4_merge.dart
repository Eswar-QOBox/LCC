/// Merges patches into existing [step4BankStatement] so one screen (e.g. main bank
/// or main salary) does not wipe co-applicant fields stored in the same map.
Map<String, dynamic> mergeStep4BankStatement(
  Map<String, dynamic>? existing,
  Map<String, dynamic> patch,
) {
  final base = Map<String, dynamic>.from(existing ?? {});
  base.addAll(patch);
  return base;
}
