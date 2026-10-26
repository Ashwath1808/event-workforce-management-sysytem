
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';
import 'job_model.dart';
import 'job_service.dart';
import 'payment_model.dart';
import 'payment_service.dart';

class WorkerPaymentsPage extends StatefulWidget {
  const WorkerPaymentsPage({super.key});

  @override
  State<WorkerPaymentsPage> createState() =>
      _WorkerPaymentsPageState();
}

class _WorkerPaymentsPageState extends State<WorkerPaymentsPage> {
  static const Color navy = Color(0xFF101828);
  static const Color emerald = Color(0xFF00C9A7);
  static const Color deepGreen = Color(0xFF008F78);
  static const Color background = Color(0xFFF3F6F8);
  static const Color ink = Color(0xFF182230);
  static const Color muted = Color(0xFF526174);
  static const Color border = Color(0xFFE3E9EF);
  static const Color mint = Color(0xFFE0F7F0);
  static const Color amber = Color(0xFFB7791F);
  static const Color red = Color(0xFFC74752);

  final ApplicationService _applicationService =
  ApplicationService();
  final AttendanceService _attendanceService =
  AttendanceService();
  final PaymentService _paymentService = PaymentService();
  final JobService _jobService = JobService();

  final TextEditingController _searchController =
  TextEditingController();

  final Map<String, Future<JobModel?>> _jobFutures = {};

  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';
  String _searchQuery = '';
  bool _showMonthlyBreakdown = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<JobModel?> _getJob(String jobId) {
    return _jobFutures.putIfAbsent(
      jobId,
          () => _jobService.getJob(jobId),
    );
  }

  Future<List<JobModel?>> _loadJobs(
      List<ApplicationModel> apps,
      ) {
    final ids = apps.map((app) => app.jobId).toSet();
    return Future.wait(ids.map(_getJob));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: navy,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 72,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Payments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'YOUR EARNINGS WORKSPACE',
              style: TextStyle(
                color: emerald,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: emerald,
            ),
          ),
        ],
      ),
      body: uid == null
          ? _emptyPage(
        'Login Required',
        'Please log in to view your payments.',
        Icons.lock_outline_rounded,
      )
          : StreamBuilder<List<ApplicationModel>>(
        stream: _applicationService
            .getWorkerApplications(uid),
        builder: (context, appSnapshot) {
          if (appSnapshot.hasError) {
            return _errorView(appSnapshot.error);
          }
          if (!appSnapshot.hasData) {
            return _loadingView();
          }

          final acceptedApps = appSnapshot.data!
              .where(
                (app) =>
            app.status.toLowerCase() == 'accepted',
          )
              .toList();

          return StreamBuilder<List<AttendanceModel>>(
            stream: _attendanceService
                .getWorkerAttendance(uid),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.hasError) {
                return _errorView(
                  attendanceSnapshot.error,
                );
              }
              if (!attendanceSnapshot.hasData) {
                return _loadingView();
              }

              final presentJobIds =
              attendanceSnapshot.data!
                  .where(
                    (attendance) =>
                attendance.status.toLowerCase() ==
                    'present',
              )
                  .map((attendance) => attendance.jobId)
                  .toSet();

              return StreamBuilder<List<PaymentModel>>(
                stream:
                _paymentService.workerPayments(uid),
                builder: (context, paymentSnapshot) {
                  if (paymentSnapshot.hasError) {
                    return _errorView(
                      paymentSnapshot.error,
                    );
                  }
                  if (!paymentSnapshot.hasData) {
                    return _loadingView();
                  }

                  final paymentsByJob =
                  <String, PaymentModel>{
                    for (final payment
                    in paymentSnapshot.data!)
                      payment.jobId: payment,
                  };

                  return FutureBuilder<List<JobModel?>>(
                    future: _loadJobs(acceptedApps),
                    builder: (context, jobSnapshot) {
                      if (jobSnapshot.hasError) {
                        return _errorView(
                          jobSnapshot.error,
                        );
                      }
                      if (!jobSnapshot.hasData) {
                        return _loadingView();
                      }

                      final jobsById = <String, JobModel>{
                        for (final job in jobSnapshot.data!)
                          if (job != null) job.id: job,
                      };

                      return _buildDashboard(
                        acceptedApps: acceptedApps,
                        presentJobIds: presentJobIds,
                        paymentsByJob: paymentsByJob,
                        jobsById: jobsById,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<_WorkerPaymentRecord> _createRecords({
    required List<ApplicationModel> acceptedApps,
    required Set<String> presentJobIds,
    required Map<String, PaymentModel> paymentsByJob,
    required Map<String, JobModel> jobsById,
  }) {
    final records = <_WorkerPaymentRecord>[];

    for (final app in acceptedApps) {
      final job = jobsById[app.jobId];
      final payment = paymentsByJob[app.jobId];

      final isPresent = presentJobIds.contains(app.jobId);
      final isCancelled =
          job?.status.toLowerCase() == 'cancelled';

      final isEligible =
          job != null && isPresent && !isCancelled;

      final agreed = job?.paymentPerWorker ?? 0.0;
      final earnings = isEligible ? agreed : 0.0;

      final received = isEligible
          ? (payment?.amountPaid ?? 0.0)
          .clamp(0.0, double.infinity)
          .toDouble()
          : 0.0;

      final pending = isEligible
          ? (earnings - received)
          .clamp(0.0, double.infinity)
          .toDouble()
          : 0.0;

      String status;

      if (isCancelled) {
        status = 'Event Cancelled';
      } else if (!isPresent) {
        status = 'Attendance Pending';
      } else if (job == null) {
        status = 'Event Unavailable';
      } else if (received >= earnings - 0.001) {
        status = 'Received';
      } else if (received > 0) {
        status = 'Partially Received';
      } else {
        status = 'Pending';
      }

      records.add(
        _WorkerPaymentRecord(
          app: app,
          job: job,
          payment: payment,
          earnings: earnings,
          received: received,
          pending: pending,
          status: status,
          isEligible: isEligible,
        ),
      );
    }

    return records;
  }

  Widget _buildDashboard({
    required List<ApplicationModel> acceptedApps,
    required Set<String> presentJobIds,
    required Map<String, PaymentModel> paymentsByJob,
    required Map<String, JobModel> jobsById,
  }) {
    final records = _createRecords(
      acceptedApps: acceptedApps,
      presentJobIds: presentJobIds,
      paymentsByJob: paymentsByJob,
      jobsById: jobsById,
    );

    final totalEarnings = records.fold<double>(
      0,
          (sum, record) => sum + record.earnings,
    );
    final totalReceived = records.fold<double>(
      0,
          (sum, record) => sum + record.received,
    );
    final totalPending = records.fold<double>(
      0,
          (sum, record) => sum + record.pending,
    );

    final eligibleEvents =
        records.where((r) => r.isEligible).length;
    final receivedEvents =
        records.where((r) => r.status == 'Received').length;

    final filtered = records.where((record) {
      if (!record.app.jobTitle
          .toLowerCase()
          .contains(_searchQuery.toLowerCase())) {
        return false;
      }

      switch (_selectedFilter) {
        case 'Received':
          return record.status == 'Received';
        case 'Pending':
          return record.status == 'Pending';
        case 'Partial':
          return record.status == 'Partially Received';
        case 'Cancelled':
          return record.status == 'Event Cancelled';
        case 'Attendance':
          return record.status == 'Attendance Pending';
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      final aDate = _parseDate(a.job?.date ?? '');
      final bDate = _parseDate(b.job?.date ?? '');

      switch (_selectedSort) {
        case 'Oldest':
          return _compareDates(aDate, bDate, false);
        case 'Highest':
          return b.earnings.compareTo(a.earnings);
        case 'Lowest':
          return a.earnings.compareTo(b.earnings);
        default:
          return _compareDates(aDate, bDate, true);
      }
    });

    return RefreshIndicator(
      color: deepGreen,
      onRefresh: () async {
        setState(() => _jobFutures.clear());
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 35),
        children: [
          _earningsHero(
            totalEarnings,
            totalReceived,
            eligibleEvents,
            receivedEvents,
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Received',
                  totalReceived,
                  Icons.check_circle_outline_rounded,
                  deepGreen,
                  mint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  'Pending',
                  totalPending,
                  Icons.schedule_rounded,
                  amber,
                  const Color(0xFFFFF4E3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          _monthlySection(records),
          const SizedBox(height: 25),
          _sectionHeading(
            'Payment History',
            'Track your event-wise earnings and transfers.',
          ),
          const SizedBox(height: 16),
          _searchField(),
          const SizedBox(height: 15),
          _filterBar(),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${filtered.length} events',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _sortMenu(),
            ],
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _emptyHistory(
              acceptedApps.isEmpty
                  ? 'No accepted events yet'
                  : 'No matching payments',
              acceptedApps.isEmpty
                  ? 'Your accepted events will appear here.'
                  : 'Try another search or filter.',
            )
          else
            ...filtered.map(_paymentCard),
          const SizedBox(height: 14),
          _paymentSafetyNotice(),
        ],
      ),
    );
  }

  Widget _earningsHero(
      double totalEarnings,
      double totalReceived,
      int eligibleEvents,
      int receivedEvents,
      ) {
    final progress = totalEarnings <= 0
        ? 0.0
        : (totalReceived / totalEarnings)
        .clamp(0.0, 1.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            navy,
            Color(0xFF1B3442),
            Color(0xFF12655C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: emerald,
              ),
              SizedBox(width: 10),
              Text(
                'TOTAL EARNINGS',
                style: TextStyle(
                  color: Color(0xFFD4E6E4),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _money(totalEarnings),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 37,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$eligibleEvents eligible events  •  '
                '$receivedEvents fully received',
            style: const TextStyle(
              color: Color(0xFFD1E3E2),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment progress',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: emerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              color: emerald,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Based on eligible events and '
                'organizer-recorded payments.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
      String title,
      double amount,
      IconData icon,
      Color iconColor,
      Color iconBackground,
      ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _money(amount),
                style: TextStyle(
                  color: iconColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthlySection(
      List<_WorkerPaymentRecord> records,
      ) {
    final monthly = <DateTime, _MonthlyEarnings>{};

    for (final record in records) {
      if (!record.isEligible) continue;

      final date = _parseDate(record.job?.date ?? '');
      if (date == null) continue;

      final month = DateTime(date.year, date.month);
      final summary = monthly.putIfAbsent(
        month,
            () => _MonthlyEarnings(),
      );

      summary.earned += record.earnings;
      summary.received += record.received;
      summary.pending += record.pending;
      summary.events++;
    }

    final months = monthly.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showMonthlyBreakdown =
                !_showMonthlyBreakdown;
              });
            },
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: mint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: deepGreen,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Earnings',
                        style: TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Breakdown by event month',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showMonthlyBreakdown
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: deepGreen,
                ),
              ],
            ),
          ),
          if (_showMonthlyBreakdown) ...[
            const SizedBox(height: 18),
            const Divider(color: border),
            if (months.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No eligible dated events yet.',
                    style: TextStyle(color: muted),
                  ),
                ),
              )
            else
              ...months.map((month) {
                final summary = monthly[month]!;
                final progress = summary.earned <= 0
                    ? 0.0
                    : (summary.received / summary.earned)
                    .clamp(0.0, 1.0)
                    .toDouble();

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 17,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _monthLabel(month),
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _money(summary.earned),
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${summary.events} events • '
                            '${_money(summary.received)} received • '
                            '${_money(summary.pending)} pending',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          color: deepGreen,
                          backgroundColor: mint,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const Text(
              'Grouped by event date, not transfer date.',
              style: TextStyle(
                color: muted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() => _searchQuery = value.trim());
      },
      decoration: InputDecoration(
        hintText: 'Search events...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: deepGreen,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
          icon: const Icon(Icons.close_rounded),
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: deepGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    const filters = [
      'All',
      'Received',
      'Pending',
      'Partial',
      'Cancelled',
      'Attendance',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              showCheckmark: false,
              selectedColor: mint,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? deepGreen : border,
              ),
              labelStyle: TextStyle(
                color: selected ? deepGreen : muted,
                fontWeight: selected
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() => _selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sortMenu() {
    return PopupMenuButton<String>(
      initialValue: _selectedSort,
      onSelected: (value) {
        setState(() => _selectedSort = value);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'Newest',
          child: Text('Newest events'),
        ),
        PopupMenuItem(
          value: 'Oldest',
          child: Text('Oldest events'),
        ),
        PopupMenuItem(
          value: 'Highest',
          child: Text('Highest earnings'),
        ),
        PopupMenuItem(
          value: 'Lowest',
          child: Text('Lowest earnings'),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sort_rounded,
            color: deepGreen,
          ),
          const SizedBox(width: 6),
          Text(
            _selectedSort,
            style: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: muted,
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(_WorkerPaymentRecord record) {
    final job = record.job;
    final agreed = job?.paymentPerWorker ?? 0.0;

    final progress = agreed <= 0
        ? 0.0
        : (record.received / agreed)
        .clamp(0.0, 1.0)
        .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showPaymentDetails(record),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: navy,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.event_available_outlined,
                        color: emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.app.jobTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            job?.date ?? 'Date unavailable',
                            style: const TextStyle(
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: deepGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _statusBadge(record.status),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _amountLabel(
                          'Agreed',
                          _money(agreed),
                          navy,
                        ),
                      ),
                      Expanded(
                        child: _amountLabel(
                          'Received',
                          _money(record.received),
                          deepGreen,
                        ),
                      ),
                      Expanded(
                        child: _amountLabel(
                          'Pending',
                          _money(record.pending),
                          amber,
                        ),
                      ),
                    ],
                  ),
                ),
                if (record.isEligible) ...[
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Payment completion',
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: deepGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      color: deepGreen,
                      backgroundColor: mint,
                    ),
                  ),
                ],
                if (record.payment != null &&
                    record.payment!.history.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${record.payment!.history.length} '
                        'transaction(s) recorded',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'VIEW DETAILS',
                      style: TextStyle(
                        color: deepGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: deepGreen,
                      size: 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountLabel(
      String title,
      String amount,
      Color valueColor,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  void _showPaymentDetails(_WorkerPaymentRecord record) {
    final job = record.job;
    final payment = record.payment;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Column(
            children: [
              Container(
                width: 45,
                height: 5,
                margin: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    20, 0, 20, 30,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Details',
                        style: TextStyle(
                          color: navy,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.app.jobTitle,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _statusBadge(record.status),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: navy,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AMOUNT RECEIVED',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _money(record.received),
                              style: const TextStyle(
                                color: emerald,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'As recorded by the organizer',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _detailsSection(
                        'Event Information',
                        [
                          _detailRow(
                            'Event Date',
                            job?.date ?? 'Unavailable',
                          ),
                          _detailRow(
                            'Location',
                            job?.location ?? 'Unavailable',
                          ),
                          _detailRow(
                            'Payment Status',
                            record.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      _detailsSection(
                        'Payment Breakdown',
                        [
                          _detailRow(
                            'Agreed Earnings',
                            _money(job?.paymentPerWorker ?? 0.0),
                          ),
                          _detailRow(
                            'Eligible Earnings',
                            _money(record.earnings),
                          ),
                          _detailRow(
                            'Amount Received',
                            _money(record.received),
                            valueColor: deepGreen,
                          ),
                          _detailRow(
                            'Amount Pending',
                            _money(record.pending),
                            valueColor: amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _sectionHeading(
                        'Transaction History',
                        'Payments recorded for this event.',
                      ),
                      const SizedBox(height: 14),
                      if (payment == null ||
                          payment.history.isEmpty)
                        _emptyHistory(
                          'No transactions yet',
                          'No payment transactions have '
                              'been recorded for this event.',
                        )
                      else
                        ...payment.history.asMap().entries.map(
                              (entry) => _transactionCard(
                            entry.key,
                            entry.value.amount,
                            entry.value.method,
                            entry.value.reference,
                          ),
                        ),
                      const SizedBox(height: 18),
                      _paymentSafetyNotice(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailsSection(
      String title,
      List<Widget> children,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(
      String title,
      String value, {
        Color valueColor = ink,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionCard(
      int index,
      double amount,
      String method,
      String reference,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.south_west_rounded,
              color: deepGreen,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _money(amount),
                  style: const TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Payment ${index + 1}',
                  style: const TextStyle(
                    color: deepGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Method: $method',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  reference.trim().isEmpty
                      ? 'No reference provided'
                      : 'Reference: $reference',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color foreground;
    Color bg;
    IconData icon;

    switch (status) {
      case 'Received':
        foreground = deepGreen;
        bg = mint;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'Partially Received':
      case 'Pending':
        foreground = amber;
        bg = const Color(0xFFFFF4E3);
        icon = Icons.schedule_rounded;
        break;
      case 'Event Cancelled':
        foreground = red;
        bg = const Color(0xFFFFEBED);
        icon = Icons.cancel_outlined;
        break;
      default:
        foreground = muted;
        bg = const Color(0xFFF0F3F6);
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8E8DF),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: deepGreen,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Safety',
                  style: TextStyle(
                    color: navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Payments shown here are recorded '
                      'by organizers. Confirm the actual '
                      'transfer in your bank or UPI app. '
                      'CrewSync does not transfer money.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: navy,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: muted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: navy.withOpacity(0.045),
          blurRadius: 17,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _loadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: deepGreen,
      ),
    );
  }

  Widget _errorView(Object? error) {
    return _emptyPage(
      'Unable to Load Payments',
      error.toString(),
      Icons.error_outline_rounded,
    );
  }

  Widget _emptyPage(
      String title,
      String subtitle,
      IconData icon,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: _emptyHistory(
          title,
          subtitle,
          icon: icon,
        ),
      ),
    );
  }

  Widget _emptyHistory(
      String title,
      String subtitle, {
        IconData icon = Icons.receipt_long_outlined,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              color: deepGreen,
              size: 36,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    final numeric = RegExp(
      r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$',
    ).firstMatch(raw);

    if (numeric != null) {
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      final year = int.parse(numeric.group(3)!);

      final date = DateTime(year, month, day);

      if (date.year == year &&
          date.month == month &&
          date.day == day) {
        return date;
      }
      return null;
    }

    const monthNumbers = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    final named = RegExp(
      r'^(\d{1,2})[\s-]+([a-zA-Z]+)[\s,-]+(\d{4})$',
    ).firstMatch(raw);

    if (named != null) {
      final day = int.parse(named.group(1)!);
      final month =
      monthNumbers[named.group(2)!.toLowerCase()];
      final year = int.parse(named.group(3)!);

      if (month == null) return null;

      final date = DateTime(year, month, day);

      if (date.year == year &&
          date.month == month &&
          date.day == day) {
        return date;
      }
    }

    return null;
  }

  int _compareDates(
      DateTime? a,
      DateTime? b,
      bool newestFirst,
      ) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    return newestFirst
        ? b.compareTo(a)
        : a.compareTo(b);
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _money(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }
}

class _WorkerPaymentRecord {
  final ApplicationModel app;
  final JobModel? job;
  final PaymentModel? payment;
  final double earnings;
  final double received;
  final double pending;
  final String status;
  final bool isEligible;

  const _WorkerPaymentRecord({
    required this.app,
    required this.job,
    required this.payment,
    required this.earnings,
    required this.received,
    required this.pending,
    required this.status,
    required this.isEligible,
  });
}

class _MonthlyEarnings {
  double earned = 0;
  double received = 0;
  double pending = 0;
  int events = 0;
}
