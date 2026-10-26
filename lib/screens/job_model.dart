import 'package:cloud_firestore/cloud_firestore.dart';

class JobModel {
  final String id;
  final String title;
  final String category;
  final String location;

  final String date;
  final String startTime;
  final String endTime;

  final int workersNeeded;
  final double paymentPerWorker;

  final String description;
  final List<String> skills;

  final bool accommodationRequired;
  final bool foodProvided;
  final bool transportProvided;

  final String otherRequirements;

  // Kept for compatibility.
  // No Firebase Storage upload is required.
  final String imageUrl;

  final String organizerId;
  final String status;

  // Used for Manage Jobs
  final int applicationsCount;
  final int acceptedWorkers;

  final DateTime createdAt;

  const JobModel({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.workersNeeded,
    required this.paymentPerWorker,
    required this.description,
    required this.skills,
    required this.accommodationRequired,
    required this.foodProvided,
    required this.transportProvided,
    required this.otherRequirements,
    this.imageUrl = '',
    required this.organizerId,
    required this.status,
    this.applicationsCount = 0,
    this.acceptedWorkers = 0,
    required this.createdAt,
  });

  // ============================================================
  // JOB MODEL -> FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'location': location,

      'date': date,
      'startTime': startTime,
      'endTime': endTime,

      'workersNeeded': workersNeeded,
      'paymentPerWorker': paymentPerWorker,

      'description': description,
      'skills': skills,

      'accommodationRequired': accommodationRequired,
      'foodProvided': foodProvided,
      'transportProvided': transportProvided,

      'otherRequirements': otherRequirements,

      // Empty string because image upload was removed.
      'imageUrl': imageUrl,

      'organizerId': organizerId,

      // Current project job status:
      // active / closed / completed / cancelled
      'status': status,

      // Manage Jobs counters
      'applicationsCount': applicationsCount,
      'acceptedWorkers': acceptedWorkers,

      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ============================================================
  // FIRESTORE -> JOB MODEL
  // ============================================================

  factory JobModel.fromMap(
      Map<String, dynamic> map,
      String documentId,
      ) {
    // ----------------------------------------------------------
    // CREATED DATE
    // ----------------------------------------------------------

    DateTime createdDate = DateTime.now();

    final dynamic created = map['createdAt'];

    if (created is Timestamp) {
      createdDate = created.toDate();
    } else if (created is DateTime) {
      createdDate = created;
    } else if (created is String) {
      createdDate =
          DateTime.tryParse(created) ?? DateTime.now();
    }

    // ----------------------------------------------------------
    // SKILLS
    // ----------------------------------------------------------

    List<String> skillsList = [];

    final dynamic skillsData = map['skills'];

    if (skillsData is List) {
      skillsList = skillsData
          .map(
            (skill) => skill.toString(),
      )
          .where(
            (skill) => skill.trim().isNotEmpty,
      )
          .toList();
    }

    // ----------------------------------------------------------
    // CREATE JOB MODEL
    // ----------------------------------------------------------

    return JobModel(
      id: documentId,

      title:
      map['title']?.toString() ?? '',

      category:
      map['category']?.toString() ?? '',

      location:
      map['location']?.toString() ?? '',

      date:
      map['date']?.toString() ?? '',

      startTime:
      map['startTime']?.toString() ?? '',

      endTime:
      map['endTime']?.toString() ?? '',

      workersNeeded:
      _toInt(map['workersNeeded']),

      paymentPerWorker:
      _toDouble(map['paymentPerWorker']),

      description:
      map['description']?.toString() ?? '',

      skills:
      skillsList,

      accommodationRequired:
      map['accommodationRequired'] == true,

      foodProvided:
      map['foodProvided'] == true,

      transportProvided:
      map['transportProvided'] == true,

      otherRequirements:
      map['otherRequirements']?.toString() ?? '',

      imageUrl:
      map['imageUrl']?.toString() ?? '',

      organizerId:
      map['organizerId']?.toString() ?? '',

      // IMPORTANT:
      // CrewSync now uses "active" for newly posted jobs.
      status:
      map['status']?.toString() ?? 'active',

      // IMPORTANT:
      // Read Manage Jobs counters from Firestore.
      // Old jobs without these fields will automatically get 0.
      applicationsCount:
      _toInt(map['applicationsCount']),

      acceptedWorkers:
      _toInt(map['acceptedWorkers']),

      createdAt:
      createdDate,
    );
  }

  // ============================================================
  // DOCUMENT -> JOB MODEL
  // ============================================================

  factory JobModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? {};

    return JobModel.fromMap(
      data,
      document.id,
    );
  }

  // ============================================================
  // SAFE INTEGER CONVERSION
  // ============================================================

  static int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }

  // ============================================================
  // SAFE DOUBLE CONVERSION
  // ============================================================

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0.0;
  }
}