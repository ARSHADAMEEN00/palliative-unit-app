import 'package:intl/intl.dart';

class PatientEnquiry {
  final String id;
  final String unitId;
  final String name;
  final int? age;
  final String address;
  final String phone;
  final String? phone2;
  final String village;
  final String? ward;
  final String? caregiverName;
  final String? caregiverPhone;
  final String? referredByName;
  final String? referredByPhone;
  final String? submittedByVolunteerId;
  final String? submittedByVolunteerName;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PatientEnquiry({
    required this.id,
    required this.unitId,
    required this.name,
    this.age,
    this.address = '',
    required this.phone,
    this.phone2,
    required this.village,
    this.ward,
    this.caregiverName,
    this.caregiverPhone,
    this.referredByName,
    this.referredByPhone,
    this.submittedByVolunteerId,
    this.submittedByVolunteerName,
    this.status = 'pending',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isVerified => status.toLowerCase() == 'verified';
  bool get isRejected => status.toLowerCase() == 'rejected';

  /// Helper getter for referrer name with backwards compatibility
  String? get displayReferredByName {
    if (referredByName != null && referredByName!.trim().isNotEmpty) {
      return referredByName!.trim();
    }
    if (caregiverName != null && caregiverName!.trim().isNotEmpty) {
      return caregiverName!.trim();
    }
    return null;
  }

  /// Helper getter for referrer phone with backwards compatibility
  String? get displayReferredByPhone {
    if (referredByPhone != null && referredByPhone!.trim().isNotEmpty) {
      return referredByPhone!.trim();
    }
    if (caregiverPhone != null && caregiverPhone!.trim().isNotEmpty) {
      return caregiverPhone!.trim();
    }
    return null;
  }

  factory PatientEnquiry.fromJson(Map<String, dynamic> json) {
    final refName = json['referredByName']?.toString() ?? json['caregiverName']?.toString();
    final refPhone = json['referredByPhone']?.toString() ?? json['caregiverPhone']?.toString();
    return PatientEnquiry(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      unitId: json['unitId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse(json['age']?.toString() ?? ''),
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      phone2: json['phone2']?.toString(),
      village: json['village']?.toString() ?? '',
      ward: json['ward']?.toString(),
      caregiverName: json['caregiverName']?.toString() ?? refName,
      caregiverPhone: json['caregiverPhone']?.toString() ?? refPhone,
      referredByName: refName,
      referredByPhone: refPhone,
      submittedByVolunteerId: json['submittedByVolunteerId']?.toString(),
      submittedByVolunteerName: json['submittedByVolunteerName']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final refName = displayReferredByName;
    final refPhone = displayReferredByPhone;
    return {
      'name': name,
      if (age != null) 'age': age,
      'address': address,
      'phone': phone,
      if (phone2 != null && phone2!.isNotEmpty) 'phone2': phone2,
      'village': village,
      if (ward != null && ward!.isNotEmpty) 'ward': ward,
      if (refName != null && refName.isNotEmpty) ...{
        'caregiverName': refName,
        'referredByName': refName,
      },
      if (refPhone != null && refPhone.isNotEmpty) ...{
        'caregiverPhone': refPhone,
        'referredByPhone': refPhone,
      },
      if (submittedByVolunteerId != null)
        'submittedByVolunteerId': submittedByVolunteerId,
      if (submittedByVolunteerName != null)
        'submittedByVolunteerName': submittedByVolunteerName,
    };
  }

  /// Formats all details with clear labels ready for WhatsApp sharing.
  String toWhatsAppMessage({String? unitName}) {
    final buffer = StringBuffer();
    buffer.writeln('📋 *NEW PATIENT ENQUIRY*');
    if (unitName != null && unitName.trim().isNotEmpty) {
      buffer.writeln('🏥 *Care Unit:* ${unitName.trim()}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('👤 *Patient Name:* $name');
    if (age != null && age! > 0) {
      buffer.writeln('🎂 *Age:* $age');
    } else {
      buffer.writeln('🎂 *Age:* Not provided');
    }
    if (address.trim().isNotEmpty) {
      buffer.writeln('🏠 *Address:* ${address.trim()}');
    }
    buffer.writeln('📞 *Primary Phone:* $phone');
    if (phone2 != null && phone2!.trim().isNotEmpty) {
      buffer.writeln('📱 *Secondary Phone:* ${phone2!.trim()}');
    }
    buffer.writeln('📍 *Village:* $village');
    if (ward != null && ward!.trim().isNotEmpty) {
      buffer.writeln('🏢 *Ward:* ${ward!.trim()}');
    }
    final refName = displayReferredByName;
    final refPhone = displayReferredByPhone;
    if (refName != null) {
      buffer.writeln('🤝 *Referred By:* $refName');
    }
    if (refPhone != null) {
      buffer.writeln('📲 *Referred By Phone:* $refPhone');
    }
    if (submittedByVolunteerName != null &&
        submittedByVolunteerName!.trim().isNotEmpty) {
      buffer.writeln(
        '🙋 *Submitted By:* ${submittedByVolunteerName!.trim()} (Volunteer)',
      );
    } else {
      buffer.writeln('🌐 *Submitted Via:* Public Form');
    }
    if (createdAt != null) {
      buffer.writeln(
        '📅 *Date:* ${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt!)}',
      );
    }
    return buffer.toString();
  }
}
