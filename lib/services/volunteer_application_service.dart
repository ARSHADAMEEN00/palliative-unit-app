import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class PublicUnit {
  const PublicUnit({
    required this.id,
    required this.name,
    required this.code,
    this.village,
    this.district,
  });

  final String id;
  final String name;
  final String code;
  final String? village;
  final String? district;

  String get locationLabel => [village, district]
      .where((item) => item != null && item.trim().isNotEmpty)
      .cast<String>()
      .join(', ');

  factory PublicUnit.fromJson(Map<String, dynamic> json) => PublicUnit(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    village: json['village']?.toString(),
    district: json['district']?.toString(),
  );
}

class VolunteerApplicationService {
  VolunteerApplicationService._();

  static Future<List<PublicUnit>> getUnits() async {
    final result = await ApiService.get<Map<String, dynamic>>(
      ApiConfig.publicUnitsEndpoint,
    );
    if (result.isSuccess && result.data != null) {
      return (result.data!['units'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => PublicUnit.fromJson(Map<String, dynamic>.from(item)))
          .where((unit) => unit.id.isNotEmpty)
          .toList();
    }
    throw Exception(result.error ?? 'Failed to load palliative care units');
  }

  static Future<void> submit({
    required String unitId,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String village,
    required String ward,
    required String place,
    String address = '',
    String phone2 = '',
  }) async {
    final result = await ApiService.post<Map<String, dynamic>>(
      ApiConfig.volunteerApplicationEndpoint,
      body: {
        'unitId': unitId,
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone.trim(),
        'phone2': phone2.trim(),
        'village': village.trim(),
        'ward': ward.trim(),
        'place': place.trim(),
        'address': address.trim(),
      },
    );
    if (!result.isSuccess) {
      throw Exception(result.error ?? 'Failed to submit volunteer application');
    }
  }

  static Future<VolunteerActivity> getMyActivity() async {
    final result = await ApiService.get<Map<String, dynamic>>(
      ApiConfig.volunteerActivityEndpoint,
    );
    if (result.isSuccess && result.data != null) {
      return VolunteerActivity.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to load volunteer activity');
  }
}
