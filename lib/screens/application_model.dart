import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationModel {
  final String id;

  final String jobId;
  final String jobTitle;

  final String organizerId;

  final String workerId;
  final String workerName;
  final String workerEmail;

  // ============================================================
  // WORKER PROFILE DETAILS
  // ============================================================

  final String workerPhone;
  final int workerAge;
  final String workerGender;
  final String workerCity;

  final List<String> workerSkills;

  final String workerExperienceLevel;
  final int workerExperienceYears;
  final String workerPreviousWork;

  final String workerEducation;
  final List<String> workerLanguages;
  final String workerBio;

  // ============================================================
  // APPLICATION DETAILS
  // ============================================================

  final String status;
  final DateTime appliedAt;

  const ApplicationModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.organizerId,
    required this.workerId,
    required this.workerName,
    required this.workerEmail,

    this.workerPhone = '',
    this.workerAge = 0,
    this.workerGender = '',
    this.workerCity = '',

    this.workerSkills = const [],

    this.workerExperienceLevel = '',
    this.workerExperienceYears = 0,
    this.workerPreviousWork = '',

    this.workerEducation = '',
    this.workerLanguages = const [],
    this.workerBio = '',

    required this.status,
    required this.appliedAt,
  });

  // ============================================================
  // APPLICATION MODEL -> FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,

      'jobId': jobId,
      'jobTitle': jobTitle,

      'organizerId': organizerId,

      'workerId': workerId,
      'workerName': workerName,
      'workerEmail': workerEmail,

      // ========================================================
      // WORKER PROFILE DETAILS
      // ========================================================

      'workerPhone': workerPhone,
      'workerAge': workerAge,
      'workerGender': workerGender,
      'workerCity': workerCity,

      'workerSkills': workerSkills,

      'workerExperienceLevel': workerExperienceLevel,
      'workerExperienceYears': workerExperienceYears,
      'workerPreviousWork': workerPreviousWork,

      'workerEducation': workerEducation,
      'workerLanguages': workerLanguages,
      'workerBio': workerBio,

      // ========================================================
      // APPLICATION DETAILS
      // ========================================================

      'status': status,

      'appliedAt': Timestamp.fromDate(
        appliedAt,
      ),
    };
  }

  // ============================================================
  // FIRESTORE -> APPLICATION MODEL
  // ============================================================

  factory ApplicationModel.fromMap(
      Map<String, dynamic> map,
      String documentId,
      ) {
    DateTime appliedDate = DateTime.now();

    final dynamic applied = map['appliedAt'];

    if (applied is Timestamp) {
      appliedDate = applied.toDate();
    } else if (applied is DateTime) {
      appliedDate = applied;
    } else if (applied is String) {
      appliedDate =
          DateTime.tryParse(applied) ??
              DateTime.now();
    }

    // ==========================================================
    // WORKER SKILLS
    // ==========================================================

    List<String> parsedSkills = [];

    final dynamic skills =
    map['workerSkills'];

    if (skills is List) {
      parsedSkills = skills
          .map(
            (item) =>
            item.toString(),
      )
          .where(
            (item) =>
        item.trim().isNotEmpty,
      )
          .toList();
    } else if (skills is String) {
      parsedSkills = skills
          .split(',')
          .map(
            (item) =>
            item.trim(),
      )
          .where(
            (item) =>
        item.isNotEmpty,
      )
          .toList();
    }

    // ==========================================================
    // WORKER LANGUAGES
    // ==========================================================

    List<String> parsedLanguages = [];

    final dynamic languages =
    map['workerLanguages'];

    if (languages is List) {
      parsedLanguages = languages
          .map(
            (item) =>
            item.toString(),
      )
          .where(
            (item) =>
        item.trim().isNotEmpty,
      )
          .toList();
    } else if (languages is String) {
      parsedLanguages = languages
          .split(',')
          .map(
            (item) =>
            item.trim(),
      )
          .where(
            (item) =>
        item.isNotEmpty,
      )
          .toList();
    }

    // ==========================================================
    // CREATE APPLICATION MODEL
    // ==========================================================

    return ApplicationModel(
      id: documentId,

      jobId:
      map['jobId']
          ?.toString() ??
          '',

      jobTitle:
      map['jobTitle']
          ?.toString() ??
          '',

      organizerId:
      map['organizerId']
          ?.toString() ??
          '',

      workerId:
      map['workerId']
          ?.toString() ??
          '',

      workerName:
      map['workerName']
          ?.toString() ??
          '',

      workerEmail:
      map['workerEmail']
          ?.toString() ??
          '',

      // ========================================================
      // WORKER PERSONAL DETAILS
      // ========================================================

      workerPhone:
      map['workerPhone']
          ?.toString() ??
          '',

      workerAge:
      _parseInt(
        map['workerAge'],
      ),

      workerGender:
      map['workerGender']
          ?.toString() ??
          '',

      workerCity:
      map['workerCity']
          ?.toString() ??
          '',

      // ========================================================
      // WORKER SKILLS
      // ========================================================

      workerSkills:
      parsedSkills,

      // ========================================================
      // WORKER EXPERIENCE
      // ========================================================

      workerExperienceLevel:
      map['workerExperienceLevel']
          ?.toString() ??
          '',

      workerExperienceYears:
      _parseInt(
        map['workerExperienceYears'],
      ),

      workerPreviousWork:
      map['workerPreviousWork']
          ?.toString() ??
          '',

      // ========================================================
      // WORKER ADDITIONAL DETAILS
      // ========================================================

      workerEducation:
      map['workerEducation']
          ?.toString() ??
          '',

      workerLanguages:
      parsedLanguages,

      workerBio:
      map['workerBio']
          ?.toString() ??
          '',

      // ========================================================
      // APPLICATION DETAILS
      // ========================================================

      status:
      map['status']
          ?.toString() ??
          'pending',

      appliedAt:
      appliedDate,
    );
  }

  // ============================================================
  // DOCUMENT -> APPLICATION MODEL
  // ============================================================

  factory ApplicationModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data =
        document.data() ?? {};

    return ApplicationModel.fromMap(
      data,
      document.id,
    );
  }

  // ============================================================
  // INT PARSER
  // ============================================================

  static int _parseInt(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }
}