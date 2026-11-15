import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:timetable_next/timetable_next.dart';

void main() => runApp(const CalendarApp());

const ink = Color(0xFF193147);
const accent = Color(0xFF087F83);

// 先转设备本地字段，再用 UTC 容器交给日历，保留微秒。
DateTime calendarTime(DateTime instant) {
  final local = instant.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  );
}

DateTime dateOnly(DateTime value) => DateTime.utc(value.year, value.month, value.day);
String hm(Duration time) =>
    '${time.inHours.toString().padLeft(2, '0')}:${(time.inMinutes % 60).toString().padLeft(2, '0')}';
String dayLabel(DateTime date) => '${date.month}月${date.day}日';
String stamp(DateTime date) => '${dayLabel(date)} ${hm(Duration(hours: date.hour, minutes: date.minute))}';

class Meeting extends Event {
  const Meeting(
    this.id,
    this.title,
    this.color, {
    required super.start,
    required super.end,
    this.allDay = false,
  });
  final String id;
  final String title;
  final Color color;
  final bool allDay;

  // 全天由业务明确给出，不按持续时长猜测。
  @override
  bool get isAllDay => allDay;
}

List<Meeting> demoMeetings(DateTime today) {
  final result = <Meeting>[];
  for (var offset = -21; offset < 42; offset++) {
    final date = today.add(Duration(days: offset));
    void add(String id, String title, int start, int end, Color color) {
      result.add(
        Meeting(
          '${date.toIso8601String()}-$id',
          title,
          color,
          start: date.add(Duration(minutes: start)),
          end: date.add(Duration(minutes: end)),
        ),
      );
    }

    add('sync', '晨会', 540, 600, const Color(0xFFD5ECEA));
    add('review', '评审', 570, 630, const Color(0xFFDFE5FA));
    add('design', '设计', 600, 660, const Color(0xFFFFE6CD));
    add('work', '项目讨论', 840, 900, const Color(0xFFD5ECEA));
    add('brief', '快速确认', 915, 920, const Color(0xFFDFE5FA));
    if (offset % 3 == 0) {
      add('night', '跨日值班', 1410, 1500, const Color(0xFFE2DEF8));
    }
  }
  result.add(
    Meeting(
      'release',
      '发布窗口',
      const Color(0xFFDCEEF7),
      start: today.subtract(const Duration(days: 1)),
      end: today.add(const Duration(days: 2)),
      allDay: true,
    ),
  );
  return List.unmodifiable(result);
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key, this.initialDate});
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      TimetableLocalizationsDelegate(),
      ...GlobalMaterialLocalizations.delegates,
    ],
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: accent),
      scaffoldBackgroundColor: const Color(0xFFF0F4F7),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF0F4F7), foregroundColor: ink),
    ),
    home: CalendarPage(initialDate: initialDate),
  );
}

enum CalendarMode { day, week, month }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late DateTime _focusedDate;
  late final DateController _dates;
  late final TimeController _times;
  late final AnimationController _fade;
  late final List<Meeting> _events;
  late final EventProvider<Meeting> _provider;
  Timer? _midnight;
  CalendarMode _mode = CalendarMode.week;
  int _operation = 0;
  bool _driving = false;
  int _clockRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final today = dateOnly(calendarTime(DateTime.now()));
    _focusedDate = dateOnly(widget.initialDate ?? today);
    _dates = DateController(
      initialDate: _focusedDate,
      visibleRange: VisibleDateRange.week(startOfWeek: DateTime.monday),
    );
    _times = TimeController(
      minDuration: const Duration(hours: 1),
      maxDuration: const Duration(days: 1),
      maxRange: TimeRange.fullDay,
      initialRange: TimeRange(const Duration(hours: 8), const Duration(hours: 18)),
    );
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 180), value: 1);
    _events = demoMeetings(today);
    _provider = eventProviderFromFixedList(_events);
    _dates.addListener(_readViewport);
    _scheduleMidnight();
  }

  void _readViewport() {
    if (_driving || _dates.value.activity is! IdleDateScrollActivity) return;
    final first = _dates.value.firstVisibleDate;
    final next = _mode == CalendarMode.week
        ? first.add(Duration(days: _focusedDate.weekday - DateTime.monday))
        : _dates.date.value;
    if (next != _focusedDate) setState(() => _focusedDate = next);
  }

  // 手指接管时，旧动画的完成回调也失去更新资格。
  void _takeOver() {
    _operation++;
    _dates.cancelAnimation();
    _times.cancelAnimation();
    _driving = false;
    _readViewport();
  }

  Future<void> _navigate(DateTime target, {CalendarMode? mode, TimeRange? timeRange}) async {
    final ticket = ++_operation;
    _driving = true;
    _dates.cancelAnimation();
    _times.cancelAnimation();
    final nextMode = mode ?? _mode;
    final changed = nextMode != _mode;
    setState(() {
      _mode = nextMode;
      _focusedDate = dateOnly(target);
    });
    _dates.visibleRange = nextMode == CalendarMode.week
        ? VisibleDateRange.week(startOfWeek: DateTime.monday)
        : VisibleDateRange.days(1);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (changed) {
      if (reduceMotion) {
        _fade.value = 1;
      } else {
        unawaited(_fade.forward(from: 0));
      }
    }
    if (reduceMotion) {
      _dates.jumpTo(_focusedDate);
      if (timeRange != null) _times.jumpTo(timeRange);
    } else {
      await Future.wait([
        _dates.animateTo(_focusedDate, vsync: this),
        if (timeRange != null) _times.animateTo(timeRange, vsync: this),
      ]);
    }
    if (!mounted || ticket != _operation) return;
    _driving = false;
    _readViewport();
  }

  void _zoom(TimeRange range) {
    _takeOver();
    if (MediaQuery.disableAnimationsOf(context)) {
      _times.jumpTo(range);
    } else {
      unawaited(_times.animateTo(range, vsync: this));
    }
  }

  void _now() {
    final now = calendarTime(DateTime.now());
    final center = Duration(
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    unawaited(
      _navigate(
        dateOnly(now),
        mode: _mode == CalendarMode.month ? CalendarMode.day : _mode,
        timeRange: TimeRange.centeredAround(center, _times.value.duration),
      ),
    );
  }

  void _step(int direction) {
    final target = _mode == CalendarMode.month
        ? DateTime.utc(_focusedDate.year, _focusedDate.month + direction)
        : _focusedDate.add(Duration(days: direction * (_mode == CalendarMode.week ? 7 : 1)));
    unawaited(_navigate(target));
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final local = DateTime.now();
    final next = DateTime(local.year, local.month, local.day + 1);
    _midnight = Timer(next.difference(local) + const Duration(milliseconds: 50), _refreshClock);
  }

  void _refreshClock() {
    if (!mounted) return;
    setState(() => _clockRevision++);
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshClock();
  }

  void _details(Meeting event) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Text(
                event.allDay
                    ? '全天 · ${dayLabel(event.start)}起'
                    : '${stamp(event.start)} — ${stamp(event.end)}',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventCard(Meeting event) => Material(
    color: event.color,
    borderRadius: BorderRadius.circular(5),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _details(event),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: ink),
        ),
      ),
    ),
  );

  Widget _monthView() {
    final events = _provider(_focusedDate.fullDayInterval);
    return Column(
      children: [
        CompactMonthTimetable(),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${dayLabel(_focusedDate)} · ${events.length}项日程',
                key: const ValueKey('agenda-title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => unawaited(_navigate(_focusedDate, mode: CalendarMode.day)),
                child: const Text('查看当天'),
              ),
            ],
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? const Center(child: Text('今天暂无日程'))
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final event = events[i];
                    return ListTile(
                      leading: Container(width: 5, height: 36, color: event.color),
                      title: Text(event.title),
                      subtitle: Text(event.allDay ? '全天' : '${stamp(event.start)} — ${stamp(event.end)}'),
                      onTap: () => _details(event),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('团队日历', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        TextButton.icon(onPressed: _now, icon: const Icon(Icons.my_location), label: const Text('现在')),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SegmentedButton<CalendarMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: CalendarMode.day, label: Text('日')),
                ButtonSegment(value: CalendarMode.week, label: Text('周')),
                ButtonSegment(value: CalendarMode.month, label: Text('月')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => unawaited(_navigate(_focusedDate, mode: value.single)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                IconButton(tooltip: '上一页', onPressed: () => _step(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _dates,
                    builder: (context, value, child) => Text(
                      _mode == CalendarMode.month
                          ? '${_focusedDate.year}年${_focusedDate.month}月'
                          : _mode == CalendarMode.day
                          ? dayLabel(_focusedDate)
                          : '${dayLabel(value.firstVisibleDate)} — '
                                '${dayLabel(value.firstVisibleDate.add(const Duration(days: 6)))}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: ink),
                    ),
                  ),
                ),
                IconButton(tooltip: '下一页', onPressed: () => _step(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          if (_mode != CalendarMode.month)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: [
                  for (final preset in [
                    ('全天', TimeRange.fullDay),
                    ('工作', TimeRange(const Duration(hours: 8), const Duration(hours: 18))),
                    ('上午', TimeRange(const Duration(hours: 8), const Duration(hours: 12))),
                  ]) ...[
                    OutlinedButton(onPressed: () => _zoom(preset.$2), child: Text(preset.$1)),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: '夜间',
                    onPressed: () => _zoom(TimeRange(const Duration(hours: 21), const Duration(hours: 24))),
                    icon: const Icon(Icons.nights_stay_outlined),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 暂无可用空间时不挂载内部视口，避免零尺寸初始化。
                    if (!constraints.hasBoundedHeight ||
                        !constraints.hasBoundedWidth ||
                        constraints.maxHeight < 300 ||
                        constraints.maxWidth < 160) {
                      return const Center(child: Text('请扩大日历窗口'));
                    }
                    return TimetableConfig<Meeting>(
                      dateController: _dates,
                      timeController: _times,
                      eventProvider: _provider,
                      eventBuilder: (context, event) => _eventCard(event),
                      allDayEventBuilder: (context, event, info) => InkWell(
                        onTap: () => _details(event),
                        child: Container(
                          color: event.color,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: ink),
                          ),
                        ),
                      ),
                      allDayOverflowBuilder: (context, date, events) =>
                          Text('+${events.length}', style: const TextStyle(fontSize: 11)),
                      callbacks: TimetableCallbacks(
                        onDateTap: (date) => unawaited(_navigate(date, mode: CalendarMode.day)),
                      ),
                      theme: TimetableThemeData(
                        context,
                        startOfWeek: DateTime.monday,
                        weekdayIndicatorStyleProvider: (date) => WeekdayIndicatorStyle(
                          context,
                          date,
                          label: const ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1],
                          textStyle: const TextStyle(fontSize: 12, color: ink),
                        ),
                        dateIndicatorStyleProvider: (date) => DateIndicatorStyle(
                          context,
                          date,
                          label: '${date.day}',
                          padding: const EdgeInsets.all(6),
                          textStyle: TextStyle(
                            fontSize: 14,
                            color: date == DateTimeTimetable.today() ? Colors.white : ink,
                          ),
                        ),
                        dateEventsStyleProvider: (date) => DateEventsStyle(
                          context,
                          date,
                          enableStacking: false,
                          minEventDuration: Duration.zero,
                          minEventHeight: 18,
                        ),
                        nowIndicatorStyle: NowIndicatorStyle(
                          context,
                          lineColor: const Color(0xFFD55350),
                          lineWidth: 1.5,
                        ),
                      ),
                      child: Listener(
                        onPointerDown: (_) => _takeOver(),
                        child: FadeTransition(
                          opacity: _fade.drive(Tween(begin: .55, end: 1.0)),
                          child: _mode == CalendarMode.month
                              ? _monthView()
                              : MultiDateTimetable<Meeting>(
                                  key: ValueKey(_clockRevision),
                                  // 首帧就固定时间栏宽度，标题与内容共用同一基准。
                                  headerBuilder: (context, _) => SizedBox(
                                    height: 140,
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          height: 92,
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 52),
                                              Expanded(
                                                child: DatePageView(
                                                  controller: _dates,
                                                  builder: (context, date) => DateHeader(date),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height: 48,
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 52),
                                              Expanded(child: MultiDateEventHeader<Meeting>()),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  contentLeading: SizedBox(
                                    width: 52,
                                    child: TimeZoom(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: TimeIndicators.hours(),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _operation++;
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _dates.removeListener(_readViewport);
    _dates.dispose();
    _times.dispose();
    _fade.dispose();
    super.dispose();
  }
}
