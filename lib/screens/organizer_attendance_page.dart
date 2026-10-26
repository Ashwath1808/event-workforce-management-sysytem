
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';
import 'job_model.dart';
import 'job_service.dart';
import 'organizer_event_attendance_page.dart';

// ============================================================
// CREWSYNC — ORGANIZER ATTENDANCE
// PROFESSIONAL MIDNIGHT NAVY & CORAL THEME
// ============================================================

const Color _bg = Color(0xFF0B1220);
const Color _card = Color(0xFF19263B);
const Color _cardLight = Color(0xFF203149);
const Color _stroke = Color(0xFF2B3D54);
const Color _coral = Color(0xFFF06449);
const Color _coralBright = Color(0xFFFF7857);
const Color _teal = Color(0xFF35D1AC);
const Color _text = Color(0xFFF7F9FC);
const Color _subtext = Color(0xFFA7B7CD);
const Color _amber = Color(0xFFFFC178);
const Color _red = Color(0xFFFF8490);

class OrganizerAttendancePage extends StatefulWidget {
  const OrganizerAttendancePage({super.key});

  @override
  State<OrganizerAttendancePage> createState() =>
      _OrganizerAttendancePageState();
}

class _OrganizerAttendancePageState
    extends State<OrganizerAttendancePage> {
  final JobService _jobService = JobService();

  final ApplicationService _applicationService =
  ApplicationService();

  final AttendanceService _attendanceService =
  AttendanceService();

  final TextEditingController _searchController =
  TextEditingController();

  String _selectedFilter = 'Active';
  bool _newestFirst = true;

  static const List<String> _filters = [
    'Active',
    'Completed',
    'Cancelled',
    'All',
  ];

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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _coral,
          secondary: _teal,
          surface: _card,
          onSurface: _text,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: currentUser == null
                    ? _message(
                  Icons.lock_outline_rounded,
                  'Session expired',
                  'Please log in again.',
                )
                    : StreamBuilder<List<JobModel>>(
                  stream: _jobService
                      .getOrganizerJobs(currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _message(
                        Icons.cloud_off_rounded,
                        'Unable to load events',
                        '${snapshot.error}',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _coral,
                        ),
                      );
                    }

                    final allJobs = snapshot.data!;
                    final filtered = _filterJobs(allJobs);

                    return Column(
                      children: [
                        _overviewCard(allJobs),
                        _searchBar(),
                        _filterBar(),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(
                            18,
                            17,
                            18,
                            10,
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'YOUR EVENTS',
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${filtered.length} results',
                                style: const TextStyle(
                                  color: _subtext,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? _message(
                            Icons.event_busy_outlined,
                            'No matching events',
                            allJobs.isEmpty
                                ? 'Your posted events will appear here.'
                                : 'Try another search or filter.',
                          )
                              : ListView.builder(
                            physics:
                            const BouncingScrollPhysics(),
                            padding:
                            const EdgeInsets.fromLTRB(
                              18,
                              4,
                              18,
                              30,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _eventCard(
                                filtered[index],
                                currentUser.uid,
                              );
                            },
                          ),
                        ),
                      ],
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
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        14,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _text,
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance',
                  style: TextStyle(
                    color: _text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your event workforce',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _coral.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _coral.withOpacity(0.18),
              ),
            ),
            child: IconButton(
              tooltip: _newestFirst
                  ? 'Sort oldest first'
                  : 'Sort newest first',
              onPressed: () {
                setState(() {
                  _newestFirst = !_newestFirst;
                });
              },
              icon: const Icon(
                Icons.swap_vert_rounded,
                color: _coralBright,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW CARD
  // ============================================================

  Widget _overviewCard(List<JobModel> jobs) {
    final active = jobs
        .where(
          (job) =>
      job.status.trim().toLowerCase() == 'active',
    )
        .length;

    final completed = jobs
        .where(
          (job) =>
      job.status.trim().toLowerCase() == 'completed',
    )
        .length;

    final cancelled = jobs
        .where(
          (job) =>
      job.status.trim().toLowerCase() == 'cancelled',
    )
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      padding: const EdgeInsets.all(19),
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
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: _coralBright,
                size: 19,
              ),
              SizedBox(width: 9),
              Text(
                'ATTENDANCE OVERVIEW',
                style: TextStyle(
                  color: _subtext,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Select an event to manage attendance for accepted workers.',
            style: TextStyle(
              color: _subtext,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _overviewMetric(
                'Total',
                jobs.length,
                _text,
                'All',
                Icons.layers_outlined,
              ),
              _overviewMetric(
                'Active',
                active,
                _teal,
                'Active',
                Icons.bolt_rounded,
              ),
              _overviewMetric(
                'Completed',
                completed,
                _amber,
                'Completed',
                Icons.verified_outlined,
              ),
              _overviewMetric(
                'Cancelled',
                cancelled,
                _red,
                'Cancelled',
                Icons.cancel_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewMetric(
      String label,
      int count,
      Color color,
      String filter,
      IconData icon,
      ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: const TextStyle(
                color: _text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _subtext,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: TextField(
        controller: _searchController,
        cursorColor: _coral,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: _text,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search event name or location...',
          hintStyle: const TextStyle(
            color: _subtext,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _coralBright,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() {});
            },
            icon: const Icon(
              Icons.close_rounded,
              color: _subtext,
            ),
          ),
          filled: true,
          fillColor: _card,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _coral,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = filter == _selectedFilter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            showCheckmark: false,
            selectedColor: _coral,
            backgroundColor: _card,
            side: BorderSide(
              color: selected ? _coral : _stroke,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelStyle: TextStyle(
              color: selected ? _text : _subtext,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // FILTER AND SORT EVENTS
  // ============================================================

  List<JobModel> _filterJobs(List<JobModel> jobs) {
    final query =
    _searchController.text.trim().toLowerCase();

    final filtered = jobs.where((job) {
      final status = job.status.trim().toLowerCase();

      final matchesFilter = _selectedFilter == 'All' ||
          status == _selectedFilter.toLowerCase();

      final matchesSearch = query.isEmpty ||
          job.title.toLowerCase().contains(query) ||
          job.location.toLowerCase().contains(query) ||
          job.date.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _parseJobDate(a.date);
      final bDate = _parseJobDate(b.date);

      return _newestFirst
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });

    return filtered;
  }

  // ============================================================
  // EVENT CARD
  // ============================================================

  Widget _eventCard(
      JobModel job,
      String organizerId,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _openAttendance(job),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      color: _coral.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.event_available_outlined,
                      color: _coralBright,
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
                            color: _text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _detail(
                          Icons.calendar_today_outlined,
                          job.date.isEmpty
                              ? 'Date not provided'
                              : job.date,
                        ),
                        const SizedBox(height: 8),
                        _detail(
                          Icons.access_time_outlined,
                          _jobTime(job),
                        ),
                        const SizedBox(height: 8),
                        _detail(
                          Icons.location_on_outlined,
                          job.location.isEmpty
                              ? 'Location not provided'
                              : job.location,
                        ),
                        const SizedBox(height: 12),
                        _statusChip(job.status),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _subtext,
                  ),
                ],
              ),
            ),
          ),
          const Divider(
            height: 1,
            color: _stroke,
          ),

          // ORGANIZER-SCOPED APPLICATION STREAM

          StreamBuilder<List<ApplicationModel>>(
            stream: _applicationService
                .getOrganizerApplications(organizerId),
            builder: (context, appSnapshot) {
              if (appSnapshot.hasError) {
                return _inlineError(
                  'Unable to load accepted workers: '
                      '${appSnapshot.error}',
                );
              }

              if (!appSnapshot.hasData) {
                return _cardLoading();
              }

              final acceptedWorkers = appSnapshot.data!
                  .where(
                    (app) =>
                app.jobId == job.id &&
                    app.status.trim().toLowerCase() ==
                        'accepted',
              )
                  .toList();

              // ORGANIZER + JOB ATTENDANCE STREAM

              return StreamBuilder<List<AttendanceModel>>(
                stream: _attendanceService
                    .getOrganizerJobAttendance(
                  organizerId: organizerId,
                  jobId: job.id,
                ),
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.hasError) {
                    return _inlineError(
                      'Unable to load attendance: '
                          '${attendanceSnapshot.error}',
                    );
                  }

                  if (!attendanceSnapshot.hasData) {
                    return _cardLoading();
                  }

                  final records = attendanceSnapshot.data!;

                  int present = 0;
                  int absent = 0;
                  int pending = 0;

                  // Count attendance only for accepted
                  // workers belonging to this event.

                  for (final worker in acceptedWorkers) {
                    AttendanceModel? record;

                    for (final item in records) {
                      if (item.workerId == worker.workerId &&
                          item.organizerId == organizerId) {
                        record = item;
                        break;
                      }
                    }

                    final status =
                        record?.status.trim().toLowerCase() ??
                            'not_marked';

                    if (status == 'present') {
                      present++;
                    } else if (status == 'absent') {
                      absent++;
                    } else {
                      pending++;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _countBox(
                              'Accepted',
                              acceptedWorkers.length,
                              _teal,
                              Icons.groups_outlined,
                            ),
                            const SizedBox(width: 7),
                            _countBox(
                              'Present',
                              present,
                              _teal,
                              Icons.check_circle_outline,
                            ),
                            const SizedBox(width: 7),
                            _countBox(
                              'Absent',
                              absent,
                              _red,
                              Icons.cancel_outlined,
                            ),
                            const SizedBox(width: 7),
                            _countBox(
                              'Pending',
                              pending,
                              _amber,
                              Icons.schedule_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _openAttendance(job);
                            },
                            icon: const Icon(
                              Icons.fact_check_outlined,
                              size: 19,
                            ),
                            label: Text(
                              acceptedWorkers.isEmpty
                                  ? 'View Attendance'
                                  : 'Manage Attendance',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _coral,
                              foregroundColor: _text,
                              elevation: 0,
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(13),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE COUNT BOX
  // ============================================================

  Widget _countBox(
      String label,
      int count,
      Color color,
      IconData icon,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 11,
          horizontal: 2,
        ),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _stroke,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 18,
            ),
            const SizedBox(height: 7),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _subtext,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EVENT STATUS CHIP
  // ============================================================

  Widget _statusChip(String status) {
    final normalized = status.trim().toLowerCase();

    late final Color color;
    late final String label;

    switch (normalized) {
      case 'completed':
        color = _teal;
        label = 'COMPLETED';
        break;
      case 'cancelled':
        color = _red;
        label = 'CANCELLED';
        break;
      case 'closed':
        color = _amber;
        label = 'CLOSED';
        break;
      default:
        color = _teal;
        label = 'ACTIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // EVENT DETAIL ROW
  // ============================================================

  Widget _detail(
      IconData icon,
      String value,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          color: _coralBright,
          size: 15,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _subtext,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOADING / ERROR STATES
  // ============================================================

  Widget _cardLoading() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(
          color: _coral,
        ),
      ),
    );
  }

  Widget _inlineError(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(
          color: _red,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _message(
      IconData icon,
      String title,
      String subtitle,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: _coralBright,
                size: 38,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _subtext,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // JOB TIME
  // ============================================================

  String _jobTime(JobModel job) {
    final start = job.startTime.trim();
    final end = job.endTime.trim();

    if (start.isEmpty && end.isEmpty) {
      return 'Time not provided';
    }

    if (start.isEmpty) return end;
    if (end.isEmpty) return start;

    return '$start - $end';
  }

  // ============================================================
  // OPEN EVENT ATTENDANCE
  // ============================================================

  void _openAttendance(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerEventAttendancePage(
          job: job,
        ),
      ),
    );
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime _parseJobDate(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final iso = DateTime.tryParse(trimmed);

    if (iso != null) return iso;

    final match = RegExp(
      r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$',
    ).firstMatch(trimmed);

    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      final parsed = DateTime(
        year,
        month,
        day,
      );

      if (parsed.day == day &&
          parsed.month == month &&
          parsed.year == year) {
        return parsed;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
