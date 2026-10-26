import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';
import 'job_model.dart';
import 'payment_model.dart';
import 'payment_service.dart';

class EventPaymentDetailsPage extends StatefulWidget {
  final JobModel job;

  const EventPaymentDetailsPage({
    super.key,
    required this.job,
  });

  @override
  State<EventPaymentDetailsPage> createState() =>
      _EventPaymentDetailsPageState();
}

class _EventPaymentDetailsPageState
    extends State<EventPaymentDetailsPage> {
  // ============================================================
  // CREWSYNC COLORS
  // ============================================================

  static const Color navy = Color(0xFF0B1220);
  static const Color panel = Color(0xFF19263B);
  static const Color panelLight = Color(0xFF203149);
  static const Color coral = Color(0xFFF06449);
  static const Color teal = Color(0xFF35D1AC);
  static const Color muted = Color(0xFFA7B7CD);
  static const Color white = Color(0xFFF7F9FC);
  static const Color border = Color(0xFF2B3D54);
  static const Color amber = Color(0xFFFFC178);
  static const Color red = Color(0xFFFF8490);

  // ============================================================
  // EXISTING SERVICES
  // ============================================================

  final PaymentService service = PaymentService();

  final ApplicationService applicationService =
  ApplicationService();

  final AttendanceService attendanceService =
  AttendanceService();

  final TextEditingController searchController =
  TextEditingController();

  String filter = 'All';
  String sort = 'Name';
  String search = '';

  bool saving = false;

  static const List<String> filters = [
    'All',
    'Present',
    'Not Eligible',
    'Unpaid',
    'Partially Paid',
    'Paid',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // BASIC HELPERS
  // ============================================================

  String _money(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? 'Not provided' : text;
  }

  double _remaining(double due, double paid) {
    return (due - paid)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  double _progress(double due, double paid) {
    if (due <= 0) return 0;

    return (paid / due).clamp(0.0, 1.0).toDouble();
  }

  bool _isPresent(String status) {
    return status.trim().toLowerCase() == 'present';
  }

  bool _isCancelled() {
    return widget.job.status.trim().toLowerCase() ==
        'cancelled';
  }

  String _paymentStatus(
      bool present,
      double paid,
      double due,
      ) {
    if (!present) return 'Not Eligible';

    if (due <= 0) return 'No Amount Due';

    if (paid >= due - 0.001) {
      return 'Paid';
    }

    if (paid > 0) {
      return 'Partially Paid';
    }

    return 'Unpaid';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return teal;

      case 'Partially Paid':
        return amber;

      case 'Unpaid':
        return red;

      case 'Present':
        return teal;

      case 'Not Eligible':
        return muted;

      default:
        return muted;
    }
  }

  void _showMessage(
      String message, {
        Color color = teal,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(
      ClipboardData(text: value),
    );

    _showMessage('Copied to clipboard.');
  }

  // ============================================================
  // UPI QR CODE
  // ============================================================

  String _upiUri({
    required String upiId,
    required String accountHolder,
    double? amount,
  }) {
    if (upiId.trim().isEmpty ||
        accountHolder.trim().isEmpty) {
      return '';
    }

    final parameters = <String, String>{
      'pa': upiId.trim(),
      'pn': accountHolder.trim(),
      'cu': 'INR',
    };

    if (amount != null && amount > 0) {
      parameters['am'] = amount.toStringAsFixed(2);
    }

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: parameters,
    ).toString();
  }

  // ============================================================
  // COMMON UI
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _amountTile(
      String label,
      double amount,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(amount),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countTile(
      String label,
      int count,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 3,
        ),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(
      double due,
      double paid, {
        double height = 8,
      }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        value: _progress(due, paid),
        minHeight: height,
        backgroundColor: navy,
        valueColor:
        const AlwaysStoppedAnimation<Color>(teal),
      ),
    );
  }

  Widget _detailRow(
      String label,
      String value, {
        bool copyable = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (copyable && value != 'Not provided')
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () => _copy(value),
              icon: const Icon(
                Icons.copy_outlined,
                color: teal,
                size: 18,
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // PAYMENT HISTORY DATE HELPERS
  // ============================================================

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(
        value < 100000000000
            ? value * 1000
            : value,
      );
    }

    return null;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/'
        '${local.year}  '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _historyDate(
      String jobId,
      String workerId,
      int index,
      ) {
    // Read the stored history entry without requiring
    // new fields in PaymentModel.
    //
    // This function is not used directly to fetch data;
    // history metadata is supplied by the payment stream
    // in _paymentHistory below.
    return '';
  }

  Widget _paymentHistory(
      PaymentModel payment,
      ) {
    if (payment.history.isEmpty) {
      return const Text(
        'No payments recorded yet.',
        style: TextStyle(
          color: muted,
          fontSize: 12,
        ),
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .doc('${payment.jobId}_${payment.workerId}')
          .snapshots(),
      builder: (context, snapshot) {
        final rawHistory =
        snapshot.data?.data()?['history'];

        final entries = rawHistory is List
            ? rawHistory
            : <dynamic>[];

        return Column(
          children: List.generate(
            payment.history.length,
                (index) {
              final entry = payment.history[index];

              Map<String, dynamic> raw = {};

              if (index < entries.length &&
                  entries[index] is Map) {
                raw = Map<String, dynamic>.from(
                  entries[index] as Map,
                );
              }

              final date = _readDate(
                raw['paidAt'] ??
                    raw['createdAt'] ??
                    raw['timestamp'] ??
                    raw['date'] ??
                    raw['recordedAt'],
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: teal,
                      size: 21,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _money(entry.amount),
                            style: const TextStyle(
                              color: teal,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            entry.method,
                            style: const TextStyle(
                              color: white,
                              fontSize: 12,
                            ),
                          ),
                          if (entry.reference.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reference: ${entry.reference}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Text(
                            date == null
                                ? 'Date not recorded'
                                : _formatDate(date),
                            style: const TextStyle(
                              color: muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // WORKER PROFILE + UPI QR
  // ============================================================

  Future<void> _showWorkerPaymentProfile(
      ApplicationModel worker,
      PaymentModel? payment,
      bool present,
      ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null ||
        uid != widget.job.organizerId) {
      _showMessage(
        'Organizer access required.',
        color: red,
      );
      return;
    }

    final due = widget.job.paymentPerWorker;
    final paid = payment?.amountPaid ?? 0.0;
    final remaining = _remaining(due, paid);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: navy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: StreamBuilder<
                DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(worker.workerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _errorView(
                    'Unable to load worker profile',
                    snapshot.error,
                  );
                }

                if (!snapshot.hasData) {
                  return _loading();
                }

                final data = snapshot.data!.data() ??
                    <String, dynamic>{};

                final name = _value(
                  data['name'] ?? worker.workerName,
                );

                final phone = _value(data['phone']);

                final upiMobile = _value(
                  data['upiMobileNumber'],
                );

                final upiId = _value(data['upiId']);

                final accountHolder = _value(
                  data['accountHolderName'],
                );

                final hasUpi =
                    upiId != 'Not provided' &&
                        accountHolder != 'Not provided';

                final qrData = hasUpi
                    ? _upiUri(
                  upiId: upiId,
                  accountHolder: accountHolder,
                  amount: present &&
                      remaining > 0
                      ? remaining
                      : null,
                )
                    : '';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    20,
                    18,
                    30,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: border,
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 19),

                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: panelLight,
                      child: Icon(
                        Icons.person_outline,
                        color: teal,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      worker.workerEmail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Center(
                      child: _badge(
                        _paymentStatus(
                          present,
                          paid,
                          due,
                        ),
                        _statusColor(
                          _paymentStatus(
                            present,
                            paid,
                            due,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    _card(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            'Worker Payment Details',
                          ),
                          _detailRow(
                            'Phone',
                            phone,
                            copyable: true,
                          ),
                          _detailRow(
                            'UPI Mobile',
                            upiMobile,
                            copyable: true,
                          ),
                          _detailRow(
                            'Account Holder',
                            accountHolder,
                          ),
                          _detailRow(
                            'UPI ID',
                            upiId,
                            copyable: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    _card(
                      child: Column(
                        children: [
                          const Text(
                            'Scan to Pay Worker',
                            style: TextStyle(
                              color: white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 9),

                          if (present && remaining > 0)
                            Text(
                              'Remaining: ${_money(remaining)}',
                              style: const TextStyle(
                                color: teal,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                          const SizedBox(height: 17),

                          if (qrData.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(15),
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 210,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel:
                                QrErrorCorrectLevel.M,
                              ),
                            )
                          else
                            const Column(
                              children: [
                                Icon(
                                  Icons.qr_code_2_outlined,
                                  size: 80,
                                  color: muted,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Worker has not completed '
                                      'UPI payment details.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 14),

                          Text(
                            upiId,
                            style: const TextStyle(
                              color: teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 11),

                          const Text(
                            'Verify the recipient and amount '
                                'in your UPI app before sending money.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 7),

                          const Text(
                            'Scanning the QR does not automatically '
                                'record or verify a payment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: amber,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    _card(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            'Event Payment Summary',
                          ),

                          _detailRow(
                            'Event',
                            widget.job.title,
                          ),

                          _detailRow(
                            'Agreed',
                            _money(due),
                          ),

                          _detailRow(
                            'Already Paid',
                            _money(paid),
                          ),

                          _detailRow(
                            'Remaining',
                            _money(remaining),
                          ),

                          _detailRow(
                            'Status',
                            _paymentStatus(
                              present,
                              paid,
                              due,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _progressBar(due, paid),

                          const SizedBox(height: 10),

                          Text(
                            '${(_progress(due, paid) * 100).toStringAsFixed(0)}% paid',
                            style: const TextStyle(
                              color: teal,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    if (!present)
                      const Text(
                        'Mark this worker Present in Attendance '
                            'before recording payment.',
                        style: TextStyle(
                          color: amber,
                          fontSize: 12,
                        ),
                      ),

                    if (present &&
                        remaining > 0.001 &&
                        !_isCancelled())
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: saving
                              ? null
                              : () {
                            Navigator.pop(sheetContext);
                            _record(
                              worker,
                              remaining,
                            );
                          },
                          icon: const Icon(
                            Icons.add_card_outlined,
                          ),
                          label: const Text(
                            'Record Payment',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: teal,
                            foregroundColor: navy,
                            padding: const EdgeInsets.all(15),
                          ),
                        ),
                      ),

                    if (present && remaining <= 0.001)
                      const Center(
                        child: Text(
                          'Payment completed',
                          style: TextStyle(
                            color: teal,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                    if (payment != null &&
                        payment.history.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _card(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Payment History'),
                            _paymentHistory(payment),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // RECORD PAYMENT
  // ============================================================

  Future<void> _record(
      ApplicationModel worker,
      double displayedRemaining,
      ) async {
    if (saving) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null ||
        uid != widget.job.organizerId) {
      _showMessage(
        'Organizer access required.',
        color: red,
      );
      return;
    }

    final amountController = TextEditingController(
      text: displayedRemaining.toStringAsFixed(2),
    );

    final referenceController =
    TextEditingController();

    String method = 'UPI';

    final result = await showDialog<
        Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, update) {
            return AlertDialog(
              backgroundColor: panel,
              title: Text(
                'Record Payment',
                style: const TextStyle(
                  color: white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.workerName,
                      style: const TextStyle(
                        color: teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Remaining: ${_money(displayedRemaining)}',
                      style: const TextStyle(
                        color: muted,
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: amountController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: white),
                      decoration: _inputDecoration(
                        'Amount (₹)',
                      ),
                    ),

                    const SizedBox(height: 13),

                    DropdownButtonFormField<String>(
                      value: method,
                      dropdownColor: panelLight,
                      style: const TextStyle(color: white),
                      decoration: _inputDecoration(
                        'Payment Method',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'UPI',
                          child: Text('UPI'),
                        ),
                        DropdownMenuItem(
                          value: 'Cash',
                          child: Text('Cash'),
                        ),
                        DropdownMenuItem(
                          value: 'Bank Transfer',
                          child: Text('Bank Transfer'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          update(() => method = value);
                        }
                      },
                    ),

                    const SizedBox(height: 13),

                    TextField(
                      controller: referenceController,
                      style: const TextStyle(color: white),
                      decoration: _inputDecoration(
                        'Transaction Reference / Note',
                      ),
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'Record only money that has already '
                          'been paid outside CrewSync.',
                      style: TextStyle(
                        color: amber,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: muted),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: navy,
                  ),
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0 ||
                        amount >
                            displayedRemaining + 0.001) {
                      ScaffoldMessenger.of(dialogContext)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a valid amount within '
                                'the remaining balance.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      {
                        'amount': amount,
                        'method': method,
                        'reference':
                        referenceController.text.trim(),
                      },
                    );
                  },
                  child: const Text('Confirm Record'),
                ),
              ],
            );
          },
        );
      },
    );

    // Allow the dialog to close before disposing
    // its text controllers.
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    amountController.dispose();
    referenceController.dispose();

    if (result == null || !mounted || saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    final paymentId =
        '${widget.job.id}_${worker.workerId}';

    final paymentRef = FirebaseFirestore.instance
        .collection('payments')
        .doc(paymentId);

    final amount = result['amount'] as double;
    final selectedMethod = result['method'] as String;
    final reference = result['reference'] as String;

    String message = '';
    Color messageColor = red;

    try {
      // Recheck organizer authentication.
      final currentUid =
          FirebaseAuth.instance.currentUser?.uid;

      if (currentUid != widget.job.organizerId) {
        throw Exception(
          'Organizer authentication changed.',
        );
      }

      // Recheck accepted application on the server.
      final applicationSnapshot =
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(paymentId)
          .get(
        const GetOptions(
          source: Source.server,
        ),
      );

      if (!applicationSnapshot.exists ||
          (applicationSnapshot.data()?['status']
              ?.toString()
              .toLowerCase() ??
              '') !=
              'accepted') {
        throw Exception(
          'Worker is no longer accepted for this job.',
        );
      }

      // Recheck attendance on the server.
      final attendanceSnapshot =
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(paymentId)
          .get(
        const GetOptions(
          source: Source.server,
        ),
      );

      if (!attendanceSnapshot.exists ||
          (attendanceSnapshot.data()?['status']
              ?.toString()
              .toLowerCase() ??
              '') !=
              'present') {
        throw Exception(
          'Worker must be marked Present '
              'before payment can be recorded.',
        );
      }

      // Recheck the event status.
      final jobSnapshot =
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.job.id)
          .get(
        const GetOptions(
          source: Source.server,
        ),
      );

      if (!jobSnapshot.exists) {
        throw Exception('Event no longer exists.');
      }

      if ((jobSnapshot.data()?['status']
          ?.toString()
          .toLowerCase() ??
          '') ==
          'cancelled') {
        throw Exception(
          'Payments are disabled for cancelled events.',
        );
      }

      // Read the latest payment before saving.
      final beforeSnapshot = await paymentRef.get(
        const GetOptions(source: Source.server),
      );

      final beforeData = beforeSnapshot.data() ??
          <String, dynamic>{};

      final alreadyPaid =
          (beforeData['amountPaid'] as num?)
              ?.toDouble() ??
              0.0;

      final currentRate =
          (jobSnapshot.data()?['paymentPerWorker']
          as num?)
              ?.toDouble() ??
              widget.job.paymentPerWorker;

      final latestRemaining =
      _remaining(currentRate, alreadyPaid);

      if (amount > latestRemaining + 0.001 ||
          latestRemaining <= 0.001) {
        throw Exception(
          'Payment balance has changed. '
              'Please reopen the payment dialog.',
        );
      }

      final beforeHistory =
          (beforeData['history'] as List<dynamic>?) ??
              <dynamic>[];

      final beforeCount = beforeHistory.length;

      try {
        // Preserve existing PaymentService logic.
        await service.recordPayment(
          job: widget.job,
          worker: worker,
          organizerId: currentUid!,
          amount: amount,
          method: selectedMethod,
          reference: reference,
        );

        message = 'Payment recorded successfully.';
        messageColor = teal;
      } catch (paymentError) {
        // Preserve the original safety behavior:
        // verify whether the write succeeded before
        // suggesting that the user try again.
        try {
          final afterSnapshot = await paymentRef.get(
            const GetOptions(source: Source.server),
          );

          final afterHistory =
              (afterSnapshot.data()?['history']
              as List<dynamic>?) ??
                  <dynamic>[];

          bool paymentFound = false;

          if (afterHistory.length > beforeCount) {
            paymentFound = afterHistory
                .skip(beforeCount)
                .any((entry) {
              if (entry is! Map) return false;

              final entryAmount =
              (entry['amount'] as num?)?.toDouble();

              return entryAmount != null &&
                  (entryAmount - amount).abs() < 0.001 &&
                  entry['method'] == selectedMethod &&
                  entry['reference'] == reference;
            });
          }

          if (paymentFound) {
            message = 'Payment recorded successfully.';
            messageColor = teal;
          } else {
            message =
            'Payment could not be confirmed: '
                '$paymentError';
            messageColor = amber;
          }
        } catch (_) {
          message =
          'Payment status uncertain. Check payment '
              'history before trying again.';
          messageColor = amber;
        }
      }
    } catch (error) {
      message = 'Unable to record payment: $error';
      messageColor = red;
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }

    if (message.isNotEmpty) {
      _showMessage(
        message,
        color: messageColor,
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: muted),
      filled: true,
      fillColor: navy,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: teal),
      ),
    );
  }

  // ============================================================
  // ADVANCED SUMMARY
  // ============================================================

  Widget _buildSummary(
      List<ApplicationModel> workers,
      Set<String> presentIds,
      Map<String, PaymentModel> payments,
      ) {
    final eligible = workers.where(
          (worker) => presentIds.contains(worker.workerId),
    ).toList();

    final due = eligible.length *
        widget.job.paymentPerWorker;

    final paid = eligible.fold<double>(
      0,
          (sum, worker) =>
      sum +
          (payments[worker.workerId]?.amountPaid ?? 0),
    );

    final outstanding = eligible.fold<double>(
      0,
          (sum, worker) => sum +
          _remaining(
            widget.job.paymentPerWorker,
            payments[worker.workerId]?.amountPaid ?? 0,
          ),
    );

    final paidCount = eligible.where((worker) {
      final amount =
          payments[worker.workerId]?.amountPaid ?? 0;

      return widget.job.paymentPerWorker > 0 &&
          amount >=
              widget.job.paymentPerWorker - 0.001;
    }).length;

    final partialCount = eligible.where((worker) {
      final amount =
          payments[worker.workerId]?.amountPaid ?? 0;

      return amount > 0 &&
          amount <
              widget.job.paymentPerWorker - 0.001;
    }).length;

    final unpaidCount = eligible.where((worker) {
      final amount =
          payments[worker.workerId]?.amountPaid ?? 0;

      return amount <= 0;
    }).length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: teal,
              ),
              SizedBox(width: 9),
              Text(
                'EVENT PAYMENT OVERVIEW',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            widget.job.title,
            style: const TextStyle(
              color: white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            '${widget.job.date} • ${widget.job.location}',
            style: const TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 19),

          const Text(
            'Total Payable',
            style: TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 7),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _money(due),
              style: const TextStyle(
                color: white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _amountTile(
                  'Total Paid',
                  paid,
                  teal,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _amountTile(
                  'Remaining',
                  outstanding,
                  amber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 19),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Completion',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                ),
              ),
              Text(
                '${(_progress(due, paid) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: teal,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          _progressBar(due, paid, height: 9),

          const SizedBox(height: 19),

          Row(
            children: [
              _countTile(
                'Present',
                eligible.length,
                white,
              ),
              const SizedBox(width: 6),
              _countTile(
                'Paid',
                paidCount,
                teal,
              ),
              const SizedBox(width: 6),
              _countTile(
                'Partial',
                partialCount,
                amber,
              ),
              const SizedBox(width: 6),
              _countTile(
                'Unpaid',
                unpaidCount,
                red,
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            '${workers.length} accepted • '
                '${workers.length - eligible.length} not eligible',
            style: const TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH, FILTER AND SORT
  // ============================================================

  Widget _searchBar() {
    return TextField(
      controller: searchController,
      style: const TextStyle(color: white),
      onChanged: (value) {
        setState(() {
          search = value.trim().toLowerCase();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search worker name or email...',
        hintStyle: const TextStyle(
          color: muted,
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: coral,
        ),
        suffixIcon: search.isEmpty
            ? null
            : IconButton(
          icon: const Icon(
            Icons.close,
            color: muted,
          ),
          onPressed: () {
            searchController.clear();
            setState(() => search = '');
          },
        ),
        filled: true,
        fillColor: panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: coral),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 43,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = filters[index];
          final selected = filter == value;

          return ChoiceChip(
            label: Text(value),
            selected: selected,
            showCheckmark: false,
            backgroundColor: panel,
            selectedColor: coral,
            side: BorderSide(
              color: selected ? coral : border,
            ),
            labelStyle: TextStyle(
              color: selected ? white : muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) {
              setState(() {
                filter = value;
              });
            },
          );
        },
      ),
    );
  }

  Widget _sortBar() {
    return Row(
      children: [
        const Icon(
          Icons.sort_rounded,
          color: coral,
          size: 19,
        ),
        const SizedBox(width: 8),
        const Text(
          'Sort workers',
          style: TextStyle(
            color: muted,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        DropdownButton<String>(
          value: sort,
          dropdownColor: panel,
          underline: const SizedBox(),
          style: const TextStyle(
            color: white,
            fontSize: 12,
          ),
          items: const [
            DropdownMenuItem(
              value: 'Name',
              child: Text('Name'),
            ),
            DropdownMenuItem(
              value: 'Highest Due',
              child: Text('Highest Due'),
            ),
            DropdownMenuItem(
              value: 'Most Paid',
              child: Text('Most Paid'),
            ),
            DropdownMenuItem(
              value: 'Least Paid',
              child: Text('Least Paid'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              sort = value;
            });
          },
        ),
      ],
    );
  }

  List<ApplicationModel> _filterWorkers(
      List<ApplicationModel> workers,
      Set<String> presentIds,
      Map<String, PaymentModel> payments,
      ) {
    final due = widget.job.paymentPerWorker;

    final result = workers.where((worker) {
      final present =
      presentIds.contains(worker.workerId);

      final paid =
          payments[worker.workerId]?.amountPaid ?? 0;

      final status = _paymentStatus(
        present,
        paid,
        due,
      );

      final matchesSearch =
          search.isEmpty ||
              worker.workerName.toLowerCase().contains(search) ||
              worker.workerEmail.toLowerCase().contains(search);

      bool matchesFilter = true;

      switch (filter) {
        case 'Present':
          matchesFilter = present;
          break;

        case 'Not Eligible':
          matchesFilter = !present;
          break;

        case 'Unpaid':
          matchesFilter = status == 'Unpaid';
          break;

        case 'Partially Paid':
          matchesFilter =
              status == 'Partially Paid';
          break;

        case 'Paid':
          matchesFilter = status == 'Paid';
          break;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    result.sort((a, b) {
      final paidA =
          payments[a.workerId]?.amountPaid ?? 0.0;

      final paidB =
          payments[b.workerId]?.amountPaid ?? 0.0;

      if (sort == 'Most Paid') {
        return paidB.compareTo(paidA);
      }

      if (sort == 'Least Paid') {
        return paidA.compareTo(paidB);
      }

      if (sort == 'Highest Due') {
        final dueA = presentIds.contains(a.workerId)
            ? _remaining(due, paidA)
            : 0.0;

        final dueB = presentIds.contains(b.workerId)
            ? _remaining(due, paidB)
            : 0.0;

        return dueB.compareTo(dueA);
      }

      return a.workerName.toLowerCase().compareTo(
        b.workerName.toLowerCase(),
      );
    });

    return result;
  }

  // ============================================================
  // WORKER PAYMENT CARD
  // ============================================================

  Widget _workerCard(
      ApplicationModel worker,
      PaymentModel? payment,
      bool present,
      ) {
    final due = widget.job.paymentPerWorker;
    final paid = payment?.amountPaid ?? 0.0;

    final remaining = _remaining(due, paid);

    final status = _paymentStatus(
      present,
      paid,
      due,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: panelLight,
                  child: Icon(
                    Icons.person_outline,
                    color: teal,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.workerName,
                        style: const TextStyle(
                          color: white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        worker.workerEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                _badge(
                  present ? 'Present' : 'Not Present',
                  present ? teal : muted,
                ),
                _badge(
                  status,
                  _statusColor(status),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(color: border),

            const SizedBox(height: 13),

            Row(
              children: [
                Expanded(
                  child: _amountTile(
                    'Agreed',
                    due,
                    white,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _amountTile(
                    'Paid',
                    paid,
                    teal,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _amountTile(
                    'Remaining',
                    present ? remaining : 0,
                    amber,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment Progress',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(_progress(due, paid) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 9),

            _progressBar(due, paid),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showWorkerPaymentProfile(
                    worker,
                    payment,
                    present,
                  );
                },
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                label: const Text(
                  'View Payment Profile & UPI QR',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: teal,
                  side: const BorderSide(color: teal),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                ),
              ),
            ),

            if (!present) ...[
              const SizedBox(height: 11),
              const Text(
                'Mark this worker Present in Attendance '
                    'to enable payment.',
                style: TextStyle(
                  color: amber,
                  fontSize: 11,
                ),
              ),
            ],

            if (present &&
                remaining > 0.001 &&
                !_isCancelled()) ...[
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () => _record(
                    worker,
                    remaining,
                  ),
                  icon: const Icon(
                    Icons.add_card_outlined,
                  ),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : 'Record Payment',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: navy,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],

            if (present && remaining <= 0.001)
              const Padding(
                padding: EdgeInsets.only(top: 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: teal,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Payment completed',
                      style: TextStyle(
                        color: teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

            if (payment != null &&
                payment.history.isNotEmpty) ...[
              const SizedBox(height: 12),

              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  iconColor: teal,
                  collapsedIconColor: muted,
                  title: const Text(
                    'Payment History',
                    style: TextStyle(
                      color: white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  children: [
                    _paymentHistory(payment),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: const ColorScheme.dark(
          primary: coral,
          secondary: teal,
          surface: panel,
          onSurface: white,
        ),
      ),
      child: Scaffold(
        backgroundColor: navy,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 18, 15),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: white, size: 21),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Event Payments',
                              style: TextStyle(color: white, fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                          SizedBox(height: 4),
                          Text('Manage worker payouts',
                              style: TextStyle(color: muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: coral.withValues(alpha: 0.20)),
                      ),
                      child: const Icon(Icons.payments_outlined,
                          color: coral, size: 23),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: uid == null ||
                    uid != widget.job.organizerId
                    ? _messageView(
                  'Organizer access required.',
                )
                    : StreamBuilder<List<ApplicationModel>>(
                  stream: applicationService
                      .getOrganizerApplications(uid),
                  builder: (context, appSnapshot) {
                    if (appSnapshot.hasError) {
                      return _errorView(
                        'Unable to load applications',
                        appSnapshot.error,
                      );
                    }

                    if (!appSnapshot.hasData) {
                      return _loading();
                    }

                    final workers = appSnapshot.data!
                        .where(
                          (application) =>
                      application.jobId ==
                          widget.job.id &&
                          application.status
                              .toLowerCase() ==
                              'accepted',
                    )
                        .toList();

                    return StreamBuilder<
                        List<AttendanceModel>>(
                      stream: attendanceService
                          .getOrganizerJobAttendance(
                        organizerId: uid,
                        jobId: widget.job.id,
                      ),
                      builder: (context, attendanceSnapshot) {
                        if (attendanceSnapshot.hasError) {
                          return _errorView(
                            'Unable to load attendance',
                            attendanceSnapshot.error,
                          );
                        }

                        if (!attendanceSnapshot.hasData) {
                          return _loading();
                        }

                        final presentIds = attendanceSnapshot
                            .data!
                            .where(
                              (attendance) =>
                          attendance.jobId ==
                              widget.job.id &&
                              _isPresent(
                                attendance.status,
                              ),
                        )
                            .map(
                              (attendance) =>
                          attendance.workerId,
                        )
                            .toSet();

                        return StreamBuilder<
                            List<PaymentModel>>(
                          stream:
                          service.organizerPayments(uid),
                          builder: (context, paymentSnapshot) {
                            if (paymentSnapshot.hasError) {
                              return _errorView(
                                'Unable to load payments',
                                paymentSnapshot.error,
                              );
                            }

                            if (!paymentSnapshot.hasData) {
                              return _loading();
                            }

                            final payments =
                            <String, PaymentModel>{
                              for (final payment
                              in paymentSnapshot.data!
                                  .where(
                                    (payment) =>
                                payment.jobId ==
                                    widget.job.id,
                              ))
                                payment.workerId: payment,
                            };

                            final shown = _filterWorkers(
                              workers,
                              presentIds,
                              payments,
                            );

                            return ListView(
                              padding:
                              const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                32,
                              ),
                              children: [
                                _buildSummary(
                                  workers,
                                  presentIds,
                                  payments,
                                ),

                                const SizedBox(height: 23),

                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Worker Payments',
                                        style: TextStyle(
                                          color: white,
                                          fontSize: 19,
                                          fontWeight:
                                          FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${shown.length} workers',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                const Text(
                                  'Review attendance, worker UPI '
                                      'details and recorded payments.',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                _searchBar(),

                                const SizedBox(height: 13),

                                _filterBar(),

                                const SizedBox(height: 10),

                                _sortBar(),

                                const SizedBox(height: 14),

                                if (shown.isEmpty)
                                  _card(
                                    child: const Padding(
                                      padding:
                                      EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.people_outline,
                                            color: teal,
                                            size: 37,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'No workers found',
                                            style: TextStyle(
                                              color: white,
                                              fontWeight:
                                              FontWeight.w900,
                                            ),
                                          ),
                                          SizedBox(height: 7),
                                          Text(
                                            'Try changing the '
                                                'search or filter.',
                                            style: TextStyle(
                                              color: muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...shown.map(
                                        (worker) => _workerCard(
                                      worker,
                                      payments[worker.workerId],
                                      presentIds.contains(
                                        worker.workerId,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING AND ERROR STATES
  // ============================================================

  Widget _loading() {
    return const Center(
      child: CircularProgressIndicator(
        color: teal,
      ),
    );
  }

  Widget _messageView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: muted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _errorView(
      String title,
      Object? error,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: red,
              size: 43,
            ),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: red,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

