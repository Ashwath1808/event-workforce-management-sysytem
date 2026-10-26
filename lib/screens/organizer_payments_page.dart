
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'job_model.dart';
import 'job_service.dart';
import 'application_model.dart';
import 'application_service.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';
import 'payment_model.dart';
import 'payment_service.dart';
import 'event_payment_details_page.dart';

// ============================================================
// CREWSYNC — ORGANIZER PAYMENTS
// MIDNIGHT NAVY & CORAL ORANGE
// ============================================================

class OrganizerPaymentsPage extends StatefulWidget {
  const OrganizerPaymentsPage({super.key});

  @override
  State<OrganizerPaymentsPage> createState() =>
      _OrganizerPaymentsPageState();
}

class _OrganizerPaymentsPageState
    extends State<OrganizerPaymentsPage> {
  static const Color navy = Color(0xFF0B1220);
  static const Color panel = Color(0xFF19263B);
  static const Color panelLight = Color(0xFF203149);
  static const Color coral = Color(0xFFF06449);
  static const Color coralBright = Color(0xFFFF7857);
  static const Color teal = Color(0xFF35D1AC);
  static const Color muted = Color(0xFFA7B7CD);
  static const Color white = Color(0xFFF7F9FC);
  static const Color border = Color(0xFF2B3D54);
  static const Color amber = Color(0xFFFFC178);
  static const Color red = Color(0xFFFF8490);

  final JobService _jobService = JobService();

  final ApplicationService _applicationService =
  ApplicationService();

  final AttendanceService _attendanceService =
  AttendanceService();

  final PaymentService _paymentService = PaymentService();

  final TextEditingController _searchController =
  TextEditingController();

  String _search = '';
  String _filter = 'All';
  String _sort = 'Newest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // MAIN SCREEN
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
              _buildHeader(),
              Expanded(
                child: uid == null
                    ? _message(
                  'Please log in to view payments.',
                )
                    : StreamBuilder<List<JobModel>>(
                  stream: _jobService.getOrganizerJobs(uid),
                  builder: (context, jobsSnapshot) {
                    if (jobsSnapshot.hasError) {
                      return _error(
                        'Unable to load events',
                        jobsSnapshot.error,
                      );
                    }

                    if (!jobsSnapshot.hasData) {
                      return _loading();
                    }

                    return StreamBuilder<
                        List<ApplicationModel>>(
                      stream: _applicationService
                          .getOrganizerApplications(uid),
                      builder: (
                          context,
                          applicationsSnapshot,
                          ) {
                        if (applicationsSnapshot.hasError) {
                          return _error(
                            'Unable to load applications',
                            applicationsSnapshot.error,
                          );
                        }

                        if (!applicationsSnapshot.hasData) {
                          return _loading();
                        }

                        return StreamBuilder<
                            List<AttendanceModel>>(
                          stream: _attendanceService
                              .getOrganizerAttendance(uid),
                          builder: (
                              context,
                              attendanceSnapshot,
                              ) {
                            if (attendanceSnapshot.hasError) {
                              return _error(
                                'Unable to load attendance',
                                attendanceSnapshot.error,
                              );
                            }

                            if (!attendanceSnapshot.hasData) {
                              return _loading();
                            }

                            return StreamBuilder<
                                List<PaymentModel>>(
                              stream: _paymentService
                                  .organizerPayments(uid),
                              builder: (
                                  context,
                                  paymentsSnapshot,
                                  ) {
                                if (paymentsSnapshot.hasError) {
                                  return _error(
                                    'Unable to load payments',
                                    paymentsSnapshot.error,
                                  );
                                }

                                if (!paymentsSnapshot.hasData) {
                                  return _loading();
                                }

                                return _dashboard(
                                  jobsSnapshot.data!,
                                  applicationsSnapshot.data!,
                                  attendanceSnapshot.data!,
                                  paymentsSnapshot.data!,
                                );
                              },
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
  // SEAMLESS HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 18, 15),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: white,
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payments',
                  style: TextStyle(
                    color: white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track and manage event payouts',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
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
                color: coral.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: coralBright,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT CALCULATIONS — EXISTING LOGIC
  // ============================================================

  List<_WorkerPaymentInfo> _calculateWorkers(
      List<JobModel> jobs,
      List<ApplicationModel> applications,
      List<AttendanceModel> attendance,
      List<PaymentModel> payments,
      ) {
    final result = <_WorkerPaymentInfo>[];

    final attendanceByKey = <String, AttendanceModel>{};

    for (final record in attendance) {
      attendanceByKey[
      '${record.jobId}_${record.workerId}'] = record;
    }

    final paymentsByKey = <String, PaymentModel>{};

    for (final payment in payments) {
      paymentsByKey[
      '${payment.jobId}_${payment.workerId}'] = payment;
    }

    final acceptedByKey = <String, ApplicationModel>{};

    for (final application in applications) {
      if (application.status.trim().toLowerCase() !=
          'accepted') {
        continue;
      }

      acceptedByKey[
      '${application.jobId}_${application.workerId}'] =
          application;
    }

    for (final job in jobs) {
      for (final application in acceptedByKey.values) {
        if (application.jobId != job.id) {
          continue;
        }

        final key =
            '${job.id}_${application.workerId}';

        final attendanceRecord = attendanceByKey[key];

        if (attendanceRecord == null ||
            attendanceRecord.status
                .trim()
                .toLowerCase() !=
                'present') {
          continue;
        }

        final paymentRecord = paymentsByKey[key];

        final due = job.paymentPerWorker;
        final paid = paymentRecord?.amountPaid ?? 0.0;

        final remaining = (due - paid)
            .clamp(0.0, double.infinity)
            .toDouble();

        result.add(
          _WorkerPaymentInfo(
            jobId: job.id,
            amountDue: due,
            amountPaid: paid,
            remaining: remaining,
          ),
        );
      }
    }

    return result;
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _dashboard(
      List<JobModel> jobs,
      List<ApplicationModel> applications,
      List<AttendanceModel> attendance,
      List<PaymentModel> payments,
      ) {
    final workers = _calculateWorkers(
      jobs,
      applications,
      attendance,
      payments,
    );

    final totalDue = workers.fold<double>(
      0,
          (sum, worker) => sum + worker.amountDue,
    );

    final totalPaid = workers.fold<double>(
      0,
          (sum, worker) => sum + worker.amountPaid,
    );

    final outstanding = workers.fold<double>(
      0,
          (sum, worker) => sum + worker.remaining,
    );

    final paidCount =
        workers.where((worker) => worker.isPaid).length;

    final partialCount =
        workers.where((worker) => worker.isPartial).length;

    final unpaidCount =
        workers.where((worker) => worker.isUnpaid).length;

    final filteredJobs = _filteredJobs(jobs);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 35),
      children: [
        _summary(
          totalDue: totalDue,
          totalPaid: totalPaid,
          outstanding: outstanding,
        ),
        const SizedBox(height: 15),
        _workerCounts(
          total: workers.length,
          paid: paidCount,
          partial: partialCount,
          unpaid: unpaidCount,
        ),
        const SizedBox(height: 27),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Event Payments',
                style: TextStyle(
                  color: white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Text(
              '${filteredJobs.length} events',
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'Payment dues update automatically when '
              'accepted workers are marked Present.',
          style: TextStyle(
            color: muted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 17),
        _searchBar(),
        const SizedBox(height: 13),
        _filterBar(),
        const SizedBox(height: 12),
        _sortBar(),
        const SizedBox(height: 15),
        if (filteredJobs.isEmpty)
          _emptyEvents()
        else
          ...filteredJobs.map((job) {
            final eventWorkers = workers
                .where((worker) => worker.jobId == job.id)
                .toList();

            return _eventCard(
              job,
              eventWorkers,
            );
          }),
      ],
    );
  }

  // ============================================================
  // PAYMENT OVERVIEW
  // ============================================================

  Widget _summary({
    required double totalDue,
    required double totalPaid,
    required double outstanding,
  }) {
    final progress = totalDue <= 0
        ? 0.0
        : (totalPaid / totalDue)
        .clamp(0.0, 1.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF25344B),
            Color(0xFF19263B),
            Color(0xFF152338),
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: coralBright,
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                'PAYMENT OVERVIEW',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const Text(
            'Your workforce payment summary',
            style: TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _amountBox(
                  'Total Paid',
                  totalPaid,
                  teal,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _amountBox(
                  'To Be Paid',
                  outstanding,
                  amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Progress',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: teal,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: navy,
              valueColor:
              const AlwaysStoppedAnimation<Color>(
                teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT AMOUNT BOX
  // ============================================================

  Widget _amountBox(
      String title,
      double amount,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(amount),
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WORKER PAYMENT STATUS
  // ============================================================

  Widget _workerCounts({
    required int total,
    required int paid,
    required int partial,
    required int unpaid,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.groups_outlined,
                color: coralBright,
                size: 19,
              ),
              SizedBox(width: 9),
              Text(
                'WORKER PAYMENT STATUS',
                style: TextStyle(
                  color: white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              _countBox(
                'Present',
                total,
                white,
                Icons.groups_outlined,
              ),
              const SizedBox(width: 7),
              _countBox(
                'Paid',
                paid,
                teal,
                Icons.check_circle_outline,
              ),
              const SizedBox(width: 7),
              _countBox(
                'Partial',
                partial,
                amber,
                Icons.timelapse_outlined,
              ),
              const SizedBox(width: 7),
              _countBox(
                'Unpaid',
                unpaid,
                red,
                Icons.pending_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countBox(
      String title,
      int value,
      Color color,
      IconData icon,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 2,
        ),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 17,
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
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

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      cursorColor: coral,
      style: const TextStyle(
        color: white,
        fontSize: 14,
      ),
      onChanged: (value) {
        setState(() {
          _search = value.toLowerCase().trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search event or location...',
        hintStyle: const TextStyle(
          color: muted,
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: coralBright,
        ),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: muted,
          ),
          onPressed: () {
            _searchController.clear();
            setState(() {
              _search = '';
            });
          },
        ),
        filled: true,
        fillColor: panel,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: coral,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _filterBar() {
    const filters = [
      'All',
      'Active',
      'Completed',
      'Cancelled',
    ];

    return SizedBox(
      height: 41,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final value = filters[index];
          final selected = _filter == value;

          return ChoiceChip(
            label: Text(value),
            selected: selected,
            showCheckmark: false,
            backgroundColor: panel,
            selectedColor: coral,
            side: BorderSide(
              color: selected ? coral : border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            labelStyle: TextStyle(
              color: selected ? white : muted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            onSelected: (_) {
              setState(() {
                _filter = value;
              });
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // SORT
  // ============================================================

  Widget _sortBar() {
    return Row(
      children: [
        const Icon(
          Icons.sort_rounded,
          color: coralBright,
          size: 19,
        ),
        const SizedBox(width: 9),
        const Text(
          'Sort events',
          style: TextStyle(
            color: muted,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        DropdownButton<String>(
          value: _sort,
          dropdownColor: panel,
          underline: const SizedBox(),
          iconEnabledColor: coralBright,
          style: const TextStyle(
            color: white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          items: const [
            DropdownMenuItem(
              value: 'Newest',
              child: Text('Newest first'),
            ),
            DropdownMenuItem(
              value: 'Oldest',
              child: Text('Oldest first'),
            ),
            DropdownMenuItem(
              value: 'Name',
              child: Text('Event name'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _sort = value;
            });
          },
        ),
      ],
    );
  }

  List<JobModel> _filteredJobs(List<JobModel> jobs) {
    final result = jobs.where((job) {
      final matchesSearch = _search.isEmpty ||
          job.title.toLowerCase().contains(_search) ||
          job.location.toLowerCase().contains(_search);

      final matchesFilter = _filter == 'All' ||
          job.status.toLowerCase() ==
              _filter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();

    result.sort((a, b) {
      if (_sort == 'Name') {
        return a.title.compareTo(b.title);
      }

      final aDate = _parseDate(a.date);
      final bDate = _parseDate(b.date);

      return _sort == 'Oldest'
          ? aDate.compareTo(bDate)
          : bDate.compareTo(aDate);
    });

    return result;
  }

  // ============================================================
  // EVENT PAYMENT CARD
  // ============================================================

  Widget _eventCard(
      JobModel job,
      List<_WorkerPaymentInfo> workers,
      ) {
    final due = workers.fold<double>(
      0,
          (sum, worker) => sum + worker.amountDue,
    );

    final paid = workers.fold<double>(
      0,
          (sum, worker) => sum + worker.amountPaid,
    );

    final remaining = workers.fold<double>(
      0,
          (sum, worker) => sum + worker.remaining,
    );

    final progress = due <= 0
        ? 0.0
        : (paid / due)
        .clamp(0.0, 1.0)
        .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openDetails(job),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.event_available_outlined,
                      color: coralBright,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _eventDetail(
                          Icons.calendar_today_outlined,
                          job.date,
                        ),
                        const SizedBox(height: 7),
                        _eventDetail(
                          Icons.location_on_outlined,
                          job.location,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: muted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${_money(job.paymentPerWorker)} per worker',
                  style: const TextStyle(
                    color: teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 17),
              const Divider(
                color: border,
                height: 1,
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
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: teal,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: navy,
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(
                    teal,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _amountBox(
                      'Total Due',
                      due,
                      white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _amountBox(
                      'Paid',
                      paid,
                      teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _amountBox(
                      'To Pay',
                      remaining,
                      amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openDetails(job),
                  icon: const Icon(
                    Icons.payments_outlined,
                    size: 19,
                  ),
                  label: const Text(
                    'Manage Event Payments',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: coral,
                    foregroundColor: white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventDetail(
      IconData icon,
      String value,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: coralBright,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.trim().isEmpty
                ? 'Not provided'
                : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openDetails(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventPaymentDetailsPage(
          job: job,
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _money(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  DateTime _parseDate(String value) {
    final iso = DateTime.tryParse(value);

    if (iso != null) return iso;

    final match = RegExp(
      r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$',
    ).firstMatch(value.trim());

    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      final date = DateTime(year, month, day);

      if (date.year == year &&
          date.month == month &&
          date.day == day) {
        return date;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _loading() {
    return const Center(
      child: CircularProgressIndicator(
        color: coral,
      ),
    );
  }

  Widget _message(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: muted,
        ),
      ),
    );
  }

  Widget _error(String title, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: red,
              size: 43,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: red,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyEvents() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: coralBright,
            size: 37,
          ),
          SizedBox(height: 14),
          Text(
            'No matching events',
            style: TextStyle(
              color: white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Try changing your search or filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CALCULATED WORKER PAYMENT DATA
// ============================================================

class _WorkerPaymentInfo {
  final String jobId;
  final double amountDue;
  final double amountPaid;
  final double remaining;

  const _WorkerPaymentInfo({
    required this.jobId,
    required this.amountDue,
    required this.amountPaid,
    required this.remaining,
  });

  bool get isPaid =>
      amountDue > 0 && remaining <= 0.001;

  bool get isPartial =>
      amountPaid > 0 && remaining > 0.001;

  bool get isUnpaid => amountPaid <= 0;
}
