import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class PublicUserRegistrationResult {
  const PublicUserRegistrationResult({
    required this.email,
    required this.expiresInMinutes,
    required this.resendAfterSeconds,
  });

  final String email;
  final int expiresInMinutes;
  final int resendAfterSeconds;
}

class PublicUserService {
  PublicUserService._();

  static Future<PublicUserRegistrationResult> register({
    required String unitId,
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.publicUserRegistrationEndpoint,
      body: {
        'unitId': unitId,
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Failed to create account');
    }
    final raw = result.data?['registration'];
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return PublicUserRegistrationResult(
      email: data['email']?.toString() ?? email.trim(),
      expiresInMinutes:
          int.tryParse(data['expiresInMinutes']?.toString() ?? '') ?? 10,
      resendAfterSeconds:
          int.tryParse(data['resendAfterSeconds']?.toString() ?? '') ?? 60,
    );
  }

  static Future<int> requestPasswordReset(String email) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.passwordResetRequestEndpoint,
      body: {'email': email.trim()},
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Could not send reset code');
    }
    return int.tryParse(result.data?['resendAfterSeconds']?.toString() ?? '') ??
        60;
  }

  static Future<String> verifyPasswordReset({
    required String email,
    required String otp,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.passwordResetVerifyEndpoint,
      body: {'email': email.trim(), 'otp': otp.trim()},
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Could not verify reset code');
    }
    final token = result.data?['resetToken']?.toString() ?? '';
    if (token.isEmpty) throw Exception('Password reset session is invalid');
    return token;
  }

  static Future<void> completePasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.passwordResetCompleteEndpoint,
      body: {'resetToken': resetToken, 'newPassword': newPassword},
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Could not update password');
    }
  }
}
