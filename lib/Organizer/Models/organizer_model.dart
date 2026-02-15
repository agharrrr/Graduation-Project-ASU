// lib/Organizer/Models/organizer_model.dart
class OrganizerModel {
  final String id;
  final String? name;
  final String? coverImageUrl;
  final String? profileImageUrl;
  final int followersCount;

  OrganizerModel({
    required this.id,
    this.name,
    this.coverImageUrl,
    this.profileImageUrl,
    required this.followersCount,
  });

  factory OrganizerModel.fromMap(Map<String, dynamic> map, String id) {
    return OrganizerModel(
      id: id,
      name: map['name'] as String?,
      coverImageUrl: map['coverImageUrl'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'coverImageUrl': coverImageUrl,
      'profileImageUrl': profileImageUrl,
      'followersCount': followersCount,
    };
  }

  OrganizerModel copyWith({
    String? id,
    String? name,
    String? coverImageUrl,
    String? profileImageUrl,
    int? followersCount,
  }) {
    return OrganizerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followersCount: followersCount ?? this.followersCount,
    );
  }
}
