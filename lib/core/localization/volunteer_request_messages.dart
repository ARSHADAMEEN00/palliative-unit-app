import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';

class VolunteerRequestMessages {
  VolunteerRequestMessages._();

  static const String homeVisitMalayalam =
      'ഹോം കെയർ സന്ദർശനത്തിനുള്ള നിങ്ങളുടെ അപേക്ഷ നിലവിൽ റദ്ദാക്കുന്നു. ദയവായി ക്ഷമയോടെ കാത്തിരിക്കുക. മറ്റൊരു തീയതിയിൽ വീണ്ടും അപേക്ഷിക്കാവുന്നതാണ്. നിങ്ങളുടെ സഹകരണത്തിന് നന്ദി. ❤️';

  static const String homeVisitEnglish =
      'Your application for Home Care Visit is currently cancelled. Please bear with us. You may apply again on another date. Thank you for your cooperation. ❤️';

  static const String socialSupportMalayalam =
      'സോഷ്യൽ സപ്പോർട്ടിനായുള്ള നിങ്ങളുടെ അപേക്ഷ നിലവിൽ റദ്ദാക്കുന്നു. ദയവായി ക്ഷമയോടെ കാത്തിരിക്കുക. മറ്റൊരു തീയതിയിൽ വീണ്ടും അപേക്ഷിക്കാവുന്നതാണ്. നിങ്ങളുടെ സഹകരണത്തിന് നന്ദി. ❤️';

  static const String socialSupportEnglish =
      'Your application for Social Support is currently cancelled. Please bear with us. You may apply again on another date. Thank you for your cooperation. ❤️';

  static const String visitAssessmentMalayalam =
      'വിസിറ്റ് അസ്സസ്സ്മെന്റിനായുള്ള നിങ്ങളുടെ അപേക്ഷ നിലവിൽ റദ്ദാക്കുന്നു. ദയവായി ക്ഷമയോടെ കാത്തിരിക്കുക. മറ്റൊരു തീയതിയിൽ വീണ്ടും അപേക്ഷിക്കാവുന്നതാണ്. നിങ്ങളുടെ സഹകരണത്തിന് നന്ദി. ❤️';

  static const String visitAssessmentEnglish =
      'Your application for Visit Assessment is currently cancelled. Please bear with us. You may apply again on another date. Thank you for your cooperation. ❤️';

  /// Returns the friendly encouraging message for Canceled or Declined requests,
  /// strictly matching the requested task type in Malayalam with English fallback.
  static String getPositiveMessage({
    required String taskType,
    String? status,
    String locale = 'ml',
  }) {
    final isMalayalam = locale.toLowerCase().startsWith('ml');
    final normalizedType = taskType.trim().toLowerCase();

    switch (normalizedType) {
      case 'social_support':
        return isMalayalam ? socialSupportMalayalam : socialSupportEnglish;
      case 'visit_assessment':
        return isMalayalam ? visitAssessmentMalayalam : visitAssessmentEnglish;
      case 'home_visit':
      default:
        return isMalayalam ? homeVisitMalayalam : homeVisitEnglish;
    }
  }

  /// Whether the status represents a Canceled or Declined state that requires
  /// a non-discouraging, neutral badge color (never red or warning).
  static bool isNeutralStatus(String? status) {
    if (status == null) return false;
    final s = status.trim().toLowerCase();
    return s == 'cancelled' || s == 'canceled' || s == 'declined' || s == 'rejected';
  }

  /// Returns a neutral badge color for Canceled or Declined states, ensuring
  /// volunteers do not feel discouraged.
  static Color getStatusColor(String? status, {Color? defaultActiveColor}) {
    if (isNeutralStatus(status)) {
      return AppColors.textSecondary;
    }
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'approved' || s == 'completed') {
      return AppColors.success;
    }
    if (s == 'accepted' || s == 'in_progress') {
      return AppColors.primary;
    }
    if (s == 'pending' || s == 'assigned') {
      return defaultActiveColor ?? AppColors.warning;
    }
    return AppColors.textSecondary;
  }

  /// Returns clear standard label for status display: "Canceled", "Declined", etc.
  static String getStatusLabel(String? status) {
    if (status == null || status.isEmpty) return '';
    final s = status.trim().toLowerCase();
    if (s == 'cancelled' || s == 'canceled') return 'Canceled';
    if (s == 'declined' || s == 'rejected') return 'Declined';
    if (s == 'approved') return 'Approved';
    if (s == 'accepted') return 'Accepted';
    if (s == 'completed') return 'Completed';
    if (s == 'in_progress') return 'In Progress';
    if (s == 'assigned') return 'Assigned';
    if (s == 'pending') return 'Pending';
    return status[0].toUpperCase() + status.substring(1);
  }
}
