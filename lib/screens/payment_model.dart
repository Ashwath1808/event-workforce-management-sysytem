import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentEntry {
  final double amount;
  final String method;
  final String reference;
  final DateTime? paidAt;

  const PaymentEntry({
    required this.amount,
    required this.method,
    required this.reference,
    this.paidAt,
  });

  factory PaymentEntry.fromMap(Map<String, dynamic> map) => PaymentEntry(
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        method: map['method'] as String? ?? '',
        reference: map['reference'] as String? ?? '',
        paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      );
}

class PaymentModel {
  final String id, jobId, jobTitle, organizerId, workerId, workerName;
  final double amountDue, amountPaid;
  final List<PaymentEntry> history;

  const PaymentModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.organizerId,
    required this.workerId,
    required this.workerName,
    required this.amountDue,
    required this.amountPaid,
    required this.history,
  });

  double get remaining =>
      (amountDue - amountPaid).clamp(0, double.infinity).toDouble();

  String get status => amountPaid <= 0
      ? 'Pending'
      : remaining <= 0.001
          ? 'Paid'
          : 'Partially Paid';

  factory PaymentModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return PaymentModel(
      id: doc.id,
      jobId: map['jobId'] as String? ?? '',
      jobTitle: map['jobTitle'] as String? ?? '',
      organizerId: map['organizerId'] as String? ?? '',
      workerId: map['workerId'] as String? ?? '',
      workerName: map['workerName'] as String? ?? '',
      amountDue: (map['amountDue'] as num?)?.toDouble() ?? 0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      history: ((map['history'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => PaymentEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
