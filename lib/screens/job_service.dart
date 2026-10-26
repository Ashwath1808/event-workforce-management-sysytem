
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'job_model.dart';

class JobService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // COLLECTIONS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _firestore.collection('jobs');

  // ============================================================
  // PUBLISH JOB
  // ============================================================

  Future<String> publishJob({
    required JobModel job,
  }) async {
    try {
      final firebaseUser =
          FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        throw Exception('Organizer is not logged in.');
      }

      if (job.organizerId != firebaseUser.uid) {
        throw Exception('Invalid organizer account.');
      }

      final document = _jobs.doc();

      final data = job.toMap();

      data['id'] = document.id;
      data['organizerId'] = firebaseUser.uid;
      data['status'] = 'active';
      data['applicationsCount'] = 0;
      data['acceptedWorkers'] = 0;

      if (data['paymentPerWorker'] is! num ||
          data['paymentPerWorker'] <= 0) {
        throw Exception(
          'Payment per worker must be greater than zero.',
        );
      }

      // Save only the job.
      // Worker notifications must be created securely
      // by a backend service such as Cloud Functions.
      await document.set(data);

      debugPrint(
        'Job published successfully: ${document.id}',
      );

      return document.id;
    } on FirebaseException catch (e) {
      debugPrint(
        'Firebase publish error: ${e.code} - ${e.message}',
      );

      throw Exception(
        e.message ?? 'Unable to publish job.',
      );
    } catch (e) {
      debugPrint('Publish job error: $e');
      rethrow;
    }
  }

  // ============================================================
  // GET ALL ACTIVE JOBS FOR WORKERS
  // ============================================================

  Stream<List<JobModel>> getPublishedJobs() {
    return _jobs
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final jobs = snapshot.docs
          .map((document) =>
          JobModel.fromDocument(document))
          .toList();

      jobs.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return jobs;
    });
  }

  // ============================================================
  // GET ACTIVE JOBS
  // ============================================================

  Stream<List<JobModel>> getActiveJobs() {
    return _jobs
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final jobs = snapshot.docs
          .map((document) =>
          JobModel.fromDocument(document))
          .toList();

      jobs.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return jobs;
    });
  }

  // ============================================================
  // GET ORGANIZER JOBS
  // ============================================================

  Stream<List<JobModel>> getOrganizerJobs(
      String organizerId,
      ) {
    return _jobs
        .where(
      'organizerId',
      isEqualTo: organizerId,
    )
        .snapshots()
        .map((snapshot) {
      final jobs = snapshot.docs
          .map((document) =>
          JobModel.fromDocument(document))
          .toList();

      jobs.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return jobs;
    });
  }

  // ============================================================
  // GET SINGLE JOB
  // ============================================================

  Future<JobModel?> getJob(
      String jobId,
      ) async {
    try {
      final document =
      await _jobs.doc(jobId).get();

      if (!document.exists) {
        return null;
      }

      return JobModel.fromDocument(document);
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ?? 'Unable to load job.',
      );
    } catch (e) {
      throw Exception(
        'Unable to load job: $e',
      );
    }
  }

  // ============================================================
  // UPDATE JOB
  // ============================================================

  Future<void> updateJob({
    required String jobId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _jobs.doc(jobId).update(data);
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ?? 'Unable to update job.',
      );
    } catch (e) {
      throw Exception(
        'Unable to update job: $e',
      );
    }
  }

  // ============================================================
  // UPDATE JOB STATUS
  // ============================================================

  Future<void> updateJobStatus({
    required String jobId,
    required String status,
  }) async {
    try {
      await _jobs.doc(jobId).update({
        'status': status,
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to update job status.',
      );
    } catch (e) {
      throw Exception(
        'Unable to update job status: $e',
      );
    }
  }

  // ============================================================
  // CLOSE JOB
  // ============================================================

  Future<void> closeJob(
      String jobId,
      ) async {
    try {
      await _jobs.doc(jobId).update({
        'status': 'closed',
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ?? 'Unable to close job.',
      );
    } catch (e) {
      throw Exception(
        'Unable to close job: $e',
      );
    }
  }

  // ============================================================
  // COMPLETE JOB
  // ============================================================

  Future<void> completeJob(
      String jobId,
      ) async {
    try {
      await _jobs.doc(jobId).update({
        'status': 'completed',
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ?? 'Unable to complete job.',
      );
    } catch (e) {
      throw Exception(
        'Unable to complete job: $e',
      );
    }
  }

  // ============================================================
  // CANCEL JOB
  // ============================================================

  Future<void> cancelJob(
      String jobId,
      ) async {
    try {
      await _jobs.doc(jobId).update({
        'status': 'cancelled',
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ?? 'Unable to cancel job.',
      );
    } catch (e) {
      throw Exception(
        'Unable to cancel job: $e',
      );
    }
  }

  // ============================================================
  // DELETE JOB
  // ============================================================

  Future<void> deleteJob(
      String jobId,
      ) async {
    try {
      await _jobs.doc(jobId).delete();
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ?? 'Unable to delete job.',
      );
    } catch (e) {
      throw Exception(
        'Unable to delete job: $e',
      );
    }
  }

  // ============================================================
  // INCREASE APPLICATION COUNT
  // ============================================================

  Future<void> increaseApplicationCount(
      String jobId,
      ) async {
    try {
      await _jobs.doc(jobId).update({
        'applicationsCount':
        FieldValue.increment(1),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to update application count.',
      );
    } catch (e) {
      throw Exception(
        'Unable to update application count: $e',
      );
    }
  }

  // ============================================================
  // INCREASE ACCEPTED WORKERS
  // ============================================================

  Future<void> increaseAcceptedWorkers(
      String jobId,
      ) async {
    try {
      await _jobs.doc(jobId).update({
        'acceptedWorkers':
        FieldValue.increment(1),
      });
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ??
            'Unable to update accepted workers.',
      );
    } catch (e) {
      throw Exception(
        'Unable to update accepted workers: $e',
      );
    }
  }
}
