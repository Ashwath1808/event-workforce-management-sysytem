
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'application_model.dart';

class ApplicationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
  get _applications =>
      _firestore.collection('applications');

  CollectionReference<Map<String, dynamic>>
  get _jobs =>
      _firestore.collection('jobs');

  String _applicationId(String jobId, String workerId) {
    return '${jobId}_$workerId';
  }

  String _status(Map<String, dynamic>? data) {
    return (data?['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _error(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Permission denied. Publish the updated '
            'Firestore security rules first.';
      }
      return error.message ?? error.code;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  // ============================================================
  // APPLY FOR JOB
  // ============================================================

  Future<String> applyForJob({
    required ApplicationModel application,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('Please log in before applying.');
      }

      if (application.workerId != currentUser.uid) {
        throw Exception(
          'You cannot apply for another worker.',
        );
      }

      final applicationId = _applicationId(
        application.jobId,
        currentUser.uid,
      );

      final applicationRef = _applications.doc(applicationId);
      final jobRef = _jobs.doc(application.jobId);

      await _firestore.runTransaction((transaction) async {
        final jobSnapshot = await transaction.get(jobRef);
        final existingApplication =
        await transaction.get(applicationRef);

        if (existingApplication.exists) {
          throw Exception(
            'You have already applied for this job.',
          );
        }

        if (!jobSnapshot.exists) {
          throw Exception('This job no longer exists.');
        }

        final jobData = jobSnapshot.data()!;

        if (_status(jobData) != 'active') {
          throw Exception(
            'This job is no longer accepting applications.',
          );
        }

        final totalWorkers =
        _number(jobData['workersNeeded']);
        final acceptedWorkers =
        _number(jobData['acceptedWorkers']);

        if (totalWorkers <= 0 ||
            acceptedWorkers >= totalWorkers) {
          throw Exception(
            'All vacancies for this job are filled.',
          );
        }

        final organizerId =
        (jobData['organizerId'] ?? '').toString();

        if (organizerId.isEmpty) {
          throw Exception(
            'Organizer information is missing.',
          );
        }

        if (organizerId == currentUser.uid) {
          throw Exception(
            'You cannot apply for your own job.',
          );
        }

        final applicationData = application.toMap();

        applicationData['id'] = applicationId;
        applicationData['jobId'] = application.jobId;
        applicationData['workerId'] = currentUser.uid;
        applicationData['organizerId'] = organizerId;
        applicationData['jobTitle'] =
            (jobData['title'] ?? application.jobTitle)
                .toString();
        applicationData['status'] = 'pending';

        transaction.set(applicationRef, applicationData);

        transaction.update(jobRef, {
          'applicationsCount': FieldValue.increment(1),
        });
      });

      return applicationId;
    } catch (e) {
      throw Exception(_error(e));
    }
  }

  // ============================================================
  // ORGANIZER APPLICATIONS
  // ============================================================

  Stream<List<ApplicationModel>> getOrganizerApplications(
      String organizerId,
      ) {
    return _applications
        .where('organizerId', isEqualTo: organizerId)
        .snapshots()
        .map((snapshot) {
      final applications = snapshot.docs
          .map(ApplicationModel.fromDocument)
          .toList();

      applications.sort(
            (a, b) => b.appliedAt.compareTo(a.appliedAt),
      );

      return applications;
    });
  }

  // ============================================================
  // APPLICATIONS FOR A JOB
  // ============================================================

  Stream<List<ApplicationModel>> getJobApplications(
      String jobId,
      ) {
    return _applications
        .where('jobId', isEqualTo: jobId)
        .snapshots()
        .map((snapshot) {
      final applications = snapshot.docs
          .map(ApplicationModel.fromDocument)
          .toList();

      applications.sort(
            (a, b) => b.appliedAt.compareTo(a.appliedAt),
      );

      return applications;
    });
  }

  // ============================================================
  // WORKER APPLICATIONS
  // ============================================================

  Stream<List<ApplicationModel>> getWorkerApplications(
      String workerId,
      ) {
    return _applications
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) {
      final applications = snapshot.docs
          .map(ApplicationModel.fromDocument)
          .toList();

      applications.sort(
            (a, b) => b.appliedAt.compareTo(a.appliedAt),
      );

      return applications;
    });
  }

  // ============================================================
  // CHECK EXISTING APPLICATION
  // ============================================================

  Future<bool> hasWorkerApplied({
    required String jobId,
    required String workerId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null ||
          currentUser.uid != workerId) {
        throw Exception(
          'Please log in as the correct worker.',
        );
      }

      final snapshot = await _applications
          .doc(_applicationId(jobId, workerId))
          .get();

      return snapshot.exists;
    } catch (e) {
      throw Exception(_error(e));
    }
  }

  // ============================================================
  // CHANGE APPLICATION STATUS
  //
  // This handles all six status transitions:
  //
  // pending  -> accepted
  // pending  -> rejected
  // accepted -> pending
  // accepted -> rejected
  // rejected -> pending
  // rejected -> accepted
  //
  // acceptedWorkers changes only when entering or
  // leaving the accepted status.
  // ============================================================

  Future<void> _changeApplicationStatus({
    required ApplicationModel application,
    required String newStatus,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('Please log in again.');
      }

      if (!['pending', 'accepted', 'rejected']
          .contains(newStatus)) {
        throw Exception('Invalid application status.');
      }

      final applicationRef =
      _applications.doc(application.id);

      final jobRef = _jobs.doc(application.jobId);

      await _firestore.runTransaction((transaction) async {
        // All transaction reads happen before writes.
        final applicationSnapshot =
        await transaction.get(applicationRef);

        final jobSnapshot =
        await transaction.get(jobRef);

        if (!applicationSnapshot.exists) {
          throw Exception(
            'This application no longer exists.',
          );
        }

        if (!jobSnapshot.exists) {
          throw Exception(
            'The associated job no longer exists.',
          );
        }

        final applicationData =
        applicationSnapshot.data()!;

        final jobData = jobSnapshot.data()!;

        if (applicationData['organizerId'] !=
            currentUser.uid ||
            jobData['organizerId'] != currentUser.uid) {
          throw Exception(
            'Only the organizer can change this application.',
          );
        }

        if (applicationData['jobId'] != application.jobId) {
          throw Exception(
            'Application and job do not match.',
          );
        }

        final currentStatus = _status(applicationData);

        if (!['pending', 'accepted', 'rejected']
            .contains(currentStatus)) {
          throw Exception(
            'This application has an invalid status.',
          );
        }

        // No changes needed.
        if (currentStatus == newStatus) {
          return;
        }

        final totalWorkers =
        _number(jobData['workersNeeded']);

        final acceptedWorkers =
        _number(jobData['acceptedWorkers']);

        // +1 when a worker becomes accepted.
        // -1 when an accepted worker is removed.
        //  0 for pending <-> rejected.
        int change = 0;

        if (currentStatus != 'accepted' &&
            newStatus == 'accepted') {
          change = 1;
        } else if (currentStatus == 'accepted' &&
            newStatus != 'accepted') {
          change = -1;
        }

        final newAcceptedWorkers =
            acceptedWorkers + change;

        if (change > 0) {
          if (_status(jobData) != 'active') {
            throw Exception(
              'This job is no longer active.',
            );
          }

          if (totalWorkers <= 0 ||
              acceptedWorkers >= totalWorkers) {
            throw Exception(
              'All vacancies for this job are filled.',
            );
          }
        }

        if (newAcceptedWorkers < 0) {
          throw Exception(
            'Accepted worker count is already zero. '
                'Please check the job data.',
          );
        }

        if (newAcceptedWorkers > totalWorkers) {
          throw Exception(
            'Accepted workers cannot exceed '
                'the required workers.',
          );
        }

        // Update application status.
        transaction.update(applicationRef, {
          'status': newStatus,
        });

        // Update job count in the SAME transaction.
        if (change != 0) {
          transaction.update(jobRef, {
            'acceptedWorkers': newAcceptedWorkers,
          });
        }
      });
    } catch (e) {
      throw Exception(_error(e));
    }
  }

  // ============================================================
  // ACCEPT APPLICATION
  // ============================================================

  Future<void> acceptApplication({
    required ApplicationModel application,
  }) async {
    await _changeApplicationStatus(
      application: application,
      newStatus: 'accepted',
    );
  }

  // ============================================================
  // REJECT APPLICATION
  // ============================================================

  Future<void> rejectApplication({
    required ApplicationModel application,
  }) async {
    await _changeApplicationStatus(
      application: application,
      newStatus: 'rejected',
    );
  }

  // ============================================================
  // MOVE APPLICATION TO PENDING
  // ============================================================

  Future<void> markPending({
    required ApplicationModel application,
  }) async {
    await _changeApplicationStatus(
      application: application,
      newStatus: 'pending',
    );
  }

  // ============================================================
  // DELETE APPLICATION
  // ============================================================

  Future<void> deleteApplication({
    required ApplicationModel application,
  }) async {
    throw UnsupportedError(
      'Deleting applications is not allowed '
          'by the current Firestore rules.',
    );
  }
}
