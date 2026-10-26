import 'package:cloud_firestore/cloud_firestore.dart';

import 'attendance_model.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _attendanceCollection =>
      _firestore.collection('attendance');

  // ============================================================
  // CREATE ATTENDANCE RECORD IF MISSING
  // ============================================================

  Future<void> createAttendanceIfMissing({
    required String jobId,
    required String jobTitle,
    required String organizerId,
    required String workerId,
    required String workerName,
    required String workerEmail,
  }) async {
    try {
      final documentId = '${jobId}_$workerId';

      final documentReference =
      _attendanceCollection.doc(documentId);

      /*
       * IMPORTANT:
       *
       * Do NOT call documentReference.get() here.
       *
       * With the Firestore security rules, reading a document that
       * does not exist yet can result in permission-denied.
       *
       * We already use a deterministic document ID:
       *
       * jobId_workerId
       *
       * Therefore there can only be one attendance document for
       * this worker + event.
       *
       * The organizer page calls this only when attendance is first
       * marked.
       */

      final attendance = AttendanceModel(
        id: documentId,
        jobId: jobId,
        jobTitle: jobTitle,
        organizerId: organizerId,
        workerId: workerId,
        workerName: workerName,
        workerEmail: workerEmail,
        status: 'not_marked',
        markedAt: null,
        markedBy: '',
      );

      await documentReference.set(
        attendance.toMap(),
      );
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to create attendance record.',
      );
    } catch (e) {
      throw Exception(
        'Unable to create attendance record: $e',
      );
    }
  }

  // ============================================================
  // MARK PRESENT
  // ============================================================

  Future<void> markPresent({
    required String jobId,
    required String workerId,
    required String organizerId,
  }) async {
    await _updateAttendanceStatus(
      jobId: jobId,
      workerId: workerId,
      organizerId: organizerId,
      status: 'present',
    );
  }

  // ============================================================
  // MARK ABSENT
  // ============================================================

  Future<void> markAbsent({
    required String jobId,
    required String workerId,
    required String organizerId,
  }) async {
    await _updateAttendanceStatus(
      jobId: jobId,
      workerId: workerId,
      organizerId: organizerId,
      status: 'absent',
    );
  }

  // ============================================================
  // RESET ATTENDANCE
  // ============================================================

  Future<void> resetAttendance({
    required String jobId,
    required String workerId,
    required String organizerId,
  }) async {
    try {
      final documentId = '${jobId}_$workerId';

      final documentReference =
      _attendanceCollection.doc(documentId);

      /*
       * We do not need to read the document first.
       *
       * Firestore security rules already verify that the currently
       * logged-in organizer owns this attendance record.
       */

      await documentReference.update({
        'status': 'not_marked',
        'markedAt': null,
        'markedBy': '',
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to reset attendance.',
      );
    } catch (e) {
      throw Exception(
        'Unable to reset attendance: $e',
      );
    }
  }

  // ============================================================
  // UPDATE ATTENDANCE STATUS
  // ============================================================

  Future<void> _updateAttendanceStatus({
    required String jobId,
    required String workerId,
    required String organizerId,
    required String status,
  }) async {
    if (status != 'present' && status != 'absent') {
      throw Exception(
        'Invalid attendance status.',
      );
    }

    try {
      final documentId = '${jobId}_$workerId';

      final documentReference =
      _attendanceCollection.doc(documentId);

      /*
       * No transaction read is necessary here.
       *
       * The document was created by createAttendanceIfMissing().
       *
       * Firestore rules verify:
       *
       * organizerId
       * workerId
       * jobId
       * allowed changed fields
       * allowed attendance status
       * markedBy
       */

      await documentReference.update({
        'status': status,
        'markedAt': FieldValue.serverTimestamp(),
        'markedBy': organizerId,
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to update attendance.',
      );
    } catch (e) {
      throw Exception(
        'Unable to update attendance: $e',
      );
    }
  }

  // ============================================================
  // GET ONE ATTENDANCE RECORD
  // ============================================================

  Future<AttendanceModel?> getAttendance({
    required String jobId,
    required String workerId,
  }) async {
    try {
      final documentId = '${jobId}_$workerId';

      final documentSnapshot =
      await _attendanceCollection.doc(documentId).get();

      if (!documentSnapshot.exists) {
        return null;
      }

      final data = documentSnapshot.data();

      if (data == null) {
        return null;
      }

      return AttendanceModel.fromMap(
        data,
        documentSnapshot.id,
      );
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to load attendance.',
      );
    } catch (e) {
      throw Exception(
        'Unable to load attendance: $e',
      );
    }
  }

  // ============================================================
  // WORKER ATTENDANCE STREAM
  // ============================================================

  Stream<List<AttendanceModel>> getWorkerAttendance(
      String workerId,
      ) {
    return _attendanceCollection
        .where(
      'workerId',
      isEqualTo: workerId,
    )
        .snapshots()
        .map(
          (snapshot) {
        final attendance = snapshot.docs
            .map(
              (document) => AttendanceModel.fromMap(
            document.data(),
            document.id,
          ),
        )
            .toList();

        attendance.sort(
              (a, b) {
            final aDate = a.markedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final bDate = b.markedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return bDate.compareTo(aDate);
          },
        );

        return attendance;
      },
    );
  }

  // ============================================================
  // ORGANIZER ATTENDANCE STREAM
  // ============================================================

  Stream<List<AttendanceModel>> getOrganizerAttendance(
      String organizerId,
      ) {
    return _attendanceCollection
        .where(
      'organizerId',
      isEqualTo: organizerId,
    )
        .snapshots()
        .map(
          (snapshot) {
        final attendance = snapshot.docs
            .map(
              (document) => AttendanceModel.fromMap(
            document.data(),
            document.id,
          ),
        )
            .toList();

        attendance.sort(
              (a, b) => a.workerName
              .toLowerCase()
              .compareTo(
            b.workerName.toLowerCase(),
          ),
        );

        return attendance;
      },
    );
  }

  // ============================================================
  // JOB ATTENDANCE STREAM
  // ============================================================

  Stream<List<AttendanceModel>> getJobAttendance(
      String jobId,
      ) {
    return _attendanceCollection
        .where(
      'jobId',
      isEqualTo: jobId,
    )
        .snapshots()
        .map(
          (snapshot) {
        final attendance = snapshot.docs
            .map(
              (document) => AttendanceModel.fromMap(
            document.data(),
            document.id,
          ),
        )
            .toList();

        attendance.sort(
              (a, b) => a.workerName
              .toLowerCase()
              .compareTo(
            b.workerName.toLowerCase(),
          ),
        );

        return attendance;
      },
    );
  }

  // ============================================================
  // ORGANIZER + JOB ATTENDANCE STREAM
  // ============================================================

  Stream<List<AttendanceModel>> getOrganizerJobAttendance({
    required String organizerId,
    required String jobId,
  }) {
    return _attendanceCollection
        .where(
      'organizerId',
      isEqualTo: organizerId,
    )
        .where(
      'jobId',
      isEqualTo: jobId,
    )
        .snapshots()
        .map(
          (snapshot) {
        final attendance = snapshot.docs
            .map(
              (document) => AttendanceModel.fromMap(
            document.data(),
            document.id,
          ),
        )
            .toList();

        attendance.sort(
              (a, b) => a.workerName
              .toLowerCase()
              .compareTo(
            b.workerName.toLowerCase(),
          ),
        );

        return attendance;
      },
    );
  }

  // ============================================================
  // ATTENDANCE COUNTS
  // ============================================================

  Future<Map<String, int>> getAttendanceCounts(
      String jobId,
      ) async {
    try {
      final snapshot = await _attendanceCollection
          .where(
        'jobId',
        isEqualTo: jobId,
      )
          .get();

      int total = 0;
      int present = 0;
      int absent = 0;
      int notMarked = 0;

      for (final document in snapshot.docs) {
        total++;

        final status = document
            .data()['status']
            ?.toString()
            .trim()
            .toLowerCase() ??
            'not_marked';

        if (status == 'present') {
          present++;
        } else if (status == 'absent') {
          absent++;
        } else {
          notMarked++;
        }
      }

      return {
        'total': total,
        'present': present,
        'absent': absent,
        'notMarked': notMarked,
      };
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to load attendance counts.',
      );
    } catch (e) {
      throw Exception(
        'Unable to load attendance counts: $e',
      );
    }
  }

  // ============================================================
  // DELETE ATTENDANCE
  // ============================================================

  Future<void> deleteAttendance({
    required String jobId,
    required String workerId,
    required String organizerId,
  }) async {
    try {
      final documentId = '${jobId}_$workerId';

      final documentReference =
      _attendanceCollection.doc(documentId);

      /*
       * No preliminary read is required.
       * Firestore rules already verify organizer ownership.
       */

      await documentReference.delete();
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to delete attendance.',
      );
    } catch (e) {
      throw Exception(
        'Unable to delete attendance: $e',
      );
    }
  }
}