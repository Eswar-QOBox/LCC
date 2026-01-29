import './document_submission.dart';
import './user.dart';

class MeResponse {
  final User user;
  final PersonalData? personalData;

  const MeResponse({
    required this.user,
    required this.personalData,
  });
}

