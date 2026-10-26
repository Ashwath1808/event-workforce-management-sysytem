
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'job_model.dart';
import 'job_service.dart';
import 'job_details_page.dart';

class WorkerMyEventsPage extends StatefulWidget {
  final bool upcomingOnly;

  const WorkerMyEventsPage({
    super.key,
    this.upcomingOnly = false,
  });

  @override
  State<WorkerMyEventsPage> createState() =>
      _WorkerMyEventsPageState();
}

class _WorkerMyEventsPageState extends State<WorkerMyEventsPage> {
  static const Color navy = Color(0xFF101828);
  static const Color emerald = Color(0xFF00C9A7);
  static const Color deepGreen = Color(0xFF008F78);
  static const Color background = Color(0xFFF4F7F9);
  static const Color ink = Color(0xFF182230);
  static const Color muted = Color(0xFF667085);
  static const Color border = Color(0xFFE5EAF0);

  final ApplicationService _applicationService =
  ApplicationService();
  final JobService _jobService = JobService();

  String _selectedFilter = 'All';

  DateTime? _parseDate(String rawValue) {
    final raw = rawValue.trim();
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
      final result = DateTime(year, month, day);

      if (result.day == day &&
          result.month == month &&
          result.year == year) {
        return result;
      }
      return null;
    }

    final named = RegExp(
      r'^(\d{1,2})[\s-]+([a-zA-Z]+)[\s,-]+(\d{4})$',
    ).firstMatch(raw);

    if (named != null) {
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

  bool _isUpcoming(JobModel job) {
    final status = job.status.trim().toLowerCase();

    if (status == 'cancelled' || status == 'completed') {
      return false;
    }

    final date = _parseDate(job.date);
    if (date == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);

    return !eventDay.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          _topHeader(),
          Expanded(
            child: user == null
                ? _emptyState(
              Icons.lock_outline_rounded,
              'Login Required',
              'Please login again.',
            )
                : StreamBuilder<List<ApplicationModel>>(
              stream: _applicationService
                  .getWorkerApplications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _errorView(
                    '${snapshot.error}',
                  );
                }

                if (!snapshot.hasData) {
                  return _loadingView();
                }

                final applications = snapshot.data!;

                if (widget.upcomingOnly) {
                  final accepted = applications.where((app) {
                    return app.status
                        .trim()
                        .toLowerCase() ==
                        'accepted';
                  }).toList();

                  return _upcomingContent(accepted);
                }

                return _allEventsContent(applications);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NAVY HEADER
  // ============================================================

  Widget _topHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 10,
        20,
        23,
      ),
      decoration: const BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.upcomingOnly
                      ? 'Upcoming Events'
                      : 'My Events',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF203B3D),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  widget.upcomingOnly
                      ? Icons.event_available_outlined
                      : Icons.work_outline_rounded,
                  color: emerald,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 43,
                  decoration: BoxDecoration(
                    color: emerald,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.upcomingOnly
                            ? 'YOUR NEXT OPPORTUNITIES'
                            : 'YOUR EVENT WORKSPACE',
                        style: const TextStyle(
                          color: emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.upcomingOnly
                            ? 'Your accepted future events, all in one place.'
                            : 'Manage applications and stay on top of every event.',
                        style: const TextStyle(
                          color: Color(0xFFD0D5DD),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
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
  // ALL EVENTS MODE
  // ============================================================

  Widget _allEventsContent(
      List<ApplicationModel> applications,
      ) {
    final filtered = _filterApplications(applications);

    final pending = _countStatus(applications, 'pending');
    final accepted = _countStatus(applications, 'accepted');
    final completed = _countStatus(applications, 'completed');

    return Column(
      children: [
        _overviewPanel(
          total: applications.length,
          firstCount: pending,
          firstLabel: 'Pending',
          secondCount: accepted,
          secondLabel: 'Accepted',
          thirdCount: completed,
          thirdLabel: 'Completed',
        ),
        _sectionTitle(
          'Applications',
          '${filtered.length} records',
        ),
        _filterBar(),
        const SizedBox(height: 13),
        Expanded(
          child: filtered.isEmpty
              ? _emptyEventsView()
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              18,
              2,
              18,
              26,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final application = filtered[index];

              return FutureBuilder<JobModel?>(
                future: _jobService.getJob(
                  application.jobId,
                ),
                builder: (context, jobSnapshot) {
                  if (!jobSnapshot.hasData) {
                    return jobSnapshot.hasError
                        ? _missingJobCard(application)
                        : _loadingEventCard();
                  }

                  final job = jobSnapshot.data;
                  if (job == null) {
                    return _missingJobCard(application);
                  }

                  return _eventCard(job, application);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // UPCOMING MODE
  // ============================================================

  Widget _upcomingContent(
      List<ApplicationModel> accepted,
      ) {
    if (accepted.isEmpty) {
      return _emptyEventsView();
    }

    return FutureBuilder<List<JobModel?>>(
      future: Future.wait(
        accepted.map(
              (app) => _jobService.getJob(app.jobId),
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView('${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return _loadingView();
        }

        final upcoming =
        <({JobModel job, ApplicationModel app})>[];

        for (int i = 0; i < accepted.length; i++) {
          final job = snapshot.data![i];

          if (job == null || !_isUpcoming(job)) continue;

          upcoming.add((
          job: job,
          app: accepted[i],
          ));
        }

        upcoming.sort((a, b) {
          final dateA = _parseDate(a.job.date)!;
          final dateB = _parseDate(b.job.date)!;

          final result = dateA.compareTo(dateB);
          if (result != 0) return result;

          return a.job.startTime.compareTo(
            b.job.startTime,
          );
        });

        if (upcoming.isEmpty) {
          return _emptyEventsView();
        }

        return Column(
          children: [
            _upcomingBanner(upcoming.length),
            _sectionTitle(
              'Upcoming Schedule',
              '${upcoming.length} events',
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  18,
                  4,
                  18,
                  26,
                ),
                itemCount: upcoming.length,
                itemBuilder: (context, index) {
                  final event = upcoming[index];
                  return _eventCard(
                    event.job,
                    event.app,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // OVERVIEW PANEL
  // ============================================================

  Widget _overviewPanel({
    required int total,
    required int firstCount,
    required String firstLabel,
    required int secondCount,
    required String secondLabel,
    required int thirdCount,
    required String thirdLabel,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.045),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Application Overview',
                  style: TextStyle(
                    color: navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$total total',
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _metric(
                  firstCount,
                  firstLabel,
                  const Color(0xFFB7791F),
                  Icons.schedule_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  secondCount,
                  secondLabel,
                  deepGreen,
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  thirdCount,
                  thirdLabel,
                  navy,
                  Icons.task_alt_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
      int value,
      String label,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 7),
          Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF1C4440),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: emerald,
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Upcoming ${count == 1 ? 'Event' : 'Events'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Accepted events scheduled for today or later.',
                  style: TextStyle(
                    color: Color(0xFFB4C1CC),
                    fontSize: 11,
                    height: 1.4,
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
  // SECTION TITLE AND FILTERS
  // ============================================================

  Widget _sectionTitle(String title, String count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    const filters = [
      'All',
      'Pending',
      'Accepted',
      'Rejected',
      'Completed',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected ? navy : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected ? navy : border,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<ApplicationModel> _filterApplications(
      List<ApplicationModel> applications,
      ) {
    if (_selectedFilter == 'All') {
      return applications;
    }

    final selected = _selectedFilter.toLowerCase();

    return applications.where((app) {
      return app.status.trim().toLowerCase() == selected;
    }).toList();
  }

  int _countStatus(
      List<ApplicationModel> applications,
      String status,
      ) {
    return applications.where((app) {
      return app.status.trim().toLowerCase() == status;
    }).length;
  }

  // ============================================================
  // REDESIGNED EVENT CARD
  // ============================================================

  Widget _eventCard(
      JobModel job,
      ApplicationModel application,
      ) {
    final status = application.status.trim().toLowerCase();
    final accent = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JobDetailsPage(job: job),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  15,
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
                            color: const Color(0xFFE5F8F3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.work_outline_rounded,
                            color: deepGreen,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 11),
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
                                  color: ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: muted,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      job.location.isEmpty
                                          ? 'Location not provided'
                                          : job.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _applicationStatusChip(
                      application.status,
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _infoItem(
                              icon: Icons.calendar_today_outlined,
                              title: 'EVENT DATE',
                              value: job.date,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoItem(
                              icon: Icons.schedule_rounded,
                              title: 'EVENT TIME',
                              value: _eventTime(job),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F8F3),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.currency_rupee_rounded,
                            color: deepGreen,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PAYMENT PER WORKER',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_formatPayment(job.paymentPerWorker)}',
                                style: const TextStyle(
                                  color: navy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: deepGreen,
                          size: 21,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _applicationMessage(
                      application.status,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _eventTime(JobModel job) {
    final start = job.startTime.trim();
    final end = job.endTime.trim();

    if (start.isEmpty && end.isEmpty) {
      return 'Time not provided';
    }

    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }

    return start.isNotEmpty ? start : end;
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: deepGreen, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          value.trim().isEmpty ? 'Not provided' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS STYLING
  // ============================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
      case 'completed':
        return deepGreen;
      case 'rejected':
        return const Color(0xFFCC4545);
      default:
        return const Color(0xFFB7791F);
    }
  }

  Widget _applicationStatusChip(String status) {
    final value = status.trim().toLowerCase();
    final color = _statusColor(value);

    final icon = switch (value) {
      'accepted' => Icons.check_circle_outline,
      'rejected' => Icons.cancel_outlined,
      'completed' => Icons.task_alt_rounded,
      _ => Icons.schedule_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            _capitalize(
              value.isEmpty ? 'pending' : value,
            ),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _applicationMessage(String status) {
    final value = status.trim().toLowerCase();
    final color = _statusColor(value);

    final icon = switch (value) {
      'accepted' => Icons.check_circle_outline,
      'rejected' => Icons.cancel_outlined,
      'completed' => Icons.task_alt_rounded,
      _ => Icons.hourglass_top_rounded,
    };

    final message = switch (value) {
      'accepted' =>
      'You have been accepted for this event.',
      'rejected' =>
      'Your application was not selected for this event.',
      'completed' =>
      'This event has been completed.',
      _ =>
      'Your application is waiting for organizer approval.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING / MISSING / EMPTY / ERROR
  // ============================================================

  Widget _loadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: deepGreen,
      ),
    );
  }

  Widget _loadingEventCard() {
    return Container(
      height: 175,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: _loadingView(),
    );
  }

  Widget _missingJobCard(
      ApplicationModel application,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            application.jobTitle.isEmpty
                ? 'Event'
                : application.jobTitle,
            style: const TextStyle(
              color: navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          _applicationStatusChip(application.status),
          const SizedBox(height: 11),
          const Text(
            'Job details are currently unavailable.',
            style: TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyEventsView() {
    if (widget.upcomingOnly) {
      return _emptyState(
        Icons.event_available_outlined,
        'No Upcoming Events',
        'Your accepted future events will appear here.',
      );
    }

    if (_selectedFilter == 'All') {
      return _emptyState(
        Icons.event_note_outlined,
        'No Events Yet',
        'Jobs you apply for will appear here so you can track their status.',
      );
    }

    return _emptyState(
      Icons.filter_alt_off_outlined,
      'No $_selectedFilter Events',
      'You currently have no ${_selectedFilter.toLowerCase()} applications.',
    );
  }

  Widget _emptyState(
      IconData icon,
      String title,
      String description,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F5F0),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                color: deepGreen,
                size: 39,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String error) {
    return _emptyState(
      Icons.error_outline_rounded,
      'Unable to Load Events',
      error,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatPayment(double payment) {
    if (payment == payment.roundToDouble()) {
      return payment.toInt().toString();
    }
    return payment.toStringAsFixed(2);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
