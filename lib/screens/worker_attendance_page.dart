
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';
import 'job_details_page.dart';
import 'job_model.dart';
import 'job_service.dart';

class WorkerAttendancePage extends StatefulWidget {
  const WorkerAttendancePage({super.key});

  @override
  State<WorkerAttendancePage> createState() =>
      _WorkerAttendancePageState();
}

class _WorkerAttendancePageState
    extends State<WorkerAttendancePage> {
  static const Color _navy = Color(0xFF101828);
  static const Color _navyLight = Color(0xFF233449);
  static const Color _green = Color(0xFF00C9A7);
  static const Color _darkGreen = Color(0xFF008F78);
  static const Color _bg = Color(0xFFF3F6F8);
  static const Color _text = Color(0xFF182230);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE5EAF0);

  final ApplicationService _applicationService =
  ApplicationService();

  final AttendanceService _attendanceService =
  AttendanceService();

  final JobService _jobService = JobService();

  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: user == null
            ? Column(
          children: [
            _topBar(),
            Expanded(
              child: _emptyState(
                Icons.lock_outline_rounded,
                'Login Required',
                'Please login again.',
              ),
            ),
          ],
        )
            : StreamBuilder<List<ApplicationModel>>(
          stream: _applicationService
              .getWorkerApplications(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting &&
                !snapshot.hasData) {
              return _screenState(
                const CircularProgressIndicator(
                  color: _darkGreen,
                ),
              );
            }

            if (snapshot.hasError) {
              return _screenState(_errorView());
            }

            final accepted = (snapshot.data ?? [])
                .where(
                  (application) =>
              application.status
                  .trim()
                  .toLowerCase() ==
                  'accepted',
            )
                .toList();

            if (accepted.isEmpty) {
              return _dashboard(
                const [],
                noAcceptedEvents: true,
              );
            }

            return FutureBuilder<
                List<_WorkerAttendanceItem>>(
              future: _loadAttendanceItems(
                accepted,
                user.uid,
              ),
              builder: (context, result) {
                if (result.connectionState ==
                    ConnectionState.waiting &&
                    !result.hasData) {
                  return _screenState(
                    const CircularProgressIndicator(
                      color: _darkGreen,
                    ),
                  );
                }

                if (result.hasError) {
                  return _screenState(_errorView());
                }

                final items = result.data ?? [];

                return _dashboard(
                  items,
                  noAcceptedEvents: items.isEmpty,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  // FULL SCREEN LAYOUT
  // ==========================================================

  Widget _dashboard(
      List<_WorkerAttendanceItem> items, {
        bool noAcceptedEvents = false,
      }) {
    final visible = _filterItems(items);

    return Column(
      children: [
        _topBar(),
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _dashboardHeader(items),
              ),
              SliverToBoxAdapter(
                child: _sectionHeading(items.length),
              ),
              SliverToBoxAdapter(
                child: _filterTabs(),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 14),
              ),
              if (noAcceptedEvents)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(
                    Icons.event_note_rounded,
                    'No Accepted Events Yet',
                    'Your accepted events will appear here. Pending and rejected applications are not shown.',
                  ),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(
                    Icons.filter_alt_off_outlined,
                    'No $_selectedFilter Attendance',
                    _filterEmptyMessage(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    30,
                  ),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      return _timelineEntry(
                        visible[index],
                        index == visible.length - 1,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _screenState(Widget content) {
    return Column(
      children: [
        _topBar(),
        Expanded(child: Center(child: content)),
      ],
    );
  }

  // ==========================================================
  // TOP BAR
  // ==========================================================

  Widget _topBar() {
    return Container(
      color: _navy,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 10,
        bottom: 17,
        left: 12,
        right: 19,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Your work. Your record.',
                  style: TextStyle(
                    color: Color(0xFF9EAFBE),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF233C42),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DARK DASHBOARD
  // ==========================================================

  Widget _dashboardHeader(
      List<_WorkerAttendanceItem> items,
      ) {
    final present = items
        .where((e) => _effectiveStatus(e) == 'present')
        .length;

    final absent = items
        .where((e) => _effectiveStatus(e) == 'absent')
        .length;

    final pending = items
        .where((e) => _effectiveStatus(e) == 'not_marked')
        .length;

    final marked = present + absent;
    final rate = marked == 0 ? 0.0 : present / marked;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            23,
            18,
            23,
            29,
          ),
          decoration: const BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(29),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ATTENDANCE OVERVIEW',
                style: TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 112,
                          height: 112,
                          child: CircularProgressIndicator(
                            value: rate,
                            strokeWidth: 9,
                            strokeCap: StrokeCap.round,
                            backgroundColor: _navyLight,
                            valueColor:
                            const AlwaysStoppedAnimation(
                              _green,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(rate * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'PRESENT',
                              style: TextStyle(
                                color: Color(0xFF9EAFBE),
                                fontSize: 9,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 23),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your attendance\nat a glance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          marked == 0
                              ? 'No attendance marked yet'
                              : '$present of $marked marked events attended',
                          style: const TextStyle(
                            color: Color(0xFFB4C1CC),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -13),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 19,
                horizontal: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _dashboardMetric(
                      items.length,
                      'Total Events',
                      _navy,
                      Icons.calendar_today_outlined,
                    ),
                  ),
                  Container(
                    height: 42,
                    width: 1,
                    color: _border,
                  ),
                  Expanded(
                    child: _dashboardMetric(
                      present,
                      'Present',
                      _darkGreen,
                      Icons.check_circle_outline,
                    ),
                  ),
                  Container(
                    height: 42,
                    width: 1,
                    color: _border,
                  ),
                  Expanded(
                    child: _dashboardMetric(
                      pending,
                      'Not Marked',
                      const Color(0xFFB7791F),
                      Icons.hourglass_empty_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashboardMetric(
      int count,
      String label,
      Color color,
      IconData icon,
      ) {
    return Column(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(height: 7),
        Text(
          count.toString().padLeft(2, '0'),
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // RECORDS HEADING AND FILTERS
  // ==========================================================

  Widget _sectionHeading(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        7,
        20,
        15,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Event Timeline',
              style: TextStyle(
                color: _text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F5F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$total events',
              style: const TextStyle(
                color: _darkGreen,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTabs() {
    const filters = [
      'All',
      'Not Marked',
      'Present',
      'Absent',
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
                color: selected ? _navy : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected ? _navy : _border,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : _muted,
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

  // ==========================================================
  // EVENT ENTRY - LEFT TIMELINE LINE REMOVED
  // ==========================================================

  Widget _timelineEntry(
      _WorkerAttendanceItem item,
      bool last,
      ) {
    final status = _effectiveStatus(item);
    final accent = _statusColor(status);

    // Only the event card remains.
    // No vertical timeline line or circular dot on the left.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _timelineCard(
        item,
        status,
        accent,
      ),
    );
  }

  // ==========================================================
  // EVENT CARD
  // ==========================================================

  Widget _timelineCard(
      _WorkerAttendanceItem item,
      String status,
      Color accent,
      ) {
    final job = item.job;
    final attendance = item.attendance;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailsPage(job: job),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  15,
                  15,
                  15,
                  13,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            job.title.trim().isEmpty
                                ? 'Event'
                                : job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusPill(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: _muted,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            job.location.trim().isEmpty
                                ? 'Location not provided'
                                : job.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _miniInfo(
                              Icons.calendar_today_outlined,
                              'DATE',
                              job.date.trim().isEmpty
                                  ? 'Not provided'
                                  : job.date,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _miniInfo(
                              Icons.schedule_rounded,
                              'TIME',
                              _eventTime(job),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 17,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusMessage(status),
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                attendance?.markedAt == null
                                    ? 'Attendance not marked yet'
                                    : 'Marked: ${_formatDateTime(attendance!.markedAt!)}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    const Divider(height: 1, color: _border),
                    const SizedBox(height: 11),
                    const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EVENT DETAILS',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: _darkGreen,
                          size: 19,
                        ),
                      ],
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

  Widget _miniInfo(
      IconData icon,
      String label,
      String value,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: _muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);

    final label = switch (status) {
      'present' => 'Present',
      'absent' => 'Absent',
      'cancelled' => 'Cancelled',
      _ => 'Pending',
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 90),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return _darkGreen;
      case 'absent':
      case 'cancelled':
        return const Color(0xFFCC4545);
      default:
        return const Color(0xFFB7791F);
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'present':
        return 'Your attendance has been marked as Present.';
      case 'absent':
        return 'Your attendance has been marked as Absent.';
      case 'cancelled':
        return 'This event has been cancelled by the organizer.';
      default:
        return 'The organizer has not marked your attendance yet.';
    }
  }

  // ==========================================================
  // FIREBASE DATA LOGIC - UNCHANGED
  // ==========================================================

  Future<List<_WorkerAttendanceItem>> _loadAttendanceItems(
      List<ApplicationModel> applications,
      String workerId,
      ) async {
    final items = <_WorkerAttendanceItem>[];

    for (final application in applications) {
      try {
        final JobModel? job =
        await _jobService.getJob(application.jobId);

        if (job == null) continue;

        AttendanceModel? attendance;

        try {
          attendance = await _attendanceService.getAttendance(
            jobId: application.jobId,
            workerId: workerId,
          );
        } catch (_) {
          attendance = null;
        }

        items.add(
          _WorkerAttendanceItem(
            application: application,
            job: job,
            attendance: attendance,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    items.sort(
          (a, b) => _parseJobDate(b.job.date)
          .compareTo(_parseJobDate(a.job.date)),
    );

    return items;
  }

  List<_WorkerAttendanceItem> _filterItems(
      List<_WorkerAttendanceItem> items,
      ) {
    if (_selectedFilter == 'All') return items;

    return items.where((item) {
      final status = _effectiveStatus(item);

      switch (_selectedFilter) {
        case 'Not Marked':
          return status == 'not_marked';
        case 'Present':
          return status == 'present';
        case 'Absent':
          return status == 'absent';
        default:
          return true;
      }
    }).toList();
  }

  String _effectiveStatus(_WorkerAttendanceItem item) {
    if (item.job.status.trim().toLowerCase() == 'cancelled') {
      return 'cancelled';
    }

    final status =
        item.attendance?.status.trim().toLowerCase() ??
            'not_marked';

    if (status == 'present') return 'present';
    if (status == 'absent') return 'absent';

    return 'not_marked';
  }

  DateTime _parseJobDate(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final direct = DateTime.tryParse(text);
    if (direct != null) return direct;

    final slash = text.split('/');
    if (slash.length == 3) {
      final day = int.tryParse(slash[0].trim());
      final month = int.tryParse(slash[1].trim());
      final year = int.tryParse(slash[2].trim());

      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final dash = text.split('-');
    if (dash.length == 3) {
      final first = int.tryParse(dash[0].trim());
      final second = int.tryParse(dash[1].trim());
      final third = int.tryParse(dash[2].trim());

      if (first != null && second != null && third != null) {
        return first > 1000
            ? DateTime(first, second, third)
            : DateTime(third, second, first);
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
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

  String _formatDateTime(DateTime dateTime) {
    final date = dateTime.toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    return '$day/$month/$year  $hour:$minute $period';
  }

  // ==========================================================
  // EMPTY / ERROR STATES
  // ==========================================================

  Widget _errorView() {
    return _emptyState(
      Icons.sync_problem_outlined,
      'Attendance Not Available Yet',
      'Your attendance information is not available right now. Please check again after your event has been confirmed.',
    );
  }

  String _filterEmptyMessage() {
    switch (_selectedFilter) {
      case 'Present':
        return 'You do not have any events marked Present yet.';
      case 'Absent':
        return 'You do not have any events marked Absent.';
      case 'Not Marked':
        return 'All available attendance records have already been marked.';
      default:
        return 'No attendance records are available.';
    }
  }

  Widget _emptyState(
      IconData icon,
      String title,
      String description,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F5F0),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                color: _darkGreen,
                size: 37,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerAttendanceItem {
  final ApplicationModel application;
  final JobModel job;
  final AttendanceModel? attendance;

  const _WorkerAttendanceItem({
    required this.application,
    required this.job,
    required this.attendance,
  });
}
