import 'package:cloud_firestore/cloud_firestore.dart';

enum EventStatus { draft, published, archived }

class EventPost {
  // shared
  final String id;
  final String organizerId;
  final String title;
  final String description;
  final String category;
  final String location;

  // ✅ NEW (optional)
  final String? city;

  final String? coverImageUrl;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isPaid;
  final int? price;
  final int capacity;
  final EventStatus status;

  // Admin & analytics
  final bool allowEditPublished;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int bookingsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;

  EventPost({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.startDateTime,
    required this.endDateTime,
    required this.isPaid,
    required this.price,
    required this.capacity,
    required this.status,
    this.city,
    this.coverImageUrl,
    this.allowEditPublished = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.bookingsCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.archived = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory EventPost.fromMap(Map<String, dynamic> data, String id) {
    final statusRaw = data['status'] as String? ?? 'draft';

    final Timestamp? startTs = data['startDateTime'] as Timestamp?;
    final Timestamp? endTs = data['endDateTime'] as Timestamp?;
    final Timestamp? createdTs = data['createdAt'] as Timestamp?;
    final Timestamp? updatedTs = data['updatedAt'] as Timestamp?;

    return EventPost(
      id: id,
      organizerId: data['organizerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      location: data['location'] as String? ?? '',
      city: (data['city'] as String?)?.trim(),
      coverImageUrl: data['coverImageUrl'] as String?,
      startDateTime: startTs?.toDate() ?? DateTime.now(),
      endDateTime: endTs?.toDate() ?? DateTime.now(),
      isPaid: data['isPaid'] as bool? ?? false,
      price: (data['price'] is int || data['price'] is double)
          ? (data['price'] as num).toInt()
          : null,
      capacity: (data['capacity'] as int?) ?? 0,
      status: statusRaw == 'published'
          ? EventStatus.published
          : statusRaw == 'archived'
          ? EventStatus.archived
          : EventStatus.draft,
      allowEditPublished: data['allowEditPublished'] as bool? ?? false,
      likesCount: (data['likesCount'] as int?) ?? 0,
      commentsCount: (data['commentsCount'] as int?) ?? 0,
      viewsCount: (data['viewsCount'] as int?) ?? 0,
      bookingsCount: (data['bookingsCount'] as int?) ?? 0,
      createdAt: createdTs?.toDate(),
      updatedAt: updatedTs?.toDate(),
      archived: data['archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizerId': organizerId,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'city': city,
      'coverImageUrl': coverImageUrl,
      'startDateTime': startDateTime,
      'endDateTime': endDateTime,
      'isPaid': isPaid,
      'price': price,
      'capacity': capacity,
      'status': status.name,
      'allowEditPublished': allowEditPublished,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'viewsCount': viewsCount,
      'bookingsCount': bookingsCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'archived': archived,
    };
  }

  String? get imageUrl => coverImageUrl;

  EventPost copyWith({
    String? id,
    String? organizerId,
    String? title,
    String? description,
    String? category,
    String? location,
    String? city,
    String? coverImageUrl,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? isPaid,
    int? price,
    int? capacity,
    EventStatus? status,
    bool? allowEditPublished,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    int? bookingsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
  }) {
    return EventPost(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      city: city ?? this.city,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      allowEditPublished: allowEditPublished ?? this.allowEditPublished,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
    );
  }
}
