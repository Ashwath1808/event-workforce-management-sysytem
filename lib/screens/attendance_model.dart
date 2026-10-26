import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;

  final String jobId;
  final String jobTitle;

  final String organizerId;

  final String workerId;
  final String workerName;
  final String workerEmail;

  final String status;

  final DateTime? markedAt;

  final String markedBy;

  const AttendanceModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.organizerId,
    required this.workerId,
    required this.workerName,
    required this.workerEmail,
    this.status = 'not_marked',
    this.markedAt,
    this.markedBy = '',
  });

  // ============================================================
  // TO MAP
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
      'status': status,
      'markedAt': markedAt == null
          ? null
          : Timestamp.fromDate(
        markedAt!,
      ),
      'markedBy': markedBy,
    };
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory AttendanceModel.fromMap(
      Map<String, dynamic> map,
      String documentId,
      ) {
    return AttendanceModel(
      id: documentId,

      jobId: map['jobId']
          ?.toString() ??
          '',

      jobTitle: map['jobTitle']
          ?.toString() ??
          '',

      organizerId:
      map['organizerId']
          ?.toString() ??
          '',

      workerId: map['workerId']
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

      status: map['status']
          ?.toString() ??
          'not_marked',

      markedAt:
      _parseDateTime(
        map['markedAt'],
      ),

      markedBy:
      map['markedBy']
          ?.toString() ??
          '',
    );
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  AttendanceModel copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? organizerId,
    String? workerId,
    String? workerName,
    String? workerEmail,
    String? status,
    DateTime? markedAt,
    String? markedBy,
  }) {
    return AttendanceModel(
      id: id ?? this.id,

      jobId:
      jobId ?? this.jobId,

      jobTitle:
      jobTitle ?? this.jobTitle,

      organizerId:
      organizerId ??
          this.organizerId,

      workerId:
      workerId ??
          this.workerId,

      workerName:
      workerName ??
          this.workerName,

      workerEmail:
      workerEmail ??
          this.workerEmail,

      status:
      status ??
          this.status,

      markedAt:
      markedAt ??
          this.markedAt,

      markedBy:
      markedBy ??
          this.markedBy,
    );
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  static DateTime? _parseDateTime(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }
}