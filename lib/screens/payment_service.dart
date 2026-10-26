import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'application_model.dart';
import 'job_model.dart';
import 'payment_model.dart';

class PaymentService {
  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  // =====================================================
  // ORGANIZER PAYMENTS
  // =====================================================

  Stream<List<PaymentModel>> organizerPayments(
      String organizerId,
      ) {
    return _db
        .collection('payments')
        .where('organizerId', isEqualTo: organizerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(PaymentModel.fromDocument)
          .toList(),
    );
  }

  // =====================================================
  // WORKER PAYMENTS
  // =====================================================

  Stream<List<PaymentModel>> workerPayments(
      String workerId,
      ) {
    return _db
        .collection('payments')
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(PaymentModel.fromDocument)
          .toList(),
    );
  }

  // =====================================================
  // RECORD PAYMENT
  // =====================================================

  Future<void> recordPayment({
    required JobModel job,
    required ApplicationModel worker,
    required String organizerId,
    required double amount,
    required String method,
    required String reference,
  }) async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Please log in again.');
    }

    if (currentUser.uid != organizerId ||
        organizerId != job.organizerId) {
      throw Exception(
        'Only the event organizer can record payment.',
      );
    }

    if (worker.organizerId != organizerId ||
        worker.jobId != job.id ||
        worker.status.toLowerCase() != 'accepted') {
      throw Exception(
        'Only accepted workers of this event '
            'can receive payment.',
      );
    }

    if (job.id.isEmpty || worker.workerId.isEmpty) {
      throw Exception('Invalid event or worker ID.');
    }

    if (!amount.isFinite || amount <= 0) {
      throw Exception(
        'Enter a valid payment amount.',
      );
    }

    if (![
      'UPI',
      'Cash',
      'Bank Transfer',
    ].contains(method)) {
      throw Exception(
        'Select a valid payment method.',
      );
    }

    final recordId =
        '${job.id}_${worker.workerId}';

    final jobRef =
    _db.collection('jobs').doc(job.id);

    final attendanceRef =
    _db.collection('attendance').doc(recordId);

    final paymentRef =
    _db.collection('payments').doc(recordId);

    debugPrint('====================================');
    debugPrint('PAYMENT DEBUG START');
    debugPrint('EVENT ID: ${job.id}');
    debugPrint('WORKER ID: ${worker.workerId}');
    debugPrint('ORGANIZER ID: $organizerId');
    debugPrint('PAYMENT DOCUMENT ID: $recordId');
    debugPrint('AMOUNT: $amount');
    debugPrint('METHOD: $method');
    debugPrint('====================================');

    try {
      await _db.runTransaction((transaction) async {
        // Firestore requires all reads before writes.

        final jobSnapshot =
        await transaction.get(jobRef);

        final attendanceSnapshot =
        await transaction.get(attendanceRef);

        final paymentSnapshot =
        await transaction.get(paymentRef);

        // -----------------------------------------------
        // VALIDATE EVENT
        // -----------------------------------------------

        final jobData = jobSnapshot.data();

        if (jobData == null) {
          throw Exception('Event does not exist.');
        }

        if (jobData['organizerId'] != organizerId) {
          throw Exception(
            'You are not the organizer of this event.',
          );
        }

        if (jobData['status'] == 'cancelled') {
          throw Exception(
            'Cannot record payment for a cancelled event.',
          );
        }

        // -----------------------------------------------
        // VALIDATE ATTENDANCE
        // -----------------------------------------------

        final attendanceData =
        attendanceSnapshot.data();

        if (attendanceData == null) {
          throw Exception(
            'Attendance record not found for this event.',
          );
        }

        if (attendanceData['jobId'] != job.id ||
            attendanceData['workerId'] != worker.workerId ||
            attendanceData['organizerId'] != organizerId ||
            attendanceData['status'] != 'present') {
          throw Exception(
            'Mark this worker Present for this event '
                'before recording payment.',
          );
        }

        // -----------------------------------------------
        // VALIDATE AMOUNT
        // -----------------------------------------------

        final amountDue =
            (jobData['paymentPerWorker'] as num?)
                ?.toDouble() ??
                0.0;

        if (amountDue <= 0) {
          throw Exception(
            'Invalid payment amount configured '
                'for this event.',
          );
        }

        final previousData =
        paymentSnapshot.data();

        final alreadyPaid =
            (previousData?['amountPaid'] as num?)
                ?.toDouble() ??
                0.0;

        final remaining =
            amountDue - alreadyPaid;

        if (remaining <= 0.001) {
          throw Exception(
            'This worker has already been paid '
                'in full for this event.',
          );
        }

        if (amount > remaining + 0.001) {
          throw Exception(
            'Payment exceeds the remaining balance.',
          );
        }

        // -----------------------------------------------
        // PRESERVE PAYMENT HISTORY
        // -----------------------------------------------

        final List<Map<String, dynamic>> history = [];

        if (previousData != null) {
          final existingHistory =
              previousData['history']
              as List<dynamic>? ??
                  [];

          for (final item in existingHistory) {
            history.add(
              Map<String, dynamic>.from(
                item as Map,
              ),
            );
          }
        }

        // Each history entry represents a distinct
        // payment. Its index can also identify one
        // unique worker notification.
        final paymentSequence = history.length + 1;

        history.add({
          'amount': amount,
          'method': method,
          'reference': reference.trim(),
          'paidAt': Timestamp.now(),
          'paymentSequence': paymentSequence,
        });

        final totalPaid = alreadyPaid + amount;

        final status =
        totalPaid >= amountDue - 0.001
            ? 'Paid'
            : 'Partially Paid';

        // -----------------------------------------------
        // WRITE PAYMENT
        // -----------------------------------------------

        transaction.set(paymentRef, {
          'jobId': job.id,
          'jobTitle': job.title,
          'organizerId': organizerId,
          'workerId': worker.workerId,
          'workerName': worker.workerName,
          'amountDue': amountDue,
          'amountPaid': totalPaid,
          'status': status,
          'history': history,
          'updatedAt':
          FieldValue.serverTimestamp(),
        });
      });

      debugPrint(
        'PAYMENT SUCCESS: $recordId',
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('PAYMENT FIREBASE ERROR');
      debugPrint('CODE: ${e.code}');
      debugPrint('MESSAGE: ${e.message}');
      debugPrint('STACK TRACE: $stackTrace');

      if (e.code == 'permission-denied') {
        throw Exception(
          'Payment permission denied. '
              'Check Firestore rules and event attendance.',
        );
      }

      throw Exception(
        'Payment failed (${e.code}): '
            '${e.message ?? "Unknown Firebase error"}',
      );
    } catch (e, stackTrace) {
      debugPrint('PAYMENT ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }
}