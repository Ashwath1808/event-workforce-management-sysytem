import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'post_new_job_page.dart';
import 'manage_jobs_page.dart';
import 'applications_page.dart';
import 'organizer_attendance_page.dart';
import 'organizer_payments_page.dart';
import 'organizer_profile_page.dart';
import 'job_details_page.dart';
import 'job_model.dart';
import 'job_service.dart';
import 'payment_model.dart';
import 'payment_service.dart';

// ============================================================
// CREWSYNC ORGANIZER - CORAL & SLATE THEME
// ============================================================

class _OC {
  static const coral = Color(0xFFF06449);
  static const coralLight = Color(0xFF50372F);
  static const coralSoft = Color(0xFF332B32);
  static const coralDark = Color(0xFFD94C34);
  static const slate = Color(0xFFE2E8F0);
  static const dark = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const background = Color(0xFF0B1220);
  static const border = Color(0xFF344156);
  static const white = Color(0xFF19263B);
  static const green = Color(0xFF35D1AC);
}

// ============================================================
// DATE AND MONEY HELPERS
// ============================================================

class _OrganizerHelper {
  static DateTime? parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;

    final numeric = RegExp(
      r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$',
    ).firstMatch(value);

    if (numeric != null) {
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      final year = int.parse(numeric.group(3)!);
      final result = DateTime(year, month, day);

      if (result.day == day &&
          result.month == month &&
          result.year == year) {
        return result;
      }
    }

    final named = RegExp(
      r'^(\d{1,2})[\s-]+([a-zA-Z]+)[\s,-]+(\d{4})$',
    ).firstMatch(value);

    if (named != null) {
      const months = <String, int>{
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

      final day = int.parse(named.group(1)!);
      final month = months[named.group(2)!.toLowerCase()];
      final year = int.parse(named.group(3)!);

      if (month == null) return null;

      final result = DateTime(year, month, day);

      if (result.day == day &&
          result.month == month &&
          result.year == year) {
        return result;
      }
    }

    return null;
  }

  static bool isUpcoming(JobModel job) {
    final status = job.status.trim().toLowerCase();

    if (status == 'completed' ||
        status == 'cancelled' ||
        status == 'closed') {
      return false;
    }

    final date = parseDate(job.date);
    if (date == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    return !eventDate.isBefore(today);
  }

  static List<JobModel> upcomingJobs(List<JobModel> jobs) {
    return jobs.where(isUpcoming).toList()
      ..sort(
            (a, b) => parseDate(a.date)!.compareTo(parseDate(b.date)!),
      );
  }

  static String money(double amount) {
    final number = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    final parts = number.split('.');
    final digits = parts.first;
    final negative = digits.startsWith('-');
    final raw = negative ? digits.substring(1) : digits;

    if (raw.length <= 3) return number;

    final lastThree = raw.substring(raw.length - 3);
    var remaining = raw.substring(0, raw.length - 3);
    final groups = <String>[];

    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }

    if (remaining.isNotEmpty) groups.insert(0, remaining);

    final formatted = '${groups.join(',')},$lastThree';
    final decimal = parts.length > 1 ? '.${parts[1]}' : '';

    return '${negative ? '-' : ''}$formatted$decimal';
  }

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'O';
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String firstName(String name) {
    final value = name.trim();
    return value.isEmpty ? 'Organizer' : value.split(' ').first;
  }

  static DateTime appliedAt(Map<String, dynamic> data) {
    final value = data['appliedAt'];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String timeAgo(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '';

    final difference = DateTime.now().difference(date);

    if (difference.isNegative || difference.inMinutes < 1) {
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
}

// ============================================================
// REUSABLE ORGANIZER UI
// ============================================================

class _OrganizerUI {
  static BoxDecoration cardDecoration({
    Color color = _OC.white,
    double radius = 18,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _OC.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  static Widget sectionTitle(
      String title, {
        String? action,
        VoidCallback? onPressed,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _OC.dark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: _OC.coral,
            ),
            child: Text(
              action,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  static Widget emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: _OC.coralSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: _OC.coral,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _OC.dark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _OC.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _OC.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(buttonText),
            ),
          ],
        ],
      ),
    );
  }

  static Widget eventCard(
      JobModel job, {
        required VoidCallback onTap,
        bool showWorkers = false,
      }) {
    final status = job.status.trim();
    final displayStatus = status.isEmpty
        ? 'Upcoming'
        : '${status[0].toUpperCase()}${status.substring(1)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _OC.coral,
                        Color(0xFFFF967C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _OC.dark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: _OC.muted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${job.date} • ${job.startTime}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _OC.muted,
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
                            Icons.location_on_outlined,
                            size: 13,
                            color: _OC.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _OC.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showWorkers) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${job.workersNeeded} workers needed',
                          style: const TextStyle(
                            color: _OC.coral,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF183E3B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        displayStatus,
                        style: const TextStyle(
                          color: _OC.green,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _OC.slate,
                      size: 22,
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
}

// ============================================================
// ORGANIZER HOME PAGE
// ============================================================

class OrganizerHomePage extends StatefulWidget {
  final UserModel user;

  const OrganizerHomePage({
    super.key,
    required this.user,
  });

  @override
  State<OrganizerHomePage> createState() =>
      _OrganizerHomePageState();
}

class _OrganizerHomePageState extends State<OrganizerHomePage> {
  int _selectedIndex = 0;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _open(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) {
      if (mounted) {
        setState(() => _selectedIndex = 0);
      }
    });
  }

  void _openPostJobPage() => _open(PostNewJobPage());

  void _openManageJobsPage() =>
      _open(const ManageJobsPage());

  void _openApplicationsPage() =>
      _open(const ApplicationsPage());

  void _openOrganizerAttendancePage() =>
      _open(const OrganizerAttendancePage());

  void _openOrganizerPaymentsPage() =>
      _open(const OrganizerPaymentsPage());

  void _openOrganizerProfilePage() =>
      _open(OrganizerProfilePage(user: widget.user));

  void _openNotifications() =>
      _open(const _OrganizerNotificationsPage());

  void _openJobDetails(JobModel job) =>
      _open(JobDetailsPage(job: job));

  void _openAllUpcomingEvents() =>
      _open(const _OrganizerUpcomingEventsPage());

  Future<void> _logout() async {
    await AuthService().logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(role: 'organizer'),
      ),
          (_) => false,
    );
  }

  void _showMessage(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _OC.slate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: _OC.background,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: _OC.background,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 26,
        ),
        surfaceTintColor: _OC.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 70,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Crew',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'Sync',
                    style: TextStyle(color: _OC.coral),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'ORGANIZER WORKSPACE',
              style: TextStyle(
                color: _OC.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          _notificationBell(),
          const SizedBox(width: 8),
        ],
      ),
      body: uid == null
          ? const Center(
        child: Text('Please log in again.'),
      )
          : StreamBuilder<List<JobModel>>(
        stream: JobService().getOrganizerJobs(uid),
        builder: (context, jobSnapshot) {
          if (jobSnapshot.hasError) {
            return _errorMessage(
              'Unable to load events',
              jobSnapshot.error,
            );
          }

          if (!jobSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: _OC.coral,
              ),
            );
          }

          final upcoming =
          _OrganizerHelper.upcomingJobs(jobSnapshot.data!);

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('applications')
                .where('organizerId', isEqualTo: uid)
                .snapshots(),
            builder: (context, appSnapshot) {
              if (appSnapshot.hasError) {
                return _errorMessage(
                  'Unable to load workers',
                  appSnapshot.error,
                );
              }

              if (!appSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _OC.coral,
                  ),
                );
              }

              final accepted = appSnapshot.data!.docs.where(
                    (doc) =>
                (doc.data()['status'] ?? '')
                    .toString()
                    .toLowerCase() ==
                    'accepted',
              );

              final workerIds = accepted
                  .map(
                    (doc) =>
                    (doc.data()['workerId'] ?? '')
                        .toString(),
              )
                  .where((id) => id.isNotEmpty)
                  .toSet();

              return StreamBuilder<List<PaymentModel>>(
                stream: PaymentService()
                    .organizerPayments(uid),
                builder: (context, paymentSnapshot) {
                  if (paymentSnapshot.hasError) {
                    return _errorMessage(
                      'Unable to load payments',
                      paymentSnapshot.error,
                    );
                  }

                  if (!paymentSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _OC.coral,
                      ),
                    );
                  }

                  final totalSpent =
                  paymentSnapshot.data!.fold<double>(
                    0.0,
                        (sum, payment) =>
                    sum + payment.amountPaid,
                  );

                  return _dashboardContent(
                    upcoming: upcoming,
                    upcomingCount: upcoming.length,
                    totalWorkers: workerIds.length,
                    totalSpent: totalSpent,
                    applicationCount: appSnapshot.data!.docs.length,
                    acceptedCount: accepted.length,
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: _OC.background,
          indicatorColor: _OC.coralSoft,
          labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected)
                  ? _OC.coral
                  : _OC.muted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _OC.coral
                  : _OC.muted,
              size: 24,
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: _OC.background,
          surfaceTintColor: _OC.background,
          elevation: 3,
          height: 72,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);

            switch (index) {
              case 0:
                break;
              case 1:
                _openManageJobsPage();
                break;
              case 2:
                _openApplicationsPage();
                break;
              case 3:
                _openOrganizerProfilePage();
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
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Events',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Workers',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // DASHBOARD CONTENT
  // ==========================================================

  Widget _dashboardContent({
    required List<JobModel> upcoming,
    required int upcomingCount,
    required int totalWorkers,
    required double totalSpent,
    required int applicationCount,
    required int acceptedCount,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - progress)),
          child: child,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.circle, color: _OC.green, size: 9),
                const SizedBox(width: 8),
                const Text('ORGANIZER COMMAND CENTER',
                    style: TextStyle(color: _OC.coral, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const Spacer(),
                Text(_todayLabel(), style: const TextStyle(
                    color: _OC.muted, fontSize: 11)),
              ]),
              const SizedBox(height: 12),
              Text('Everything under control.',
                  style: const TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -0.8)),
              const SizedBox(height: 5),
              Text('Welcome back, ${_OrganizerHelper.firstName(widget.user.name)}.\nYour events and crew, all in one place.',
                  style: const TextStyle(color: _OC.muted, fontSize: 12,
                      height: 1.5)),
              const SizedBox(height: 24),
              _commandCenterCard(upcomingCount, totalWorkers,
                  applicationCount, acceptedCount),
              const SizedBox(height: 20),
              _commandSectionTitle('Performance overview'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _commandMetric(Icons.event_available_outlined,
                    'UPCOMING EVENTS', '$upcomingCount', _OC.coral)),
                const SizedBox(width: 11),
                Expanded(child: _commandMetric(Icons.groups_rounded,
                    'HIRED WORKERS', '$totalWorkers', _OC.green)),
              ]),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: _commandMetric(Icons.pending_actions_rounded,
                    'APPLICATIONS', '$applicationCount', const Color(0xFFB5A5FF))),
                const SizedBox(width: 11),
                Expanded(child: _commandMetric(Icons.account_balance_wallet_outlined,
                    'TOTAL PAID', '₹${_OrganizerHelper.money(totalSpent)}',
                    const Color(0xFFFFB77D))),
              ]),
              const SizedBox(height: 24),
              _commandSectionTitle('Quick operations'),
              const SizedBox(height: 12),
              _commandActions(),
              const SizedBox(height: 24),
              _commandSectionTitle('Live operations',
                  action: 'View all', onTap: _openAllUpcomingEvents),
              const SizedBox(height: 12),
              if (upcoming.isEmpty)
                _commandEmpty()
              else
                ...upcoming.take(4).map((job) => _commandEvent(job)),
              const SizedBox(height: 14),
              _commandFooter(),
            ],
          ),
        ),
      ),
    );
  }

  String _todayLabel() {
    final d = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
      'Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _commandSectionTitle(String label,
      {String? action, VoidCallback? onTap}) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
    if (action != null) TextButton(onPressed: onTap,
        child: Text(action, style: const TextStyle(color: _OC.coral,
            fontWeight: FontWeight.w700))),
  ]);

  Widget _commandCenterCard(int events, int workers, int applications,
      int accepted) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF25354C), Color(0xFF162237)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF46516A)),
        boxShadow: [BoxShadow(color: _OC.coral.withOpacity(0.09),
            blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EVENT OPERATIONS', style: TextStyle(
                      color: _OC.muted, fontSize: 10, fontWeight: FontWeight.w800,
                      letterSpacing: 1.7)),
                  const SizedBox(height: 9),
                  Text('$events Upcoming ${events == 1 ? 'Event' : 'Events'}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Plan confidently. Lead your crew.',
                      style: TextStyle(color: _OC.muted, fontSize: 12)),
                ])),
            Container(width: 55, height: 55,
                decoration: BoxDecoration(color: _OC.coral,
                    borderRadius: BorderRadius.circular(17)),
                child: const Icon(Icons.hub_rounded,
                    color: Colors.white, size: 30)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _commandMiniMetric('HIRED CREW', '$workers')),
            const SizedBox(width: 10),
            Expanded(child: _commandMiniMetric('ACCEPTED APPS', '$accepted')),
            const SizedBox(width: 10),
            Expanded(child: _commandMiniMetric('ALL APPS', '$applications')),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: _openPostJobPage,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 21),
                label: const Text('Launch New Event',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _OC.coral, foregroundColor: Colors.white,
                    elevation: 0, shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13))),
              )),
        ],
      ),
    );
  }

  Widget _commandMiniMetric(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFF344258),
        borderRadius: BorderRadius.circular(13)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _OC.muted, fontSize: 8,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(color: Colors.white,
          fontSize: 20, fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _commandMetric(IconData icon, String label, String value,
      Color accent) => Container(
    height: 118,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF19263B),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFF344156))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: accent, size: 22),
        const Spacer(),
        Icon(Icons.north_east_rounded, color: accent.withOpacity(0.7),
            size: 16),
      ]),
      const Spacer(),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(color: Colors.white,
              fontSize: 23, fontWeight: FontWeight.w900))),
      const SizedBox(height: 5),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _OC.muted, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ]),
  );

  Widget _commandActions() {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.add_circle_outline_rounded, 'Post Job', _openPostJobPage),
      (Icons.work_outline_rounded, 'Manage Jobs', _openManageJobsPage),
      (Icons.assignment_outlined, 'Applications', _openApplicationsPage),
      (Icons.fact_check_outlined, 'Attendance', _openOrganizerAttendancePage),
      (Icons.account_balance_wallet_outlined, 'Payments', _openOrganizerPaymentsPage),
      (Icons.notifications_none_rounded, 'Alerts', _openNotifications),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 20) / 3;
      return Wrap(spacing: 10, runSpacing: 10,
        children: actions.map((item) => SizedBox(width: width,
          child: Material(color: const Color(0xFF19263B),
            borderRadius: BorderRadius.circular(17),
            child: InkWell(onTap: item.$3,
              borderRadius: BorderRadius.circular(17),
              child: Container(height: 102,
                decoration: BoxDecoration(border: Border.all(
                    color: const Color(0xFF344156)),
                    borderRadius: BorderRadius.circular(17)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 43, height: 43,
                          decoration: BoxDecoration(color: _OC.coralSoft,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(item.$1, color: _OC.coral, size: 23)),
                      const SizedBox(height: 10),
                      Text(item.$2, maxLines: 1,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
              ),
            ),
          ),
        )).toList(),
      );
    });
  }

  Widget _commandEvent(JobModel job) {
    final date = _OrganizerHelper.parseDate(job.date);
    final day = date == null ? '--' : '${date.day}';
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG',
      'SEP','OCT','NOV','DEC'];
    final month = date == null ? 'DATE' : months[date.month - 1];
    final status = job.status.trim().isEmpty ? 'Upcoming' : job.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(color: const Color(0xFF19263B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF344156))),
      child: Material(color: Colors.transparent,
        child: InkWell(onTap: () => _openJobDetails(job),
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: const EdgeInsets.all(13),
            child: Row(children: [
              Container(width: 58, height: 64,
                  decoration: BoxDecoration(color: _OC.coralSoft,
                      borderRadius: BorderRadius.circular(13)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(day, style: const TextStyle(color: _OC.coral,
                            fontSize: 24, fontWeight: FontWeight.w900)),
                        Text(month, style: const TextStyle(color: _OC.coral,
                            fontSize: 10, fontWeight: FontWeight.w800)),
                      ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('${job.location} • ${job.startTime}', maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _OC.muted, fontSize: 11)),
                    const SizedBox(height: 7),
                    Text('${job.workersNeeded} workers needed • $status',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _OC.coral,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: _OC.muted),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _commandEmpty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
    decoration: BoxDecoration(color: const Color(0xFF19263B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF344156))),
    child: Column(children: [
      const Icon(Icons.event_busy_outlined, color: _OC.coral, size: 38),
      const SizedBox(height: 12),
      const Text('No upcoming events yet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text('Create your first event and start building your crew.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _OC.muted, fontSize: 12)),
      const SizedBox(height: 12),
      TextButton(onPressed: _openPostJobPage,
          child: const Text('Post a Job', style: TextStyle(color: _OC.coral))),
    ]),
  );

  Widget _commandFooter() => Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text('CREWSYNC  •  ORGANIZER PRO',
        style: TextStyle(color: _OC.muted.withOpacity(0.7),
            fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
  ));

  // ==========================================================
  // WELCOME CARD
  // ==========================================================

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _OC.coral,
            Color(0xFFFF9277),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _OC.coral.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_OrganizerHelper.firstName(widget.user.name)} 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your events, workers\nand payments in one place.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: Colors.white,
              size: 39,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATISTICS
  // ==========================================================

  Widget _buildStatistics({
    required int upcomingCount,
    required int totalWorkers,
    required double totalSpent,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.event_available_outlined,
                value: '$upcomingCount',
                label: 'Upcoming Events',
                iconColor: _OC.coral,
                iconBackground: _OC.coralSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.groups_rounded,
                value: '$totalWorkers',
                label: 'Hired Workers',
                iconColor: const Color(0xFF2563EB),
                iconBackground: const Color(0xFFEAF2FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _statCard(
          icon: Icons.account_balance_wallet_outlined,
          value: '₹${_OrganizerHelper.money(totalSpent)}',
          label: 'Total Spent',
          iconColor: _OC.green,
          iconBackground: const Color(0xFFE5F8EF),
          wide: true,
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
    required Color iconBackground,
    bool wide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _OrganizerUI.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: wide ? 48 : 40,
            height: wide ? 48 : 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: wide ? 25 : 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: _OC.dark,
                      fontSize: wide ? 22 : 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    color: _OC.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // QUICK ACTIONS
  // ==========================================================

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickCard(
                Icons.add_circle_outline_rounded,
                'Post New Job',
                _OC.coral,
                _OC.coralSoft,
                _openPostJobPage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickCard(
                Icons.work_outline_rounded,
                'Manage Jobs',
                _OC.slate,
                const Color(0xFFE9EEF4),
                _openManageJobsPage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickCard(
                Icons.assignment_outlined,
                'Applications',
                const Color(0xFF8B5CF6),
                const Color(0xFFF1EAFE),
                _openApplicationsPage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickCard(
                Icons.fact_check_outlined,
                'Attendance',
                const Color(0xFF2563EB),
                const Color(0xFFEAF2FF),
                _openOrganizerAttendancePage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickCard(
                Icons.account_balance_wallet_outlined,
                'Payments',
                _OC.green,
                const Color(0xFFE5F8EF),
                _openOrganizerPaymentsPage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickCard(
                Icons.bar_chart_outlined,
                'Reports',
                const Color(0xFFD97706),
                const Color(0xFFFFF2DC),
                    () => _showMessage('Reports'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickCard(
      IconData icon,
      String title,
      Color iconColor,
      Color iconBackground,
      VoidCallback onTap,
      ) {
    return Container(
      decoration: _OrganizerUI.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 105,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _OC.slate,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // NOTIFICATION BELL
  // ==========================================================

  Widget _notificationBell() {
    final uid = _uid;
    if (uid == null) {
      return IconButton(
        onPressed: _openNotifications,
        icon: const Icon(Icons.notifications_none_rounded, color: _OC.slate),
      );
    }
    return _OrganizerNotificationFeed(
      organizerId: uid,
      builder: (context, alerts, readIds) {
        final unread = alerts.where((n) => !readIds.contains(n.id)).length;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: Badge(
            backgroundColor: _OC.coral,
            textColor: Colors.white,
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none_rounded,
                size: 27, color: _OC.slate),
          ),
        );
      },
    );
  }

  // ==========================================================
  // NAVIGATION DRAWER
  // ==========================================================

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _OC.background,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                22,
                25,
                22,
                25,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _OC.coral,
                    Color(0xFFFF967D),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Text(
                      _OrganizerHelper.initials(widget.user.name),
                      style: const TextStyle(
                        color: _OC.coral,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.user.email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ORGANIZER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
                  _drawerItem(
                    Icons.home_outlined,
                    'Dashboard',
                        () {},
                    selected: true,
                  ),
                  _drawerItem(
                    Icons.add_circle_outline,
                    'Post New Job',
                    _openPostJobPage,
                  ),
                  _drawerItem(
                    Icons.work_outline,
                    'Manage Jobs',
                    _openManageJobsPage,
                  ),
                  _drawerItem(
                    Icons.assignment_outlined,
                    'Applications',
                    _openApplicationsPage,
                  ),
                  _drawerItem(
                    Icons.fact_check_outlined,
                    'Attendance',
                    _openOrganizerAttendancePage,
                  ),
                  _drawerItem(
                    Icons.account_balance_wallet_outlined,
                    'Payments',
                    _openOrganizerPaymentsPage,
                  ),
                  _drawerItem(
                    Icons.notifications_none,
                    'Notifications',
                    _openNotifications,
                  ),
                  _drawerItem(
                    Icons.bar_chart_outlined,
                    'Reports',
                        () => _showMessage('Reports'),
                  ),
                  _drawerItem(
                    Icons.person_outline,
                    'Profile',
                        () => _openOrganizerProfilePage(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _logout,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
      IconData icon,
      String title,
      VoidCallback action, {
        bool selected = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: selected ? _OC.coralSoft : null,
        leading: Icon(
          icon,
          color: selected ? _OC.coral : _OC.slate,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? _OC.coral : _OC.slate,
            fontSize: 13,
            fontWeight:
            selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          action();
        },
      ),
    );
  }

  Widget _errorMessage(String message, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '$message\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _OC.slate),
        ),
      ),
    );
  }
}

// ============================================================
// UPCOMING EVENTS PAGE
// ============================================================

class _OrganizerUpcomingEventsPage extends StatelessWidget {
  const _OrganizerUpcomingEventsPage();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _OC.background,
      appBar: AppBar(
        backgroundColor: _OC.background,
        foregroundColor: _OC.slate,
        surfaceTintColor: _OC.background,
        elevation: 0,
        title: const Text(
          'Upcoming Events',
          style: TextStyle(
            color: _OC.dark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: uid == null
          ? const Center(
        child: Text('Please log in again.'),
      )
          : StreamBuilder<List<JobModel>>(
        stream: JobService().getOrganizerJobs(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load events:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: _OC.coral,
              ),
            );
          }

          final upcoming =
          _OrganizerHelper.upcomingJobs(snapshot.data!);

          if (upcoming.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _OrganizerUI.emptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No Upcoming Events',
                  subtitle:
                  'Your future posted jobs will appear here.',
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  18,
                ),
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: _OC.coralSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: _OC.coral,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${upcoming.length} Upcoming Events',
                            style: const TextStyle(
                              color: _OC.dark,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Your scheduled events at a glance',
                            style: TextStyle(
                              color: _OC.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    24,
                  ),
                  itemCount: upcoming.length,
                  itemBuilder: (context, index) {
                    final job = upcoming[index];

                    return _OrganizerUI.eventCard(
                      job,
                      showWorkers: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                JobDetailsPage(job: job),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// ORGANIZER NOTIFICATION FEED (SPARK PLAN - IN APP ONLY)
// ============================================================

class _OrganizerAlert {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final IconData icon;
  final String destination;
  final String actionLabel;

  const _OrganizerAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.icon,
    required this.destination,
    required this.actionLabel,
  });
}

class _OrganizerNotificationFeed extends StatelessWidget {
  final String organizerId;
  final Widget Function(BuildContext, List<_OrganizerAlert>, Set<String>) builder;

  const _OrganizerNotificationFeed({
    required this.organizerId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('applications')
          .where('organizerId', isEqualTo: organizerId).snapshots(),
      builder: (context, apps) {
        if (apps.hasError) return _error('applications', apps.error);
        if (!apps.hasData) return _loading();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('jobs')
              .where('organizerId', isEqualTo: organizerId).snapshots(),
          builder: (context, jobs) {
            if (jobs.hasError) return _error('events', jobs.error);
            if (!jobs.hasData) return _loading();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collection('attendance')
                  .where('organizerId', isEqualTo: organizerId).snapshots(),
              builder: (context, attendance) {
                if (attendance.hasError) return _error('attendance', attendance.error);
                if (!attendance.hasData) return _loading();
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db.collection('payments')
                      .where('organizerId', isEqualTo: organizerId).snapshots(),
                  builder: (context, payments) {
                    if (payments.hasError) return _error('payments', payments.error);
                    if (!payments.hasData) return _loading();
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: db.collection('notificationStates')
                          .doc(organizerId).collection('items').snapshots(),
                      builder: (context, states) {
                        if (states.hasError) return _error('read states', states.error);
                        if (!states.hasData) return _loading();
                        final readIds = states.data!.docs
                            .where((doc) => doc.data()['isRead'] == true)
                            .map((doc) => doc.id).toSet();
                        final alerts = _buildAlerts(
                          apps.data!.docs, jobs.data!.docs,
                          attendance.data!.docs, payments.data!.docs,
                        );
                        return builder(context, alerts, readIds);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static Widget _loading() => const Center(
    child: CircularProgressIndicator(color: _OC.coral),
  );

  static Widget _error(String area, Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Unable to load $area: $error',
          style: const TextStyle(color: _OC.slate)),
    ),
  );

  static List<_OrganizerAlert> _buildAlerts(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> applications,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> attendance,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
      ) {
    final alerts = <_OrganizerAlert>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final attendanceById = {for (final doc in attendance) doc.id: doc.data()};
    final paymentById = {for (final doc in payments) doc.id: doc.data()};
    final acceptedByJob = <String, List<Map<String, dynamic>>>{};

    for (final doc in applications) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final jobId = (data['jobId'] ?? '').toString();
      if (status == 'accepted') {
        acceptedByJob.putIfAbsent(jobId, () => []).add(data);
      }
      // Application notifications remain in history even after acceptance/rejection.
      alerts.add(_OrganizerAlert(
        id: 'app_${doc.id}',
        title: 'New Job Application',
        message: '${data['workerName'] ?? 'A worker'} applied for "${data['jobTitle'] ?? 'your event'}". Status: $status.',
        createdAt: _OrganizerHelper.appliedAt(data),
        icon: Icons.person_add_alt_1_rounded,
        destination: 'applications',
        actionLabel: 'Review Application',
      ));
    }

    for (final doc in jobs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled') continue;
      final isOpen = status != 'completed' && status != 'closed';
      final date = _OrganizerHelper.parseDate((data['date'] ?? '').toString());
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      final title = (data['title'] ?? 'Your event').toString();
      final daysUntil = day.difference(today).inDays;
      if (isOpen && (daysUntil == 0 || daysUntil == 1)) {
        alerts.add(_OrganizerAlert(
          id: 'event_${doc.id}_${date.year}${date.month}${date.day}',
          title: daysUntil == 0 ? 'Event Today' : 'Upcoming Event Tomorrow',
          message: '"$title" is scheduled ${daysUntil == 0 ? 'today' : 'tomorrow'} at ${data['startTime'] ?? 'the scheduled time'}.',
          createdAt: day.subtract(const Duration(days: 1)),
          icon: Icons.event_available_outlined,
          destination: 'events',
          actionLabel: 'View Events',
        ));
      }
      // Attendance is actionable from event day onward.
      if (isOpen && daysUntil <= 0) {
        var unmarked = 0;
        for (final worker in acceptedByJob[doc.id] ?? <Map<String, dynamic>>[]) {
          final workerId = (worker['workerId'] ?? '').toString();
          if (workerId.isEmpty) continue;
          final record = attendanceById['${doc.id}_$workerId'];
          if (record == null || (record['status'] ?? 'not_marked') == 'not_marked') {
            unmarked++;
          }
        }
        if (unmarked > 0) {
          alerts.add(_OrganizerAlert(
            id: 'attend_${doc.id}',
            title: 'Attendance Pending',
            message: '$unmarked worker${unmarked == 1 ? '' : 's'} still need attendance marked for "$title".',
            createdAt: day,
            icon: Icons.fact_check_outlined,
            destination: 'attendance',
            actionLabel: 'Mark Attendance',
          ));
        }
      }
      // A worker is payable only when accepted AND marked present.
      var unpaidCount = 0;
      var outstanding = 0.0;
      final due = (data['paymentPerWorker'] as num?)?.toDouble() ?? 0;
      if (due > 0) {
        for (final worker in acceptedByJob[doc.id] ?? <Map<String, dynamic>>[]) {
          final workerId = (worker['workerId'] ?? '').toString();
          if (workerId.isEmpty) continue;
          final key = '${doc.id}_$workerId';
          if (attendanceById[key]?['status'] != 'present') continue;
          final paid = (paymentById[key]?['amountPaid'] as num?)?.toDouble() ?? 0;
          final remaining = due - paid;
          if (remaining > 0.001) {
            unpaidCount++;
            outstanding += remaining;
          }
        }
      }
      if (unpaidCount > 0) {
        alerts.add(_OrganizerAlert(
          id: 'pay_${doc.id}',
          title: 'Pending Worker Payments',
          message: '$unpaidCount worker${unpaidCount == 1 ? '' : 's'} have ₹${_OrganizerHelper.money(outstanding)} outstanding for "$title".',
          createdAt: day,
          icon: Icons.account_balance_wallet_outlined,
          destination: 'payments',
          actionLabel: 'View Payments',
        ));
      }
    }
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return alerts;
  }
}

// ============================================================
// ORGANIZER NOTIFICATIONS PAGE
// ============================================================

class _OrganizerNotificationsPage extends StatefulWidget {
  const _OrganizerNotificationsPage();

  @override
  State<_OrganizerNotificationsPage> createState() =>
      _OrganizerNotificationsPageState();
}

class _OrganizerNotificationsPageState extends State<_OrganizerNotificationsPage> {
  final Set<String> _busy = {};

  Future<void> _markRead(String id) async {
    if (_busy.contains(id)) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy.add(id));
    try {
      await FirebaseFirestore.instance.collection('notificationStates')
          .doc(uid).collection('items').doc(id).set({'isRead': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to mark as read: $e'),
          backgroundColor: _OC.coral,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _openAlert(_OrganizerAlert alert) async {
    await _markRead(alert.id);
    if (!mounted) return;
    late final Widget page;
    switch (alert.destination) {
      case 'attendance':
        page = const OrganizerAttendancePage();
        break;
      case 'payments':
        page = const OrganizerPaymentsPage();
        break;
      case 'events':
        page = const ManageJobsPage();
        break;
      default:
        page = const ApplicationsPage();
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _OC.background,
      appBar: AppBar(
        backgroundColor: _OC.background,
        foregroundColor: _OC.slate,
        surfaceTintColor: _OC.background,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(
          color: _OC.dark, fontSize: 19, fontWeight: FontWeight.w800,
        )),
      ),
      body: uid == null
          ? const Center(child: Text('Please log in again.'))
          : _OrganizerNotificationFeed(
        organizerId: uid,
        builder: (context, alerts, readIds) {
          final visibleAlerts = alerts
              .where((alert) => !readIds.contains(alert.id) && !_busy.contains(alert.id))
              .toList();
          if (visibleAlerts.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: _OrganizerUI.emptyState(
                icon: Icons.notifications_none_rounded,
                title: 'All caught up',
                subtitle: 'New applications and actionable reminders will appear here.',
              ),
            ));
          }
          final unread = visibleAlerts.length;
          return Column(children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _OC.coralSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.notifications_active_outlined,
                    color: _OC.coral, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$unread Unread Notifications',
                        style: const TextStyle(color: _OC.dark,
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    const Text('Applications, events, attendance and payments',
                        style: TextStyle(color: _OC.muted, fontSize: 11)),
                  ],
                )),
              ]),
            ),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: visibleAlerts.length,
              itemBuilder: (context, index) {
                final alert = visibleAlerts[index];
                final isRead = readIds.contains(alert.id);
                final busy = _busy.contains(alert.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: _OrganizerUI.cardDecoration(
                    color: isRead ? _OC.white : _OC.coralSoft,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: _OC.background,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(alert.icon, color: _OC.coral, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(alert.title, style: const TextStyle(
                                color: _OC.dark, fontSize: 14,
                                fontWeight: FontWeight.w800,
                              )),
                              const SizedBox(height: 5),
                              Text(_OrganizerHelper.timeAgo(alert.createdAt),
                                  style: const TextStyle(color: _OC.muted, fontSize: 11)),
                            ],
                          )),
                          if (!isRead) const CircleAvatar(
                              radius: 5, backgroundColor: _OC.coral),
                        ]),
                        const SizedBox(height: 13),
                        Text(alert.message, style: const TextStyle(
                          color: _OC.slate, fontSize: 13, height: 1.5,
                        )),
                        const SizedBox(height: 15),
                        SizedBox(width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: busy ? null : () => _openAlert(alert),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: Text(alert.actionLabel),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _OC.coral,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (!isRead) Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: busy ? null : () => _markRead(alert.id),
                            icon: const Icon(Icons.done_rounded, size: 17),
                            label: const Text('Mark as read'),
                            style: TextButton.styleFrom(foregroundColor: _OC.coral),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )),
          ]);
        },
      ),
    );
  }
}

