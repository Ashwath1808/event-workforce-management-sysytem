import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'job_model.dart';
import 'job_service.dart';

class _P {
  static const bg = Color(0xFF0B1220);
  static const card = Color(0xFF152238);
  static const field = Color(0xFF101B2E);
  static const border = Color(0xFF29394F);
  static const coral = Color(0xFFF06449);
  static const white = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const green = Color(0xFF34D399);
}

class PostNewJobPage extends StatefulWidget {
  const PostNewJobPage({super.key});

  @override
  State<PostNewJobPage> createState() => _PostNewJobPageState();
}

class _PostNewJobPageState extends State<PostNewJobPage> {
  int _step = 0;
  bool _publishing = false;
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _skills = TextEditingController();
  final _workers = TextEditingController();
  final _description = TextEditingController();
  final _payment = TextEditingController();
  final _other = TextEditingController();
  String? _category;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _accommodation = false;
  bool _food = true;
  bool _transport = false;

  static const _categories = [
    'Event Management', 'Crowd Management', 'Security', 'Hospitality',
    'Food & Catering', 'Entry Management', 'Technical Support',
    'Cleaning', 'Photography', 'Other',
  ];
  static const _stepNames = ['Event', 'Crew', 'Benefits', 'Review'];
  static const _stepTitles = [
    'Event information', 'Crew & compensation',
    'Worker benefits', 'Review your posting',
  ];
  static const _stepDescriptions = [
    'Tell workers where and when the event takes place.',
    'Describe the role, staffing needs and payment.',
    'Clarify what is provided and any special requirements.',
    'Check every detail before making your job live.',
  ];

  @override
  void dispose() {
    for (final c in [_title, _location, _skills, _workers,
      _description, _payment, _other]) {
      c.dispose();
    }
    super.dispose();
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'Choose event date';
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _timeText(TimeOfDay? value) =>
      value == null ? 'Choose time' : value.format(context);

  int? get _workerCount => int.tryParse(_workers.text.trim());
  double? get _payAmount => double.tryParse(_payment.text.trim());
  double get _budget => (_workerCount ?? 0) * (_payAmount ?? 0);

  void _message(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: _P.card,
      behavior: SnackBarBehavior.floating,
    ));
  }

  bool _validate(int step) {
    if (step == 0) {
      if (_title.text.trim().isEmpty) { _message('Enter the event or job title.'); return false; }
      if (_category == null) { _message('Choose an event category.'); return false; }
      if (_location.text.trim().isEmpty) { _message('Enter the event location.'); return false; }
      if (_date == null) { _message('Choose an event date.'); return false; }
      if (_start == null || _end == null) { _message('Choose both start and end times.'); return false; }
      final startMinutes = _start!.hour * 60 + _start!.minute;
      final endMinutes = _end!.hour * 60 + _end!.minute;
      if (startMinutes == endMinutes) {
        _message('Start and end times cannot be the same.');
        return false;
      }
      // An earlier end time can indicate an overnight shift.
    }
    if (step == 1) {
      if (_skills.text.trim().isEmpty ||
          _skills.text.split(',').every((s) => s.trim().isEmpty)) {
        _message('Enter at least one required skill.'); return false;
      }
      if ((_workerCount ?? 0) <= 0) { _message('Enter a valid number of workers.'); return false; }
      if (_description.text.trim().isEmpty) { _message('Add a job description.'); return false; }
      final pay = _payAmount;
      if (pay == null || !pay.isFinite || pay <= 0) {
        _message('Enter a valid payment per worker.'); return false;
      }
    }
    return true;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_validate(_step)) return;
    if (_step < 3) setState(() => _step++);
  }

  void _back() {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context, initialDate: _date ?? today,
      firstDate: today, lastDate: DateTime(now.year + 3, 12, 31),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _P.coral, onPrimary: Colors.white,
            surface: _P.card, onSurface: _P.white,
          ),
        ), child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _chooseTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _start : _end) ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _P.coral, onPrimary: Colors.white,
            surface: _P.card, onSurface: _P.white,
          ),
        ), child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() { if (isStart) { _start = picked; } else { _end = picked; } });
    }
  }

  Future<void> _publish() async {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    for (int i = 0; i < 2; i++) {
      if (!_validate(i)) { setState(() => _step = i); return; }
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) { _message('Please log in again.'); return; }
    setState(() => _publishing = true);
    try {
      final job = JobModel(
        id: '',
        title: _title.text.trim(),
        category: _category!,
        location: _location.text.trim(),
        date: _dateText(_date),
        startTime: _timeText(_start),
        endTime: _timeText(_end),
        workersNeeded: _workerCount!,
        paymentPerWorker: _payAmount!,
        description: _description.text.trim(),
        skills: _skills.text.split(',').map((s) => s.trim())
            .where((s) => s.isNotEmpty).toList(),
        accommodationRequired: _accommodation,
        foodProvided: _food,
        transportProvided: _transport,
        otherRequirements: _other.text.trim(),
        imageUrl: '',
        organizerId: firebaseUser.uid,
        status: 'active',
        createdAt: DateTime.now(),
      );
      await JobService().publishJob(job: job);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Job published successfully!'),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_publishing && _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_publishing && _step > 0) _back();
      },
      child: Scaffold(
        backgroundColor: _P.bg,
        appBar: AppBar(
          backgroundColor: _P.bg,
          surfaceTintColor: _P.bg,
          foregroundColor: _P.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            onPressed: _publishing ? null : _back,
          ),
          title: const Text('Create new job', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3,
          )),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _P.coral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('ORGANIZER', style: TextStyle(
                color: _P.coral, fontSize: 9,
                letterSpacing: 0.8, fontWeight: FontWeight.w800,
              )),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            _progressHeader(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _stepContent(),
                    ),
                  ),
                )),
              ),
            ),
            _footer(),
          ]),
        ),
      ),
    );
  }

  Widget _progressHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 19),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _P.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('POST A NEW OPPORTUNITY', style: TextStyle(
            color: _P.muted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.4,
          )),
          Text('STEP ${_step + 1} OF 4', style: const TextStyle(
            color: _P.coral, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1,
          )),
        ]),
        const SizedBox(height: 15),
        Row(children: List.generate(4, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 3 ? 0 : 7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: i <= _step ? _P.coral : _P.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ))),
        const SizedBox(height: 13),
        Row(children: List.generate(4, (i) => Expanded(
          child: Text(_stepNames[i],
            textAlign: i == 0 ? TextAlign.left :
            i == 3 ? TextAlign.right : TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: i == _step ? FontWeight.w800 : FontWeight.w500,
              color: i == _step ? _P.white : _P.muted,
            ),
          ),
        ))),
      ]),
    );
  }

  Widget _stepContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_stepTitles[_step], style: const TextStyle(
        color: _P.white, fontSize: 26,
        fontWeight: FontWeight.w900, letterSpacing: -0.7,
      )),
      const SizedBox(height: 8),
      Text(_stepDescriptions[_step], style: const TextStyle(
        color: _P.muted, fontSize: 13, height: 1.5,
      )),
      const SizedBox(height: 22),
      if (_step == 0) _eventStep(),
      if (_step == 1) _crewStep(),
      if (_step == 2) _benefitsStep(),
      if (_step == 3) _reviewStep(),
    ]);
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 18, offset: const Offset(0, 8),
        )],
      ),
      child: child,
    );
  }

  Widget _section(IconData icon, String title, String subtitle) {
    return Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: _P.coral.withOpacity(0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _P.coral, size: 21),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            color: _P.white, fontSize: 15, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(
            color: _P.muted, fontSize: 11,
          )),
        ],
      )),
    ]);
  }

  Widget _label(String value, {bool optional = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(children: [
      Flexible(child: Text(value, style: const TextStyle(
        color: _P.white, fontSize: 12, fontWeight: FontWeight.w700,
      ))),
      if (optional) const Text('  OPTIONAL', style: TextStyle(
        color: _P.muted, fontSize: 9, letterSpacing: 0.7,
      )),
    ]),
  );

  InputDecoration _decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _P.muted, fontSize: 12),
      prefixIcon: Icon(icon, color: _P.muted, size: 20),
      filled: true, fillColor: _P.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _P.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _P.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _P.coral, width: 1.6)),
    );
  }

  Widget _field(String label, TextEditingController controller,
      String hint, IconData icon, {TextInputType? keyboard,
        int lines = 1, ValueChanged<String>? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      TextField(
        controller: controller, keyboardType: keyboard,
        maxLines: lines, onChanged: onChanged,
        style: const TextStyle(color: _P.white, fontSize: 13),
        cursorColor: _P.coral,
        decoration: _decoration(hint, icon),
      ),
    ]);
  }

  Widget _picker(String label, String value, IconData icon,
      VoidCallback onTap, {bool empty = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      Material(color: _P.field, borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13), onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _P.border),
            ),
            child: Row(children: [
              Icon(icon, color: _P.muted, size: 19),
              const SizedBox(width: 10),
              Expanded(child: Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: empty ? _P.muted : _P.white, fontSize: 12,
                ),
              )),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _P.muted, size: 18),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _eventStep() => _panel(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _section(Icons.event_note_rounded, 'Event essentials',
          'The details workers see first'),
      const SizedBox(height: 24),
      _field('Event / job title', _title, 'e.g. Concert event crew',
          Icons.edit_note_rounded),
      const SizedBox(height: 20),
      _label('Event category'),
      DropdownButtonFormField<String>(
        value: _category, isExpanded: true,
        dropdownColor: _P.card,
        iconEnabledColor: _P.muted,
        style: const TextStyle(color: _P.white, fontSize: 13),
        decoration: _decoration('Select a category', Icons.category_outlined),
        items: _categories.map((c) => DropdownMenuItem(
          value: c, child: Text(c, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (value) => setState(() => _category = value),
      ),
      const SizedBox(height: 20),
      _field('Event location', _location,
          'Venue, area, city', Icons.location_on_outlined),
      const SizedBox(height: 20),
      _picker('Event date', _dateText(_date),
          Icons.calendar_today_outlined, _chooseDate, empty: _date == null),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _picker('Start time', _timeText(_start),
            Icons.schedule_outlined, () => _chooseTime(true),
            empty: _start == null)),
        const SizedBox(width: 12),
        Expanded(child: _picker('End time', _timeText(_end),
            Icons.schedule_outlined, () => _chooseTime(false),
            empty: _end == null)),
      ]),
      const SizedBox(height: 15),
      _hint(Icons.info_outline_rounded,
          'For overnight events, choose an end time earlier than the start time.'),
    ],
  ));

  Widget _crewStep() => Column(children: [
    _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(Icons.groups_2_outlined, 'Crew requirements',
          'Define who you need for this event'),
      const SizedBox(height: 24),
      _field('Required skills', _skills,
          'e.g. Communication, Crowd Management', Icons.psychology_outlined),
      const SizedBox(height: 8),
      const Text('Separate multiple skills with commas.', style: TextStyle(
        color: _P.muted, fontSize: 11,
      )),
      const SizedBox(height: 20),
      _field('Number of workers', _workers,
          'e.g. 12', Icons.groups_outlined,
          keyboard: TextInputType.number,
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 20),
      _field('Job description', _description,
          'Explain duties, responsibilities, dress code and reporting instructions...',
          Icons.description_outlined, lines: 5),
    ])),
    const SizedBox(height: 16),
    _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(Icons.payments_outlined, 'Compensation',
          'Set a clear payment for each worker'),
      const SizedBox(height: 24),
      _field('Payment per worker (₹)', _payment,
          'e.g. 1200', Icons.currency_rupee_rounded,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 18),
      _budgetBanner(),
    ])),
  ]);

  Widget _budgetBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _P.coral.withOpacity(0.10),
      border: Border.all(color: _P.coral.withOpacity(0.25)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(children: [
      const Icon(Icons.account_balance_wallet_outlined,
          color: _P.coral, size: 25),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ESTIMATED CREW BUDGET', style: TextStyle(
          color: _P.muted, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 0.8,
        )),
        const SizedBox(height: 5),
        Text('₹${_budget.toStringAsFixed(2)}', style: const TextStyle(
          color: _P.white, fontSize: 22, fontWeight: FontWeight.w900,
        )),
        const SizedBox(height: 3),
        const Text('Workers × payment per worker', style: TextStyle(
          color: _P.muted, fontSize: 10,
        )),
      ])),
    ]),
  );

  Widget _benefitTile(IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
      decoration: BoxDecoration(
        color: _P.field, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value ? _P.coral.withOpacity(0.5) : _P.border),
      ),
      child: Row(children: [
        Icon(icon, color: value ? _P.coral : _P.muted, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              color: _P.white, fontSize: 12, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(
              color: _P.muted, fontSize: 10,
            )),
          ],
        )),
        Switch(value: value, onChanged: onChanged,
            activeThumbColor: _P.coral, activeTrackColor: _P.coral.withOpacity(0.4)),
      ]),
    );
  }

  Widget _benefitsStep() => Column(children: [
    _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(Icons.verified_user_outlined, 'Facilities & support',
          'Set accurate expectations for your workers'),
      const SizedBox(height: 23),
      _benefitTile(Icons.bed_outlined, 'Accommodation required',
          'Accommodation is a requirement for this job',
          _accommodation, (v) => setState(() => _accommodation = v)),
      _benefitTile(Icons.restaurant_outlined, 'Food provided',
          'Meals will be provided to workers',
          _food, (v) => setState(() => _food = v)),
      _benefitTile(Icons.directions_bus_outlined, 'Transport provided',
          'Transport will be arranged for workers',
          _transport, (v) => setState(() => _transport = v)),
      const SizedBox(height: 10),
      _label('Additional requirements', optional: true),
      TextField(
        controller: _other, maxLines: 4,
        style: const TextStyle(color: _P.white, fontSize: 13),
        cursorColor: _P.coral,
        decoration: _decoration('Any other requirements or instructions...',
            Icons.notes_rounded),
      ),
    ])),

  ]);

  Widget _reviewLine(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _P.coral, size: 19),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _P.muted, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value.isEmpty ? '—' : value, style: const TextStyle(
          color: _P.white, fontSize: 13, fontWeight: FontWeight.w600,
          height: 1.4,
        )),
      ])),
    ]),
  );

  Widget _reviewStep() => Column(children: [
    _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 50, height: 50,
            decoration: BoxDecoration(
              color: _P.coral.withOpacity(0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: _P.coral, size: 27)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title.text.trim(), style: const TextStyle(
            color: _P.white, fontSize: 18, fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 5),
          Text(_category ?? '', style: const TextStyle(
            color: _P.coral, fontSize: 12, fontWeight: FontWeight.w700,
          )),
        ])),
      ]),
      const Divider(color: _P.border, height: 35),
      _reviewLine(Icons.location_on_outlined, 'LOCATION', _location.text.trim()),
      _reviewLine(Icons.calendar_today_outlined, 'EVENT DATE', _dateText(_date)),
      _reviewLine(Icons.schedule_outlined, 'SHIFT TIMING',
          '${_timeText(_start)} – ${_timeText(_end)}'),
      _reviewLine(Icons.groups_outlined, 'WORKERS NEEDED', '${_workerCount ?? 0}'),
      _reviewLine(Icons.currency_rupee, 'PAYMENT PER WORKER',
          '₹${(_payAmount ?? 0).toStringAsFixed(2)}'),
      _reviewLine(Icons.psychology_outlined, 'REQUIRED SKILLS', _skills.text.trim()),
      _reviewLine(Icons.description_outlined, 'JOB DESCRIPTION',
          _description.text.trim()),
      _reviewLine(Icons.fact_check_outlined, 'ACCOMMODATION REQUIRED',
          _accommodation ? 'Yes' : 'No'),
      _reviewLine(Icons.restaurant_outlined, 'FOOD PROVIDED', _food ? 'Yes' : 'No'),
      _reviewLine(Icons.directions_bus_outlined, 'TRANSPORT PROVIDED',
          _transport ? 'Yes' : 'No'),
      if (_other.text.trim().isNotEmpty)
        _reviewLine(Icons.notes_rounded, 'OTHER REQUIREMENTS',
            _other.text.trim()),
      const Divider(color: _P.border, height: 18),
      _budgetBanner(),
    ])),
    const SizedBox(height: 16),
    _hint(Icons.info_outline_rounded,
        'Once published, this job will be active and visible to eligible workers. Review all details before continuing.'),
  ]);

  Widget _hint(IconData icon, String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _P.field,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _P.border),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _P.muted, size: 18),
      const SizedBox(width: 9),
      Expanded(child: Text(message, style: const TextStyle(
        color: _P.muted, fontSize: 11, height: 1.5,
      ))),
    ]),
  );

  Widget _footer() => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
    decoration: BoxDecoration(
      color: _P.card,
      border: const Border(top: BorderSide(color: _P.border)),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 18, offset: const Offset(0, -6),
      )],
    ),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Row(children: [
        if (_step > 0) ...[
          Expanded(child: OutlinedButton(
            onPressed: _publishing ? null : _back,
            style: OutlinedButton.styleFrom(
              foregroundColor: _P.white,
              side: const BorderSide(color: _P.border),
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 12),
        ],
        Expanded(flex: 2, child: FilledButton(
          onPressed: _publishing ? null : (_step == 3 ? _publish : _next),
          style: FilledButton.styleFrom(
            backgroundColor: _P.coral, foregroundColor: Colors.white,
            disabledBackgroundColor: _P.coral.withOpacity(0.5),
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _publishing
              ? const SizedBox(width: 21, height: 21,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.4))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_step == 3 ? 'Publish job' : 'Continue',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(width: 9),
            Icon(_step == 3 ? Icons.rocket_launch_rounded :
            Icons.arrow_forward_rounded, size: 18),
          ]),
        )),
      ]),
    )),
  );
}
