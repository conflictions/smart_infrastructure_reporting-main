class InfrastructureReport {
  final String id;
  final String referenceNumber;
  final String citizenId;

  final String title;
  final String category;
  final String priority;
  final String description;

  final String address;
  final String? landmark;

  final double? latitude;
  final double? longitude;

  final String status;

  final String? assignedDepartment;

  final String? assignedWorkerId;
  final DateTime? assignedAt;

  final int progressPercentage;

  final DateTime? estimatedCompletion;

  // 维修后照片链接列表
  final List<String> afterImages;

  final DateTime createdAt;
  final DateTime updatedAt;

  InfrastructureReport({
    required this.id,
    required this.referenceNumber,
    required this.citizenId,
    required this.title,
    required this.category,
    required this.priority,
    required this.description,
    required this.address,
    this.landmark,
    this.latitude,
    this.longitude,
    required this.status,
    this.assignedDepartment,
    this.assignedWorkerId,
    this.assignedAt,
    required this.progressPercentage,
    this.estimatedCompletion,
    this.afterImages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory InfrastructureReport.fromMap(Map<String, dynamic> map) {
    List<String> parsedAfterImages = [];
    if (map['after_images'] != null) {
      if (map['after_images'] is List) {
        parsedAfterImages = (map['after_images'] as List)
            .map((item) => item.toString())
            .toList();
      }
    }

    return InfrastructureReport(
      id: map['id']?.toString() ?? '',
      referenceNumber: map['reference_number']?.toString() ?? '',
      citizenId: map['citizen_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      priority: map['priority']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      landmark: map['landmark']?.toString(),
      latitude: map['latitude'] == null
          ? null
          : (map['latitude'] as num).toDouble(),
      longitude: map['longitude'] == null
          ? null
          : (map['longitude'] as num).toDouble(),
      status: map['status']?.toString() ?? 'pending',
      assignedDepartment: map['assigned_department']?.toString(),
      assignedWorkerId: map['assigned_worker_id']?.toString(),
      assignedAt: map['assigned_at'] != null
          ? DateTime.tryParse(map['assigned_at'].toString())
          : null,
      progressPercentage: map['progress_percentage'] as int? ?? 0,
      estimatedCompletion: map['estimated_completion'] != null
          ? DateTime.tryParse(map['estimated_completion'].toString())
          : null,
      afterImages: parsedAfterImages,
      createdAt: DateTime.tryParse(map['created_at'].toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'].toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference_number': referenceNumber,
      'citizen_id': citizenId,
      'title': title,
      'category': category,
      'priority': priority,
      'description': description,
      'address': address,
      'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'assigned_department': assignedDepartment,
      'assigned_worker_id': assignedWorkerId,
      'assigned_at': assignedAt?.toIso8601String(),
      'progress_percentage': progressPercentage,
      'estimated_completion': estimatedCompletion?.toIso8601String(),
      'after_images': afterImages,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}