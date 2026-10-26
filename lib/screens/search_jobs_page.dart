
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'job_model.dart';
import 'job_service.dart';
import 'job_details_page.dart';
import 'application_service.dart';

class SearchJobsPage extends StatefulWidget {
  const SearchJobsPage({super.key});

  @override
  State<SearchJobsPage> createState() => _SearchJobsPageState();
}

class _SearchJobsPageState extends State<SearchJobsPage> {
  static const Color _navy = Color(0xFF101828);
  static const Color _navySoft = Color(0xFF22334A);
  static const Color _emerald = Color(0xFF00C9A7);
  static const Color _deepGreen = Color(0xFF008F78);
  static const Color _background = Color(0xFFF4F7F9);
  static const Color _ink = Color(0xFF182230);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE5EAF0);
  static const Color _amber = Color(0xFFB7791F);
  static const Color _red = Color(0xFFCC4545);

  final TextEditingController _searchController =
  TextEditingController();

  final JobService _jobService = JobService();
  final ApplicationService _applicationService =
  ApplicationService();

  String selectedFilter = 'All';

  final Map<String, bool> _appliedJobs = {};
  final Set<String> _checkingJobs = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // APPLICATION STATUS
  // ============================================================

  Future<void> _checkApplicationStatus(JobModel job) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _checkingJobs.contains(job.id)) {
      return;
    }

    _checkingJobs.add(job.id);

    try {
      final applied =
      await _applicationService.hasWorkerApplied(
        jobId: job.id,
        workerId: user.uid,
      );

      if (!mounted) return;

      setState(() {
        _appliedJobs[job.id] = applied;
      });
    } catch (e) {
      debugPrint(
        'Unable to check application status for ${job.id}: $e',
      );
    } finally {
      _checkingJobs.remove(job.id);
    }
  }

  Future<void> _openJobDetails(JobModel job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(job: job),
      ),
    );

    if (!mounted) return;

    setState(() {
      _appliedJobs.remove(job.id);
      _checkingJobs.remove(job.id);
    });

    await _checkApplicationStatus(job);
  }

  // ============================================================
  // VACANCY HELPERS
  // ============================================================

  int _remainingVacancies(JobModel job) {
    final total =
    job.workersNeeded < 0 ? 0 : job.workersNeeded;

    final accepted =
    job.acceptedWorkers < 0 ? 0 : job.acceptedWorkers;

    final remaining = total - accepted;
    return remaining > 0 ? remaining : 0;
  }

  bool _isFilled(JobModel job) {
    return _remainingVacancies(job) == 0;
  }

  bool _isAvailable(JobModel job) {
    final status = job.status.trim().toLowerCase();
    return status == 'active' && !_isFilled(job);
  }

  String _vacancyStatus(JobModel job) {
    final status = job.status.trim().toLowerCase();

    if (status == 'cancelled') return 'Cancelled';
    if (status == 'completed') return 'Completed';
    if (status == 'closed') return 'Closed';

    if (_isFilled(job)) return 'Fully Filled';
    if (status != 'active') return 'Unavailable';

    return 'Open';
  }

  Color _statusColor(JobModel job) {
    if (_isAvailable(job)) return _deepGreen;

    if (job.status.trim().toLowerCase() == 'cancelled' ||
        _isFilled(job)) {
      return _red;
    }

    return _amber;
  }

  double _fillProgress(JobModel job) {
    if (job.workersNeeded <= 0) return 1;

    return (job.acceptedWorkers / job.workersNeeded)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<List<JobModel>>(
              stream: _jobService.getPublishedJobs(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _errorView('${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _deepGreen,
                    ),
                  );
                }

                final jobs = _filteredJobs(snapshot.data!);

                for (final job in jobs) {
                  if (!_appliedJobs.containsKey(job.id) &&
                      !_checkingJobs.contains(job.id)) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) {
                      if (mounted) {
                        _checkApplicationStatus(job);
                      }
                    });
                  }
                }

                return Column(
                  children: [
                    _resultsHeading(jobs.length),
                    _buildFilters(),
                    const SizedBox(height: 13),
                    Expanded(
                      child: jobs.isEmpty
                          ? _emptyView()
                          : ListView.builder(
                        physics:
                        const BouncingScrollPhysics(),
                        padding:
                        const EdgeInsets.fromLTRB(
                          18,
                          12,
                          18,
                          32,
                        ),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          return _jobCard(jobs[index]);
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
    );
  }

  // ============================================================
  // PREMIUM NAVY HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 12,
        18,
        24,
      ),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(27),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 3),
              const Expanded(
                child: Text(
                  'Search Jobs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _navySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: _emerald,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISCOVER OPPORTUNITIES',
                  style: TextStyle(
                    color: _emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Find your next great event.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Explore jobs that match your interests.',
                  style: TextStyle(
                    color: Color(0xFFB4C1CC),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search event, location or category',
                hintStyle: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _deepGreen,
                  size: 23,
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
                    color: _muted,
                    size: 19,
                  ),
                ),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(
                  vertical: 17,
                  horizontal: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULTS AND FILTERS
  // ============================================================

  Widget _resultsHeading(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        21,
        20,
        15,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Explore Jobs',
              style: TextStyle(
                color: _navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F5F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count found',
              style: const TextStyle(
                color: _deepGreen,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      'All',
      'Today',
      'Nearby',
      'High Pay',
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
          final selected = selectedFilter == filter;

          final icon = switch (filter) {
            'Today' => Icons.today_outlined,
            'Nearby' => Icons.location_on_outlined,
            'High Pay' => Icons.trending_up_rounded,
            _ => Icons.apps_rounded,
          };

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: selected ? _navy : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected ? _navy : _border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected
                        ? _emerald
                        : _muted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    filter,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<JobModel> _filteredJobs(List<JobModel> jobs) {
    final search =
    _searchController.text.trim().toLowerCase();

    final result = jobs.where((job) {
      if (search.isEmpty) return true;

      return job.title.toLowerCase().contains(search) ||
          job.location.toLowerCase().contains(search) ||
          job.category.toLowerCase().contains(search);
    }).toList();

    if (selectedFilter == 'High Pay') {
      result.sort(
            (a, b) => b.paymentPerWorker.compareTo(
          a.paymentPerWorker,
        ),
      );
    }

    // Today and Nearby remain visual filters, matching
    // the behavior of the previous implementation.
    return result;
  }

  // ============================================================
  // FLOATING EVENT CARD - IMPROVED SEPARATION
  // ============================================================

  Widget _jobCard(JobModel job) {
    final statusLoaded = _appliedJobs.containsKey(job.id);
    final alreadyApplied = _appliedJobs[job.id] ?? false;

    final available = _isAvailable(job);
    final remaining = _remainingVacancies(job);
    final progress = _fillProgress(job);
    final statusColor = _statusColor(job);

    return Container(
      margin: const EdgeInsets.only(
        top: 7,
        bottom: 19,
        left: 2,
        right: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD8E2E8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.10),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openJobDetails(job),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  17,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2F7F1),
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.work_outline_rounded,
                            color: _deepGreen,
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
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 7),
                              _detailLine(
                                Icons.location_on_outlined,
                                job.location,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _statusBadge(job),
                        const Spacer(),
                        if (job.category.trim().isNotEmpty)
                          Flexible(
                            child: Text(
                              job.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _infoBlock(
                              Icons.calendar_today_outlined,
                              'EVENT DATE',
                              job.date,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoBlock(
                              Icons.schedule_rounded,
                              'EVENT TIME',
                              _eventTime(job),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'WORKFORCE AVAILABILITY',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: _countBox(
                            '${job.workersNeeded}',
                            'Total',
                            _navy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _countBox(
                            '${job.applicationsCount}',
                            'Applied',
                            _amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _countBox(
                            '${job.acceptedWorkers}',
                            'Accepted',
                            _deepGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Icon(
                          remaining > 0
                              ? Icons.groups_outlined
                              : Icons.event_busy_outlined,
                          color: available
                              ? _deepGreen
                              : statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            available
                                ? '$remaining ${remaining == 1 ? 'vacancy' : 'vacancies'} remaining'
                                : _vacancyStatus(job),
                            style: TextStyle(
                              color: available
                                  ? _deepGreen
                                  : statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}% filled',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor:
                        const Color(0xFFE7EDF1),
                        valueColor:
                        AlwaysStoppedAnimation<Color>(
                          _isFilled(job)
                              ? _red
                              : _emerald,
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    const Divider(
                      height: 1,
                      color: _border,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PAYMENT PER WORKER',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '₹${_formatPayment(job.paymentPerWorker)}',
                                style: const TextStyle(
                                  color: _navy,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _actionButton(
                          job,
                          statusLoaded: statusLoaded,
                          alreadyApplied: alreadyApplied,
                          available: available,
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

  Widget _statusBadge(JobModel job) {
    final color = _statusColor(job);
    final available = _isAvailable(job);

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
          Icon(
            available
                ? Icons.check_circle_outline
                : Icons.info_outline_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            _vacancyStatus(job),
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

  Widget _infoBlock(
      IconData icon,
      String label,
      String value,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _deepGreen, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
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
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
      ],
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

  Widget _countBox(
      String count,
      String label,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLICATION BUTTON
  // ============================================================

  Widget _actionButton(
      JobModel job, {
        required bool statusLoaded,
        required bool alreadyApplied,
        required bool available,
      }) {
    if (!statusLoaded) {
      return Container(
        width: 112,
        height: 43,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(
            color: _deepGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (alreadyApplied) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F5F0),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: const Color(0xFFB9EBDD),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: _deepGreen,
              size: 17,
            ),
            SizedBox(width: 6),
            Text(
              'Applied',
              style: TextStyle(
                color: _deepGreen,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: available
          ? () => _openJobDetails(job)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
        const Color(0xFFE9EDF1),
        disabledForegroundColor: _muted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            available
                ? 'Apply Now'
                : _isFilled(job)
                ? 'Filled'
                : 'Closed',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (available) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value.trim().isEmpty
                ? 'Not provided'
                : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY AND ERROR
  // ============================================================

  Widget _emptyView() {
    return _messageView(
      Icons.work_off_outlined,
      'No Jobs Available',
      'New jobs posted by organizers will appear here.',
    );
  }

  Widget _errorView(String error) {
    return _messageView(
      Icons.error_outline_rounded,
      'Unable to Load Jobs',
      error,
    );
  }

  Widget _messageView(
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
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: _deepGreen,
                size: 39,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _navy,
                fontSize: 20,
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

  String _formatPayment(double payment) {
    if (payment == payment.roundToDouble()) {
      return payment.toInt().toString();
    }
    return payment.toStringAsFixed(2);
  }
}
