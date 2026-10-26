
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'job_details_page.dart';
import 'job_service.dart';

// ============================================================
// CREWSYNC - WORKER NOTIFICATIONS
// MIDNIGHT & EMERALD DESIGN
// REAL-TIME FIRESTORE NOTIFICATIONS
// ============================================================

class WorkerNotificationsPage extends StatefulWidget {
  const WorkerNotificationsPage({super.key});

  @override
  State<WorkerNotificationsPage> createState() =>
      _WorkerNotificationsPageState();
}

class _WorkerNotificationsPageState
    extends State<WorkerNotificationsPage> {
  static const Color _navy = Color(0xFF101828);
  static const Color _emerald = Color(0xFF00C9A7);
  static const Color _deepGreen = Color(0xFF008F78);
  static const Color _background = Color(0xFFF3F6F8);
  static const Color _ink = Color(0xFF182230);
  static const Color _muted = Color(0xFF526174);
  static const Color _border = Color(0xFFE3E9EF);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final JobService _jobService = JobService();

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _jobsStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>?
  _applicationsStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>?
  _readStatesStream;

  final Set<String> _openingNotifications = {};

  String? _currentUserId;

  @override
  void initState() {
    super.initState();

    _jobsStream = _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'active')
        .snapshots();

    _initializeWorkerStreams();
  }

  void _initializeWorkerStreams() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _currentUserId = user.uid;

    _applicationsStream = _firestore
        .collection('applications')
        .where('workerId', isEqualTo: user.uid)
        .snapshots();

    _readStatesStream = _firestore
        .collection('notificationStates')
        .doc(user.uid)
        .collection('items')
        .snapshots();
  }

  DateTime _timestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _stringValue(dynamic value) {
    return (value ?? '').toString().trim();
  }

  // ============================================================
  // BUILD PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: _background,
        body: _pageLayout(
          context,
          count: 0,
          content: _emptyState(
            Icons.lock_outline_rounded,
            'Login Required',
            'Please log in to view notifications.',
          ),
        ),
      );
    }

    // Rebuild the worker-specific listeners if the
    // authenticated account changes.
    if (_currentUserId != user.uid) {
      _initializeWorkerStreams();
    }

    return Scaffold(
      backgroundColor: _background,
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _jobsStream,
        builder: (context, jobsSnapshot) {
          if (jobsSnapshot.hasError) {
            debugPrint(
              'WORKER JOB STREAM ERROR: '
                  '${jobsSnapshot.error}',
            );

            return _errorLayout(
              context,
              'Unable to load jobs: '
                  '${jobsSnapshot.error}',
            );
          }

          if (!jobsSnapshot.hasData) {
            return _loadingLayout(context);
          }

          final activeJobs = jobsSnapshot.data!.docs;

          debugPrint(
            'WORKER NOTIFICATIONS: '
                '${activeJobs.length} active jobs received',
          );

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _applicationsStream,
            builder: (context, appSnapshot) {
              if (appSnapshot.hasError) {
                debugPrint(
                  'APPLICATION STREAM ERROR: '
                      '${appSnapshot.error}',
                );

                return _errorLayout(
                  context,
                  'Unable to load applications: '
                      '${appSnapshot.error}',
                );
              }

              if (!appSnapshot.hasData) {
                return _loadingLayout(context);
              }

              final applications =
                  appSnapshot.data!.docs;

              return StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _readStatesStream,
                builder: (context, readSnapshot) {
                  if (readSnapshot.hasError) {
                    debugPrint(
                      'NOTIFICATION STATE ERROR: '
                          '${readSnapshot.error}',
                    );

                    return _errorLayout(
                      context,
                      'Unable to load notification states: '
                          '${readSnapshot.error}',
                    );
                  }

                  if (!readSnapshot.hasData) {
                    return _loadingLayout(context);
                  }

                  // ======================================
                  // READ NOTIFICATION IDS
                  // ======================================

                  final readIds = readSnapshot
                      .data!.docs
                      .where(
                        (doc) =>
                    doc.data()['isRead'] == true,
                  )
                      .map((doc) => doc.id)
                      .toSet();

                  // ======================================
                  // ALREADY APPLIED JOB IDS
                  // ======================================

                  final appliedJobIds = applications
                      .map(
                        (doc) => _stringValue(
                      doc.data()['jobId'],
                    ),
                  )
                      .where((id) => id.isNotEmpty)
                      .toSet();

                  final notifications =
                  <_WorkerNotification>[];

                  // ======================================
                  // APPLICATION RESULT NOTIFICATIONS
                  // ======================================

                  for (final doc in applications) {
                    final data = doc.data();

                    final status = _stringValue(
                      data['status'],
                    ).toLowerCase();

                    if (status != 'accepted' &&
                        status != 'rejected') {
                      continue;
                    }

                    final jobId = _stringValue(
                      data['jobId'],
                    );

                    final jobTitle = _stringValue(
                      data['jobTitle'],
                    ).isNotEmpty
                        ? _stringValue(data['jobTitle'])
                        : 'your job';

                    final isAccepted =
                        status == 'accepted';

                    notifications.add(
                      _WorkerNotification(
                        id:
                        'job_result_${doc.id}_$status',
                        type: status,
                        title: isAccepted
                            ? 'Application Accepted!'
                            : 'Application Rejected',
                        message: isAccepted
                            ? 'Congratulations! Your '
                            'application for "$jobTitle" '
                            'has been accepted by '
                            'the organizer.'
                            : 'Your application for '
                            '"$jobTitle" was not selected.',
                        jobId: jobId,
                        createdAt: _timestamp(
                          data['updatedAt'] ??
                              data['appliedAt'],
                        ),
                      ),
                    );
                  }

                  // ======================================
                  // NEW JOB NOTIFICATIONS
                  // ======================================

                  for (final doc in activeJobs) {
                    final data = doc.data();

                    final organizerId =
                    _stringValue(
                      data['organizerId'],
                    );

                    // Do not notify an organizer
                    // about their own jobs.
                    if (organizerId == user.uid) {
                      continue;
                    }

                    // Do not show new-job alerts for
                    // jobs already applied to.
                    if (appliedJobIds.contains(doc.id)) {
                      continue;
                    }

                    final title = _stringValue(
                      data['title'],
                    ).isNotEmpty
                        ? _stringValue(data['title'])
                        : 'New Job Opportunity';

                    final location = _stringValue(
                      data['location'],
                    ).isNotEmpty
                        ? _stringValue(data['location'])
                        : 'Unknown location';

                    final payment = _stringValue(
                      data['paymentPerWorker'],
                    ).isNotEmpty
                        ? _stringValue(
                      data['paymentPerWorker'],
                    )
                        : '0';

                    notifications.add(
                      _WorkerNotification(
                        id: 'job_${doc.id}',
                        type: 'new_job',
                        title: title,
                        message:
                        '$location • ₹$payment per worker',
                        jobId: doc.id,
                        location: location,
                        payment: payment,
                        createdAt: _timestamp(
                          data['createdAt'],
                        ),
                      ),
                    );
                  }

                  // ======================================
                  // REMOVE READ NOTIFICATIONS
                  // ======================================

                  final unreadNotifications =
                  notifications.where((notification) {
                    return !readIds.contains(
                      notification.id,
                    );
                  }).toList();

                  unreadNotifications.sort(
                        (a, b) => b.createdAt
                        .compareTo(a.createdAt),
                  );

                  // ======================================
                  // DEBUGGING INFORMATION
                  // ======================================

                  debugPrint(
                    '========== WORKER NOTIFICATIONS ==========',
                  );

                  debugPrint(
                    'Worker UID: ${user.uid}',
                  );

                  debugPrint(
                    'Active jobs: ${activeJobs.length}',
                  );

                  debugPrint(
                    'Applications: ${applications.length}',
                  );

                  debugPrint(
                    'Applied job IDs: $appliedJobIds',
                  );

                  debugPrint(
                    'Read notification IDs: $readIds',
                  );

                  debugPrint(
                    'Generated notifications: '
                        '${notifications.length}',
                  );

                  debugPrint(
                    'Unread notifications: '
                        '${unreadNotifications.length}',
                  );

                  for (final job in activeJobs) {
                    debugPrint(
                      'Job ${job.id}: ${job.data()}',
                    );
                  }

                  debugPrint(
                    '==========================================',
                  );

                  // ======================================
                  // DISPLAY NOTIFICATIONS
                  // ======================================

                  return _pageLayout(
                    context,
                    count:
                    unreadNotifications.length,
                    content: unreadNotifications.isEmpty
                        ? _emptyState(
                      Icons.notifications_none_rounded,
                      'All Caught Up!',
                      'You have no unread '
                          'notifications. New jobs and '
                          'application updates will '
                          'appear here automatically.',
                    )
                        : ListView.builder(
                      physics:
                      const BouncingScrollPhysics(),
                      padding:
                      const EdgeInsets.fromLTRB(
                        18,
                        20,
                        18,
                        35,
                      ),
                      itemCount:
                      unreadNotifications.length,
                      itemBuilder: (context, index) {
                        final notification =
                        unreadNotifications[index];

                        return _notificationCard(
                          context,
                          notification,
                          user.uid,
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // OPEN NOTIFICATION
  // ============================================================

  Future<void> _openNotification(
      BuildContext context,
      _WorkerNotification notification,
      String userId,
      ) async {
    if (_openingNotifications.contains(
      notification.id,
    )) {
      return;
    }

    setState(() {
      _openingNotifications.add(
        notification.id,
      );
    });

    try {
      final jobId = notification.jobId;

      if (jobId == null || jobId.isEmpty) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This notification has no linked job.',
            ),
          ),
        );
        return;
      }

      // ======================================
      // FETCH THE RELATED JOB
      // ======================================

      final job = await _jobService.getJob(jobId);

      if (!context.mounted) return;

      if (job == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This job is no longer available.',
            ),
          ),
        );
        return;
      }

      // ======================================
      // MARK NOTIFICATION AS READ
      // ======================================

      await _firestore
          .collection('notificationStates')
          .doc(userId)
          .collection('items')
          .doc(notification.id)
          .set({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'jobId': jobId,
        'type': notification.type,
      }, SetOptions(merge: true));

      if (!context.mounted) return;

      // ======================================
      // NAVIGATE TO JOB DETAILS
      // ======================================

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(
            job: job,
          ),
        ),
      );

      // Firestore's read-state stream updates
      // automatically and hides this notification.

    } catch (e) {
      debugPrint(
        'OPEN NOTIFICATION ERROR: $e',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open notification: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingNotifications.remove(
            notification.id,
          );
        });
      }
    }
  }

  // ============================================================
  // LOADING LAYOUT
  // ============================================================

  Widget _loadingLayout(BuildContext context) {
    return _pageLayout(
      context,
      count: 0,
      content: const Center(
        child: CircularProgressIndicator(
          color: _deepGreen,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR LAYOUT
  // ============================================================

  Widget _errorLayout(
      BuildContext context,
      String message,
      ) {
    return _pageLayout(
      context,
      count: 0,
      content: _emptyState(
        Icons.error_outline_rounded,
        'Unable to Load Notifications',
        message,
      ),
    );
  }

  // ============================================================
  // PAGE LAYOUT
  // ============================================================

  Widget _pageLayout(
      BuildContext context, {
        required int count,
        required Widget content,
      }) {
    return Column(
      children: [
        _header(context, count),
        Expanded(child: content),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header(
      BuildContext context,
      int count,
      ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        13,
        MediaQuery.paddingOf(context).top + 18,
        20,
        25,
      ),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF203C3E),
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: _emerald,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Padding(
            padding:
            EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              'STAY IN THE LOOP',
              style: TextStyle(
                color: _emerald,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding:
            EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              'Your next opportunity awaits.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding:
            EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              'New jobs and application updates, '
                  'all in one place.',
              style: TextStyle(
                color: Color(0xFFE1E8EE),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 21),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFF203247),
              borderRadius:
              BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF304458),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  color: _emerald,
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Unread notifications',
                        style: TextStyle(
                          color: Color(0xFFE1E8EE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: _emerald,
                  size: 23,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget _notificationCard(
      BuildContext context,
      _WorkerNotification notification,
      String userId,
      ) {
    final isAccepted =
        notification.type == 'accepted';

    final isRejected =
        notification.type == 'rejected';

    final isJob =
        notification.type == 'new_job';

    final isOpening =
    _openingNotifications.contains(
      notification.id,
    );

    final accent = isAccepted
        ? _deepGreen
        : isRejected
        ? const Color(0xFFCF5960)
        : _deepGreen;

    final notificationIcon = isAccepted
        ? Icons.check_circle_outline_rounded
        : isRejected
        ? Icons.cancel_outlined
        : Icons.work_outline_rounded;

    final category = isAccepted
        ? 'APPLICATION ACCEPTED'
        : isRejected
        ? 'APPLICATION REJECTED'
        : 'NEW JOB OPPORTUNITY';

    return Container(
      margin: const EdgeInsets.only(
        top: 5,
        bottom: 16,
        left: 2,
        right: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB7E9DD),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.07),
            blurRadius: 19,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
        BorderRadius.circular(20),
        child: InkWell(
          borderRadius:
          BorderRadius.circular(20),
          onTap: isOpening
              ? null
              : () => _openNotification(
            context,
            notification,
            userId,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius:
                  const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 49,
                          height: 49,
                          decoration: BoxDecoration(
                            color: isRejected
                                ? const Color(
                              0xFFFFEBED,
                            )
                                : const Color(
                              0xFFE0F7F0,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: Icon(
                            notificationIcon,
                            color: accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight:
                                  FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                notification.title,
                                maxLines: 3,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.w900,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _newBadge(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: isJob
                          ? Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: _deepGreen,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notification.location ??
                                      'Unknown location',
                                  style:
                                  const TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.currency_rupee_rounded,
                                color: _deepGreen,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '₹${notification.payment ?? '0'}'
                                      ' per worker',
                                  style:
                                  const TextStyle(
                                    color: _ink,
                                    fontSize: 15,
                                    fontWeight:
                                    FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                          : Text(
                        notification.message,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          height: 1.6,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(
                      height: 1,
                      color: _border,
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: _muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatCreatedAt(
                              notification.createdAt,
                            ),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isOpening)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _deepGreen,
                            ),
                          )
                        else ...[
                          Text(
                            isJob
                                ? 'VIEW JOB'
                                : 'VIEW DETAILS',
                            style: const TextStyle(
                              color: _deepGreen,
                              fontSize: 11,
                              fontWeight:
                              FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: _deepGreen,
                            size: 18,
                          ),
                        ],
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

  // ============================================================
  // NEW BADGE
  // ============================================================

  Widget _newBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7F0),
        borderRadius:
        BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: _deepGreen,
          ),
          SizedBox(width: 5),
          Text(
            'New',
            style: TextStyle(
              color: _deepGreen,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE FORMATTING
  // ============================================================

  String _formatCreatedAt(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Recently updated';
    }

    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference =
    now.difference(localDate);

    if (!difference.isNegative) {
      if (difference.inMinutes < 1) {
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
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${localDate.day} '
        '${months[localDate.month - 1]} '
        '${localDate.year}';
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F5F0),
                borderRadius:
                BorderRadius.circular(26),
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
}

// ============================================================
// NOTIFICATION MODEL
// ============================================================

class _WorkerNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? jobId;
  final String? location;
  final String? payment;
  final DateTime createdAt;

  const _WorkerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.jobId,
    this.location,
    this.payment,
  });
}
