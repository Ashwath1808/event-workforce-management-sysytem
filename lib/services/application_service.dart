import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplicationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // APPLY FOR JOB
  // ============================================================

  Future<void> applyForJob({
    required String jobId,
    required String jobTitle,
    required String date,
    required String location,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    // Check whether worker already applied
    final existingApplication = await _firestore
        .collection('applications')
        .where('workerId', isEqualTo: user.uid)
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();

    if (existingApplication.docs.isNotEmpty) {
      throw Exception(
        'You have already applied for this job.',
      );
    }

    // Get worker information
    final userDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDocument.data();

    await _firestore.collection('applications').add({
      'workerId': user.uid,
      'workerName':
      userData?['name'] ?? user.displayName ?? 'Worker',
      'workerEmail':
      userData?['email'] ?? user.email ?? '',
      'jobId': jobId,
      'jobTitle': jobTitle,
      'date': date,
      'location': location,

      // IMPORTANT
      // Every new application starts as pending.
      'status': 'pending',

      'appliedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // GET WORKER APPLICATIONS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
  getMyApplications() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('applications')
        .where(
      'workerId',
      isEqualTo: user.uid,
    )
        .orderBy(
      'appliedAt',
      descending: true,
    )
        .snapshots();
  }
}