class UserProfile {
  final int? userId;
  final String firebaseUid;
  final String? name;           // 닉네임
  final String? role;
  final String? email;
  final String? gender;
  final String? birthdate;      // "YYYY-MM-DD"
  final int? age;
  final double? height;         // cm
  final double? weight;         // kg
  final double? bmi;
  final int? familyId;
  final String? familyName;
  final String? profileImageUrl;

  const UserProfile({
    required this.firebaseUid,
    this.userId,
    this.name,
    this.role,
    this.email,
    this.gender,
    this.birthdate,
    this.age,
    this.height,
    this.weight,
    this.bmi,
    this.familyId,
    this.familyName,
    this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    userId: j['userId'] as int?,
    firebaseUid: j['firebaseUid'] as String,
    name: j['name'] as String?,
    role: j['role'] as String?,
    email: j['email'] as String?,
    gender: j['gender'] as String?,
    birthdate: j['birthdate'] as String?,
    age: j['age'] as int?,
    height: (j['height'] as num?)?.toDouble(),
    weight: (j['weight'] as num?)?.toDouble(),
    bmi: (j['bmi'] as num?)?.toDouble(),
    familyId: j['familyId'] as int?,
    familyName: j['familyName'] as String?,
    profileImageUrl: j['profileImageUrl'] as String?,
  );
}
