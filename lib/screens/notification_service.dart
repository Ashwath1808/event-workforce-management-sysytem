
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // WORKER NOTIFICATIONS
  // ============================================================

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getWorkerNotifications() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .where((doc) =>
      doc.data()['organizerId'] != user.uid)
          .toList();

      notifications.sort((a, b) {
        final aTime = a.data()['createdAt'];
        final bTime = b.data()['createdAt'];

        if (aTime is Timestamp &&
            bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }

        return 0;
      });

      return notifications;
    });
  }

  // ============================================================
  // WORKER UNREAD NOTIFICATION COUNT
  // ============================================================

  Stream<int> getWorkerUnreadCount() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notificationStates')
        .doc(user.uid)
        .collection('items')
        .snapshots()
        .asyncMap((readSnapshot) async {
      final readIds = readSnapshot.docs
          .where((doc) =>
      doc.data()['isRead'] == true)
          .map((doc) => doc.id)
          .toSet();

      final jobsSnapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'active')
          .get();

      return jobsSnapshot.docs.where((doc) {
        final isOwnJob =
            doc.data()['organizerId'] == user.uid;

        final isRead =
        readIds.contains('job_${doc.id}');

        return !isOwnJob && !isRead;
      }).length;
    });
  }

  // ============================================================
  // MARK JOB NOTIFICATION AS READ
  // ============================================================

  Future<void> markAsRead(
      String jobId,
      ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in.');
    }

    await _firestore
        .collection('notificationStates')
        .doc(user.uid)
        .collection('items')
        .doc('job_$jobId')
        .set({
      'isRead': true,
    });
  }
}
