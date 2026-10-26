import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';
import 'job_model.dart';
import 'job_service.dart';
import 'payment_model.dart';
import 'payment_service.dart';

import 'login_page.dart';
import 'search_jobs_page.dart';
import 'worker_profile_page.dart';
import 'worker_my_events_page.dart';
import 'worker_attendance_page.dart';
import 'worker_payments_page.dart';
import 'worker_notifications_page.dart';
import 'job_details_page.dart';

// ============================================================
// CREWSYNC — MIDNIGHT & EMERALD DESIGN SYSTEM
// ============================================================

class _CrewColors {
  static const midnight = Color(0xFF101828);
  static const navy = Color(0xFF1D2939);
  static const emerald = Color(0xFF00C9A7);
  static const deepEmerald = Color(0xFF009B82);
  static const mint = Color(0xFFE6FAF5);
  static const background = Color(0xFFF5F7FA);
  static const border = Color(0xFFE4E7EC);
  static const muted = Color(0xFF667085);
  static const white = Colors.white;
}

// ============================================================
// WORKER HOME PAGE
// ============================================================

class WorkerHomePage extends StatefulWidget {
  final UserModel user;

  const WorkerHomePage({
    super.key,
    required this.user,
  });

  @override
  State<WorkerHomePage> createState() =>
      _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  final ApplicationService _applicationService =
  ApplicationService();

  final AttendanceService _attendanceService =
  AttendanceService();

  final PaymentService _paymentService =
  PaymentService();

  final JobService _jobService = JobService();

  final Map<String, Future<JobModel?>> _jobFutures = {};

  int _selectedIndex = 0;

  Future<JobModel?> _getJob(String id) {
    return _jobFutures.putIfAbsent(
      id,
          () => _jobService.getJob(id),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openPage(
      Widget page, {
        int selectedIndex = 0,
      }) {
    setState(() => _selectedIndex = selectedIndex);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) {
      if (!mounted) return;

      setState(() {
        _selectedIndex = 0;
        _jobFutures.clear();
      });
    });
  }

  void _openSearchJobs() {
    _openPage(const SearchJobsPage());
  }

  void _openMyEvents() {
    _openPage(
      const WorkerMyEventsPage(),
      selectedIndex: 1,
    );
  }

  void _openUpcomingEvents() {
    _openPage(
      const WorkerMyEventsPage(upcomingOnly: true),
      selectedIndex: 1,
    );
  }

  void _openAttendance() {
    _openPage(const WorkerAttendancePage());
  }

  void _openPayments() {
    _openPage(
      const WorkerPaymentsPage(),
      selectedIndex: 2,
    );
  }

  void _openProfile() {
    _openPage(
      WorkerProfilePage(user: widget.user),
      selectedIndex: 3,
    );
  }

  void _openJobDetails(JobModel job) {
    _openPage(JobDetailsPage(job: job));
  }

  void _openNotifications() {
    _openPage(const WorkerNotificationsPage());
  }

  Future<void> _logout() async {
    await AuthService().logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(role: 'worker'),
      ),
          (_) => false,
    );
  }

  // ============================================================
  // DATE HELPERS — PRESERVED
  // ============================================================

  DateTime? _parseDate(String value) {
    final raw = value.trim();

    if (raw.isEmpty) return null;

    final iso = DateTime.tryParse(raw);

    if (iso != null) return iso;

    final numeric = RegExp(
      r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$',
    ).firstMatch(raw);

    if (numeric != null) {
      final d = int.parse(numeric.group(1)!);
      final m = int.parse(numeric.group(2)!);
      final y = int.parse(numeric.group(3)!);

      final date = DateTime(y, m, d);

      return date.year == y &&
          date.month == m &&
          date.day == d
          ? date
          : null;
    }

    const months = {
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
      final d = int.parse(named.group(1)!);
      final m = months[named.group(2)!.toLowerCase()];
      final y = int.parse(named.group(3)!);

      if (m == null) return null;

      final date = DateTime(y, m, d);

      return date.year == y &&
          date.month == m &&
          date.day == d
          ? date
          : null;
    }

    return null;
  }

  bool _isUpcoming(JobModel job) {
    final status = job.status.trim().toLowerCase();

    if (status == 'cancelled' || status == 'completed') {
      return false;
    }

    final date = _parseDate(job.date);

    if (date == null) return false;

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    return !DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(today);
  }

  String _money(double value) {
    return value == value.roundToDouble()
        ? '₹${value.toInt()}'
        : '₹${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // MAIN DASHBOARD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _CrewColors.emerald,
          primary: _CrewColors.deepEmerald,
        ),
        scaffoldBackgroundColor: _CrewColors.background,
      ),
      child: Scaffold(
        backgroundColor: _CrewColors.background,
        drawer: _buildDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Open navigation menu',
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          backgroundColor: _CrewColors.midnight,
          foregroundColor: Colors.white,
          surfaceTintColor: _CrewColors.midnight,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 70,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CrewSync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'WORKER WORKSPACE',
                style: TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            if (uid != null)
              _NotificationBell(
                uid: uid,
                onPressed: _openNotifications,
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: uid == null
            ? const Center(
          child: Text('Please login again.'),
        )
            : StreamBuilder<List<ApplicationModel>>(
          stream: _applicationService
              .getWorkerApplications(uid),
          builder: (context, appSnapshot) {
            if (appSnapshot.hasError) {
              return _errorView(
                '${appSnapshot.error}',
              );
            }

            if (!appSnapshot.hasData) {
              return _loadingView();
            }

            return StreamBuilder<List<AttendanceModel>>(
              stream: _attendanceService
                  .getWorkerAttendance(uid),
              builder: (context, attendanceSnapshot) {
                if (attendanceSnapshot.hasError) {
                  return _errorView(
                    '${attendanceSnapshot.error}',
                  );
                }

                if (!attendanceSnapshot.hasData) {
                  return _loadingView();
                }

                return StreamBuilder<List<PaymentModel>>(
                  stream: _paymentService
                      .workerPayments(uid),
                  builder: (context, paymentSnapshot) {
                    if (paymentSnapshot.hasError) {
                      return _errorView(
                        '${paymentSnapshot.error}',
                      );
                    }

                    if (!paymentSnapshot.hasData) {
                      return _loadingView();
                    }

                    final applications =
                    appSnapshot.data!;

                    final accepted = applications
                        .where(
                          (a) =>
                      a.status
                          .trim()
                          .toLowerCase() ==
                          'accepted',
                    )
                        .toList();

                    return FutureBuilder<List<JobModel?>>(
                      future: Future.wait(
                        accepted.map(
                              (a) => _getJob(a.jobId),
                        ),
                      ),
                      builder: (context, jobSnapshot) {
                        if (jobSnapshot.hasError) {
                          return _errorView(
                            '${jobSnapshot.error}',
                          );
                        }

                        if (!jobSnapshot.hasData) {
                          return _loadingView();
                        }

                        final jobs =
                        <String, JobModel>{};

                        for (final job
                        in jobSnapshot.data!) {
                          if (job != null) {
                            jobs[job.id] = job;
                          }
                        }

                        final upcoming =
                        accepted.where((a) {
                          final job = jobs[a.jobId];

                          return job != null &&
                              _isUpcoming(job);
                        }).toList();

                        upcoming.sort((a, b) {
                          final da = _parseDate(
                            jobs[a.jobId]!.date,
                          )!;

                          final db = _parseDate(
                            jobs[b.jobId]!.date,
                          )!;

                          final result =
                          da.compareTo(db);

                          return result != 0
                              ? result
                              : jobs[a.jobId]!
                              .startTime
                              .compareTo(
                            jobs[b.jobId]!
                                .startTime,
                          );
                        });

                        final pendingCount =
                            applications.where(
                                  (a) =>
                              a.status
                                  .trim()
                                  .toLowerCase() ==
                                  'pending',
                            ).length;

                        final presentJobIds =
                        attendanceSnapshot.data!
                            .where(
                              (a) =>
                          a.status
                              .trim()
                              .toLowerCase() ==
                              'present',
                        )
                            .map((a) => a.jobId)
                            .toSet();

                        final paymentByJob =
                        <String, PaymentModel>{};

                        for (final payment
                        in paymentSnapshot.data!) {
                          paymentByJob[payment.jobId] =
                              payment;
                        }

                        double received = 0;

                        for (final a in accepted) {
                          final job = jobs[a.jobId];

                          if (job == null ||
                              !presentJobIds
                                  .contains(a.jobId) ||
                              job.status
                                  .trim()
                                  .toLowerCase() ==
                                  'cancelled') {
                            continue;
                          }

                          received +=
                              paymentByJob[a.jobId]
                                  ?.amountPaid ??
                                  0;
                        }

                        return _buildDashboard(
                          uid: uid,
                          upcoming: upcoming,
                          jobs: jobs,
                          pendingCount: pendingCount,
                          received: received,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: _CrewColors.mint,
        labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? _CrewColors.deepEmerald
                : _CrewColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _CrewColors.deepEmerald
                : _CrewColors.muted,
            size: 24,
          ),
        ),
      ),
      child: NavigationBar(
        height: 75,
        elevation: 0,
        backgroundColor: Colors.white,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              setState(() => _selectedIndex = 0);
              break;
            case 1:
              _openMyEvents();
              break;
            case 2:
              _openPayments();
              break;
            case 3:
              _openProfile();
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.account_balance_wallet_outlined,
            ),
            selectedIcon: Icon(
              Icons.account_balance_wallet_rounded,
            ),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD CONTENT
  // ============================================================

  Widget _buildDashboard({
    required String uid,
    required List<ApplicationModel> upcoming,
    required Map<String, JobModel> jobs,
    required int pendingCount,
    required double received,
  }) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          18,
          20,
          18,
          35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WELCOME HERO
            _welcomeCard(),

            const SizedBox(height: 23),

            // STATISTICS
            _sectionHeading(
              'Your Overview',
              'Your activity at a glance',
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.event_available_outlined,
                    value: '${upcoming.length}',
                    label: 'Upcoming\nEvents',
                    onTap: _openUpcomingEvents,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    icon: Icons.hourglass_top_rounded,
                    value: '$pendingCount',
                    label: 'Pending\nApplications',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    icon: Icons.payments_outlined,
                    value: _money(received),
                    label: 'Total\nReceived',
                    onTap: _openPayments,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // PROFILE COMPLETION
            _profileCompletionCard(uid),

            const SizedBox(height: 4),

            // UPCOMING EVENTS
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Upcoming Events',
                    style: TextStyle(
                      color: _CrewColors.midnight,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openUpcomingEvents,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (upcoming.isEmpty)
              _emptyUpcomingCard()
            else
              ...upcoming.take(3).map((application) {
                final job = jobs[application.jobId]!;

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _upcomingEventCard(job),
                );
              }),

            const SizedBox(height: 25),

            _sectionHeading(
              'Quick Access',
              'Everything you need in one place',
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _shortcut(
                    Icons.search_rounded,
                    'Search Jobs',
                    _openSearchJobs,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shortcut(
                    Icons.calendar_month_outlined,
                    'My Events',
                    _openMyEvents,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shortcut(
                    Icons.fact_check_outlined,
                    'Attendance',
                    _openAttendance,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 11),

            Row(
              children: [
                Expanded(
                  child: _shortcut(
                    Icons.account_balance_wallet_outlined,
                    'Payments',
                    _openPayments,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shortcut(
                    Icons.notifications_none_rounded,
                    'Notifications',
                    _openNotifications,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _shortcut(
                    Icons.person_outline_rounded,
                    'My Profile',
                    _openProfile,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _bottomBanner(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _welcomeCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _CrewColors.midnight,
            Color(0xFF1B3442),
            Color(0xFF12655C),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _CrewColors.midnight.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            Positioned(
              top: -55,
              right: -55,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: _CrewColors.emerald.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 25,
              bottom: -65,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                    width: 2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 29,
                        backgroundColor: _CrewColors.mint,
                        child: Text(
                          _initials(widget.user.name),
                          style: const TextStyle(
                            color: _CrewColors.midnight,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WELCOME BACK',
                              style: TextStyle(
                                color: _CrewColors.emerald,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Hello, ${_firstName(widget.user.name)} 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Your next opportunity\nstarts here.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),

                  const SizedBox(height: 9),

                  const Text(
                    'Discover events, connect with organizers and grow your experience.',
                    style: TextStyle(
                      color: Color(0xFFD0D5DD),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 21),

                  SizedBox(
                    width: double.infinity,
                    height: 49,
                    child: FilledButton.icon(
                      onPressed: _openSearchJobs,
                      style: FilledButton.styleFrom(
                        backgroundColor: _CrewColors.emerald,
                        foregroundColor: _CrewColors.midnight,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        'Explore Available Jobs',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADING
  // ============================================================

  Widget _sectionHeading(
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _CrewColors.midnight,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _CrewColors.muted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATISTICS CARDS
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          decoration: _cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 16,
            ),
            child: Column(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: _CrewColors.mint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: _CrewColors.deepEmerald,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: _CrewColors.midnight,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _CrewColors.muted,
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE COMPLETION
  // ============================================================

  Widget _profileCompletionCard(String uid) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() ?? {};

        // Same fields used in the original dashboard.
        final fields = [
          'name',
          'phone',
          'age',
          'gender',
          'city',
          'skills',
          'experienceLevel',
          'education',
          'languages',
          'bio',
          'upiId',
        ];

        final completed = fields.where((field) {
          final value = data[field];

          if (value is List) {
            return value.isNotEmpty;
          }

          return value != null &&
              value.toString().trim().isNotEmpty;
        }).length;

        final progress = completed / fields.length;

        if (progress >= 1) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openProfile,
              borderRadius: BorderRadius.circular(21),
              child: Ink(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  color: _CrewColors.mint,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: const Color(0xFFB8EDE1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: _CrewColors.deepEmerald,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Complete Your Profile',
                            style: TextStyle(
                              color: _CrewColors.midnight,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: _CrewColors.deepEmerald,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        color: _CrewColors.deepEmerald,
                        backgroundColor:
                        const Color(0xFFCAEDE4),
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add your missing details to complete your profile.',
                            style: TextStyle(
                              color: _CrewColors.muted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: _CrewColors.deepEmerald,
                          size: 19,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // UPCOMING EVENT CARD
  // ============================================================

  Widget _upcomingEventCard(JobModel job) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openJobDetails(job),
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: _cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 82,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _CrewColors.midnight,
                      Color(0xFF17685D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: _CrewColors.emerald,
                  size: 34,
                ),
              ),
              const SizedBox(width: 13),
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
                        color: _CrewColors.midnight,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: _CrewColors.muted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            job.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _CrewColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: _CrewColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${job.date}  •  ${job.startTime}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _CrewColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Earn ${_money(job.paymentPerWorker)}',
                      style: const TextStyle(
                        color: _CrewColors.deepEmerald,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: _CrewColors.deepEmerald,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY UPCOMING EVENTS
  // ============================================================

  Widget _emptyUpcomingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: _CrewColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 36,
              color: _CrewColors.deepEmerald,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No upcoming events yet',
            style: TextStyle(
              color: _CrewColors.midnight,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Your accepted future events will appear here. Explore jobs to find your next opportunity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _CrewColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: _openSearchJobs,
            style: FilledButton.styleFrom(
              backgroundColor: _CrewColors.deepEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.search_rounded,
              size: 19,
            ),
            label: const Text('Explore Jobs'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACCESS TILES
  // ============================================================

  Widget _shortcut(
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          height: 112,
          decoration: _cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _CrewColors.mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: _CrewColors.deepEmerald,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CrewColors.midnight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM INFORMATION BANNER
  // ============================================================

  Widget _bottomBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _CrewColors.midnight,
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: _CrewColors.emerald,
            size: 25,
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep growing with CrewSync',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Stay active, explore new events and build your professional experience.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DECORATION
  // ============================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(
        color: _CrewColors.border,
      ),
      boxShadow: [
        BoxShadow(
          color: _CrewColors.midnight.withOpacity(0.045),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ============================================================
  // LOADING / ERROR
  // ============================================================

  Widget _loadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: _CrewColors.deepEmerald,
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC3545),
              size: 46,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load dashboard',
              style: TextStyle(
                color: _CrewColors.midnight,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _CrewColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION DRAWER
  // ============================================================

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _CrewColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                23,
                28,
                23,
                28,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _CrewColors.midnight,
                    Color(0xFF174B4C),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: _CrewColors.mint,
                    child: Text(
                      _initials(widget.user.name),
                      style: const TextStyle(
                        color: _CrewColors.midnight,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                      _CrewColors.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CREWSYNC WORKER',
                      style: TextStyle(
                        color: _CrewColors.emerald,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                children: [
                  _drawerTile(
                    Icons.home_outlined,
                    'Home',
                        () {},
                    selected: true,
                  ),
                  _drawerTile(
                    Icons.search_rounded,
                    'Search Jobs',
                    _openSearchJobs,
                  ),
                  _drawerTile(
                    Icons.event_outlined,
                    'My Events',
                    _openMyEvents,
                  ),
                  _drawerTile(
                    Icons.fact_check_outlined,
                    'Attendance',
                    _openAttendance,
                  ),
                  _drawerTile(
                    Icons.account_balance_wallet_outlined,
                    'Payments',
                    _openPayments,
                  ),
                  _drawerTile(
                    Icons.notifications_none_rounded,
                    'Notifications',
                    _openNotifications,
                  ),
                  _drawerTile(
                    Icons.person_outline_rounded,
                    'My Profile',
                    _openProfile,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                tileColor: const Color(0xFFFFEEEE),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFC83F4A),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFC83F4A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
      IconData icon,
      String title,
      VoidCallback action, {
        bool selected = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: ListTile(
        selected: selected,
        selectedTileColor: _CrewColors.mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        leading: Icon(
          icon,
          color: selected
              ? _CrewColors.deepEmerald
              : _CrewColors.muted,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected
                ? _CrewColors.deepEmerald
                : _CrewColors.midnight,
            fontWeight: selected
                ? FontWeight.w900
                : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          action();
        },
      ),
    );
  }

  // ============================================================
  // NAME HELPERS
  // ============================================================

  String _firstName(String name) {
    final trimmed = name.trim();

    return trimmed.isEmpty
        ? 'Worker'
        : trimmed.split(' ').first;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'W';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'
        .toUpperCase();
  }
}

// ============================================================
// WORKER NOTIFICATION DATA
// ============================================================

class _WorkerNotificationData {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? jobId;
  final DateTime createdAt;

  const _WorkerNotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.jobId,
  });
}

// ============================================================
// LIVE WORKER NOTIFICATION FEED
// FIRESTORE LOGIC PRESERVED
// ============================================================

class _WorkerNotificationFeed extends StatelessWidget {
  final String uid;

  final Widget Function(
      BuildContext context,
      List<_WorkerNotificationData> notifications,
      ) builder;

  const _WorkerNotificationFeed({
    required this.uid,
    required this.builder,
  });

  DateTime _timestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('jobs')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, jobsSnapshot) {
        if (jobsSnapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load job notifications: '
                  '${jobsSnapshot.error}',
            ),
          );
        }

        if (!jobsSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: _CrewColors.deepEmerald,
            ),
          );
        }

        return StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('applications')
              .where('workerId', isEqualTo: uid)
              .snapshots(),
          builder: (context, appSnapshot) {
            if (appSnapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load application notifications: '
                      '${appSnapshot.error}',
                ),
              );
            }

            if (!appSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _CrewColors.deepEmerald,
                ),
              );
            }

            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('notificationStates')
                  .doc(uid)
                  .collection('items')
                  .snapshots(),
              builder: (context, readSnapshot) {
                if (readSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load notification states: '
                          '${readSnapshot.error}',
                    ),
                  );
                }

                if (!readSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _CrewColors.deepEmerald,
                    ),
                  );
                }

                final readIds = readSnapshot.data!.docs
                    .where(
                      (doc) =>
                  doc.data()['isRead'] == true,
                )
                    .map((doc) => doc.id)
                    .toSet();

                final applications =
                    appSnapshot.data!.docs;

                final appliedJobIds = applications
                    .map(
                      (doc) =>
                      (doc.data()['jobId'] ?? '')
                          .toString(),
                )
                    .toSet();

                final notifications =
                <_WorkerNotificationData>[];

                // ACCEPTED / REJECTED APPLICATIONS

                for (final doc in applications) {
                  final data = doc.data();

                  final status = (data['status'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  if (status != 'accepted' &&
                      status != 'rejected') {
                    continue;
                  }

                  final jobTitle =
                  (data['jobTitle'] ?? 'your job')
                      .toString();

                  final jobId =
                  (data['jobId'] ?? '').toString();

                  final id =
                      'job_result_${doc.id}_$status';

                  notifications.add(
                    _WorkerNotificationData(
                      id: id,
                      type: status,
                      title: status == 'accepted'
                          ? 'Application Accepted!'
                          : 'Application Rejected',
                      message: status == 'accepted'
                          ? 'Congratulations! Your application for "$jobTitle" has been accepted by the organizer.'
                          : 'Your application for "$jobTitle" was not selected.',
                      jobId: jobId,
                      createdAt: _timestamp(
                        data['updatedAt'] ??
                            data['appliedAt'],
                      ),
                    ),
                  );
                }

                // NEW JOB NOTIFICATIONS

                for (final doc
                in jobsSnapshot.data!.docs) {
                  final data = doc.data();

                  final organizerId =
                  (data['organizerId'] ?? '')
                      .toString();

                  if (organizerId == uid) continue;

                  if (appliedJobIds.contains(doc.id)) {
                    continue;
                  }

                  final jobTitle =
                  (data['title'] ?? 'New Job')
                      .toString();

                  final location =
                  (data['location'] ?? 'Unknown')
                      .toString();

                  final payment =
                  (data['paymentPerWorker'] ?? 0)
                      .toString();

                  notifications.add(
                    _WorkerNotificationData(
                      id: 'job_${doc.id}',
                      type: 'new_job',
                      title: 'New Job: $jobTitle',
                      message:
                      '$jobTitle at $location\nPayment: ₹$payment',
                      jobId: doc.id,
                      createdAt: _timestamp(
                        data['createdAt'],
                      ),
                    ),
                  );
                }

                // UNREAD NOTIFICATIONS

                final freshNotifications = notifications
                    .where(
                      (notification) =>
                  !readIds.contains(
                    notification.id,
                  ),
                )
                    .toList();

                freshNotifications.sort(
                      (a, b) =>
                      b.createdAt.compareTo(a.createdAt),
                );

                return builder(
                  context,
                  freshNotifications,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ============================================================
// NOTIFICATION BELL
// ============================================================

class _NotificationBell extends StatelessWidget {
  final String uid;
  final VoidCallback onPressed;

  const _NotificationBell({
    required this.uid,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _WorkerNotificationFeed(
      uid: uid,
      builder: (context, notifications) {
        final unread = notifications.length;

        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor:
              Colors.white.withOpacity(0.09),
            ),
            icon: Badge(
              backgroundColor:
              _CrewColors.emerald,
              textColor:
              _CrewColors.midnight,
              isLabelVisible: unread > 0,
              label: Text(
                unread > 99 ? '99+' : '$unread',
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// WORKER NOTIFICATIONS PAGE
// ============================================================

class _WorkerNotificationsPage extends StatefulWidget {
  const _WorkerNotificationsPage();

  @override
  State<_WorkerNotificationsPage> createState() =>
      _WorkerNotificationsPageState();
}

class _WorkerNotificationsPageState
    extends State<_WorkerNotificationsPage> {
  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  final JobService _jobService = JobService();

  final Set<String> _busy = {};

  // ============================================================
  // MARK NOTIFICATION AS READ
  // ============================================================

  Future<void> _markRead(
      String uid,
      String notificationId,
      ) async {
    await _db
        .collection('notificationStates')
        .doc(uid)
        .collection('items')
        .doc(notificationId)
        .set({
      'isRead': true,
    });
  }

  Future<void> _readWithFeedback(
      String uid,
      String notificationId,
      ) async {
    if (_busy.contains(notificationId)) return;

    setState(() {
      _busy.add(notificationId);
    });

    try {
      await _markRead(uid, notificationId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to mark as read: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(notificationId);
        });
      }
    }
  }

  // ============================================================
  // OPEN JOB FROM NOTIFICATION
  // ============================================================

  Future<void> _viewJob(
      String uid,
      _WorkerNotificationData notification,
      ) async {
    if (_busy.contains(notification.id)) return;

    setState(() {
      _busy.add(notification.id);
    });

    try {
      final jobId = notification.jobId;

      if (jobId == null || jobId.isEmpty) {
        throw Exception('Job ID is missing.');
      }

      final job = await _jobService.getJob(jobId);

      if (job == null) {
        throw Exception(
          'This job is no longer available.',
        );
      }

      if (notification.type == 'new_job') {
        if (job.status.trim().toLowerCase() !=
            'active' ||
            job.acceptedWorkers >=
                job.workersNeeded) {
          throw Exception(
            'This job is closed or fully filled.',
          );
        }
      }

      await _markRead(uid, notification.id);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(
            job: job,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open job: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(notification.id);
        });
      }
    }
  }

  // ============================================================
  // TIME FORMAT
  // ============================================================

  String _timeAgo(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return '';
    }

    final difference =
    DateTime.now().difference(date);

    if (difference.isNegative ||
        difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // ============================================================
  // NOTIFICATION SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _CrewColors.emerald,
          primary: _CrewColors.deepEmerald,
        ),
      ),
      child: Scaffold(
        backgroundColor: _CrewColors.background,
        appBar: AppBar(
          backgroundColor: _CrewColors.midnight,
          foregroundColor: Colors.white,
          surfaceTintColor: _CrewColors.midnight,
          elevation: 0,
          title: const Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        body: uid == null
            ? const Center(
          child: Text('Please log in again.'),
        )
            : _WorkerNotificationFeed(
          uid: uid,
          builder: (context, notifications) {
            if (notifications.isEmpty) {
              return _emptyNotifications();
            }

            return ListView.builder(
              physics:
              const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification =
                notifications[index];

                return _notificationCard(
                  uid,
                  notification,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY NOTIFICATIONS
  // ============================================================

  Widget _emptyNotifications() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 95,
              height: 95,
              decoration: const BoxDecoration(
                color: _CrewColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _CrewColors.deepEmerald,
                size: 47,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'You are all caught up!',
              style: TextStyle(
                color: _CrewColors.midnight,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No new notifications right now. Updates about jobs and applications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _CrewColors.muted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget _notificationCard(
      String uid,
      _WorkerNotificationData notification,
      ) {
    final busy = _busy.contains(notification.id);

    final accepted =
        notification.type == 'accepted';

    final rejected =
        notification.type == 'rejected';

    final isJob =
        notification.type == 'new_job';

    final Color accent = accepted
        ? _CrewColors.deepEmerald
        : rejected
        ? const Color(0xFFD64550)
        : _CrewColors.deepEmerald;

    final IconData icon = accepted
        ? Icons.check_circle_outline_rounded
        : rejected
        ? Icons.cancel_outlined
        : Icons.work_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: _CrewColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: _CrewColors.midnight.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        color: _CrewColors.midnight,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: const TextStyle(
                        color: _CrewColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const CircleAvatar(
                radius: 4,
                backgroundColor:
                _CrewColors.emerald,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            notification.message,
            style: const TextStyle(
              color: _CrewColors.navy,
              fontSize: 13,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 12),

          if (accepted)
            _statusLabel(
              'You have been selected!',
              _CrewColors.deepEmerald,
            ),

          if (rejected)
            _statusLabel(
              'Application not selected',
              const Color(0xFFD64550),
            ),

          if (isJob)
            _statusLabel(
              'Job available',
              _CrewColors.deepEmerald,
            ),

          const SizedBox(height: 17),

          Wrap(
            spacing: 10,
            runSpacing: 9,
            children: [
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => _viewJob(
                  uid,
                  notification,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                  _CrewColors.deepEmerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                ),
                label: Text(
                  isJob
                      ? 'View Job / Apply'
                      : 'View Job',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _readWithFeedback(
                  uid,
                  notification.id,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                  _CrewColors.midnight,
                  side: const BorderSide(
                    color: _CrewColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Mark as read',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusLabel(
      String text,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
