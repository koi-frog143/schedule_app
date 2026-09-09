import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

// ==========================================
// 1. MODEL
// ==========================================
class ClassReminder {
  final int minutesBefore;
  final bool isAlarm; // true = audible alarm sound + vibration, false = silent push notification

  const ClassReminder({
    required this.minutesBefore,
    this.isAlarm = true,
  });

  String get label {
    if (minutesBefore >= 60) {
      final hours = minutesBefore ~/ 60;
      final remainingMins = minutesBefore % 60;
      return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
    }
    return '${minutesBefore}m';
  }

  Map<String, dynamic> toJson() => {
    'minutesBefore': minutesBefore,
    'isAlarm': isAlarm,
  };

  factory ClassReminder.fromJson(Map<String, dynamic> json) => ClassReminder(
    minutesBefore: json['minutesBefore'] ?? 15,
    isAlarm: json['isAlarm'] ?? true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassReminder &&
          runtimeType == other.runtimeType &&
          minutesBefore == other.minutesBefore &&
          isAlarm == other.isAlarm;

  @override
  int get hashCode => Object.hash(minutesBefore, isAlarm);
}

class CourseClass {
  final String id;
  final String title;
  final String room;
  final int dayOfWeek; // 1 = Mon, 2 = Tue, ..., 7 = Sun
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int colorValue;
  final String? imagePath;
  final List<ClassReminder> reminders;

  CourseClass({
    required this.id,
    required this.title,
    required this.room,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.colorValue,
    this.imagePath,
    List<ClassReminder>? reminders,
    int? reminderMinutes,
    bool? playAlarmSound,
  }) : reminders = reminders ??
            (reminderMinutes != null && reminderMinutes > 0
                ? [ClassReminder(minutesBefore: reminderMinutes, isAlarm: playAlarmSound ?? true)]
                : (reminderMinutes == 0
                    ? []
                    : [const ClassReminder(minutesBefore: 15, isAlarm: true)]));

  // Backward compatibility getters
  int get reminderMinutes =>
      reminders.isNotEmpty ? reminders.first.minutesBefore : 0;
  bool get playAlarmSound =>
      reminders.isNotEmpty ? reminders.first.isAlarm : true;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'room': room,
    'dayOfWeek': dayOfWeek,
    'startHour': startHour,
    'startMinute': startMinute,
    'endHour': endHour,
    'endMinute': endMinute,
    'colorValue': colorValue,
    'imagePath': imagePath,
    'reminders': reminders.map((r) => r.toJson()).toList(),
    'reminderMinutes': reminderMinutes,
    'playAlarmSound': playAlarmSound,
  };

  factory CourseClass.fromJson(Map<String, dynamic> json) {
    List<ClassReminder> parsedReminders = [];
    if (json['reminders'] != null) {
      parsedReminders = (json['reminders'] as List)
          .map((r) => ClassReminder.fromJson(r as Map<String, dynamic>))
          .toList();
    } else if (json['reminderMinutes'] != null) {
      final int oldMins = json['reminderMinutes'] as int;
      final bool oldAlarm = json['playAlarmSound'] as bool? ?? true;
      if (oldMins > 0) {
        parsedReminders = [ClassReminder(minutesBefore: oldMins, isAlarm: oldAlarm)];
      }
    } else {
      parsedReminders = [const ClassReminder(minutesBefore: 15, isAlarm: true)];
    }

    return CourseClass(
      id: json['id'],
      title: json['title'],
      room: json['room'] ?? '',
      dayOfWeek: json['dayOfWeek'],
      startHour: json['startHour'],
      startMinute: json['startMinute'],
      endHour: json['endHour'],
      endMinute: json['endMinute'],
      colorValue: json['colorValue'] ?? 0xFFD6E8FA,
      imagePath: json['imagePath'],
      reminders: parsedReminders,
    );
  }

  String get startTimeFormatted =>
      DateFormat('h:mm a').format(DateTime(2026, 1, 1, startHour, startMinute));

  String get endTimeFormatted =>
      DateFormat('h:mm a').format(DateTime(2026, 1, 1, endHour, endMinute));
}

// ==========================================
// 2. LOCAL FILE SYSTEM DATABASE
// ==========================================
class ScheduleStorage {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/schedule_data.json');
  }

  static Future<List<CourseClass>> loadClasses() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        // Return default sample courses inspired by Folderly layout
        return [
          CourseClass(
            id: '1',
            title: 'CMSC 161',
            room: 'Lab 301',
            dayOfWeek: 1, // Mon
            startHour: 7,
            startMinute: 30,
            endHour: 9,
            endMinute: 0,
            colorValue: 0xFFD6E8FA, // pastel blue
          ),
          CourseClass(
            id: '2',
            title: 'CALCULUS',
            room: 'Room 204',
            dayOfWeek: 1, // Mon
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 30,
            colorValue: 0xFFFFF8C9, // pastel yellow
          ),
          CourseClass(
            id: '3',
            title: 'ARTS',
            room: 'Hall B',
            dayOfWeek: 2, // Tue
            startHour: 7,
            startMinute: 30,
            endHour: 9,
            endMinute: 0,
            colorValue: 0xFFFCE2E6, // pastel pink
          ),
          CourseClass(
            id: '4',
            title: 'BIOLOGY',
            room: 'Science Lab',
            dayOfWeek: 2, // Tue
            startHour: 10,
            startMinute: 30,
            endHour: 12,
            endMinute: 0,
            colorValue: 0xFFD8F3DC, // pastel green
          ),
          CourseClass(
            id: '5',
            title: 'ENGLISH',
            room: 'Room 102',
            dayOfWeek: 3, // Wed
            startHour: 9,
            startMinute: 0,
            endHour: 11,
            endMinute: 0,
            colorValue: 0xFFE8E0F8, // pastel lavender
          ),
          CourseClass(
            id: '6',
            title: 'RESEARCH',
            room: 'Library',
            dayOfWeek: 4, // Thu
            startHour: 11,
            startMinute: 0,
            endHour: 12,
            endMinute: 30,
            colorValue: 0xFFFFE5D9, // pastel peach
          ),
        ];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonData = jsonDecode(contents);
      return jsonData.map((item) => CourseClass.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveClasses(List<CourseClass> classes) async {
    final file = await _getFile();
    final data = jsonEncode(classes.map((c) => c.toJson()).toList());
    await file.writeAsString(data, flush: true);
  }
}

// ==========================================
// 3. NOTIFICATION SERVICE
// ==========================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String alarmChannelId = 'class_alarms_channel_v2';
  static const String silentChannelId = 'class_silent_channel_v2';

  static Future<void> init() async {
    // 1. Initialize Timezones using actual device local timezone
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Error getting device local timezone: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification clicked: ${details.payload}');
      },
    );

    // 2. Register Android Notification Channels
    const alarmChannel = AndroidNotificationChannel(
      alarmChannelId,
      'Class Alarms',
      description: 'Audible alarms and high-priority reminders for upcoming classes',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    const silentChannel = AndroidNotificationChannel(
      silentChannelId,
      'Silent Class Reminders',
      description: 'Silent notifications for upcoming courses',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(alarmChannel);
    await androidImplementation?.createNotificationChannel(silentChannel);
  }

  /// Request runtime permissions for notifications and exact alarms
  static Future<bool> requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) return true;

    // 1. Request POST_NOTIFICATIONS (Android 13+)
    final notifGranted = await androidImplementation.requestNotificationsPermission();

    // 2. Request Exact Alarm permission (Android 12/13/14+)
    final canScheduleExact =
        await androidImplementation.canScheduleExactNotifications() ?? false;
    if (!canScheduleExact) {
      await androidImplementation.requestExactAlarmsPermission();
    }

    // 3. Request Full Screen Intent permission (Android 14+)
    await androidImplementation.requestFullScreenIntentPermission();

    return notifGranted ?? true;
  }

  static Future<void> scheduleCourseAlarm(CourseClass course) async {
    // Cancel any existing alarms/notifications for this course
    await cancelAlarm(course.id);

    if (course.reminders.isEmpty) {
      return;
    }

    for (final reminder in course.reminders) {
      if (reminder.minutesBefore <= 0) continue;

      final int notificationId = Object.hash(course.id, reminder.minutesBefore);

      final reminderTime = _nextInstanceOfReminder(
        course.dayOfWeek,
        course.startHour,
        course.startMinute,
        reminder.minutesBefore,
      );

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          reminder.isAlarm ? alarmChannelId : silentChannelId,
          reminder.isAlarm ? 'Class Alarms' : 'Silent Class Reminders',
          channelDescription: reminder.isAlarm
              ? 'Audible alarms and high-priority reminders for upcoming courses'
              : 'Silent notifications for upcoming courses',
          importance: reminder.isAlarm ? Importance.max : Importance.defaultImportance,
          priority: reminder.isAlarm ? Priority.max : Priority.defaultPriority,
          playSound: reminder.isAlarm,
          enableVibration: reminder.isAlarm,
          audioAttributesUsage: reminder.isAlarm
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          category: reminder.isAlarm
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.reminder,
          fullScreenIntent: reminder.isAlarm,
          visibility: NotificationVisibility.public,
        ),
      );

      final String prefix = reminder.isAlarm ? 'Alarm' : 'Reminder';
      final scheduleMode = reminder.isAlarm
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.exactAllowWhileIdle;

      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '[$prefix] Upcoming Class: ${course.title}',
          'Starts in ${reminder.minutesBefore} mins at ${course.startTimeFormatted} (${course.room.isNotEmpty ? course.room : "No Room"})',
          reminderTime,
          notificationDetails,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('Error scheduling with primary mode ($scheduleMode): $e. Attempting fallback...');
        try {
          await _notificationsPlugin.zonedSchedule(
            notificationId,
            '[$prefix] Upcoming Class: ${course.title}',
            'Starts in ${reminder.minutesBefore} mins at ${course.startTimeFormatted} (${course.room.isNotEmpty ? course.room : "No Room"})',
            reminderTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e2) {
          debugPrint('Fallback exact schedule failed: $e2. Using inexactAllowWhileIdle.');
          await _notificationsPlugin.zonedSchedule(
            notificationId,
            '[$prefix] Upcoming Class: ${course.title}',
            'Starts in ${reminder.minutesBefore} mins at ${course.startTimeFormatted} (${course.room.isNotEmpty ? course.room : "No Room"})',
            reminderTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    }
  }

  /// Sends an immediate test alert so the user can verify system alarms and notifications
  static Future<void> sendTestNotification({required bool isAlarm}) async {
    await requestPermissions();

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        isAlarm ? alarmChannelId : silentChannelId,
        isAlarm ? 'Class Alarms' : 'Silent Class Reminders',
        channelDescription: isAlarm
            ? 'Audible alarms and high-priority reminders for upcoming courses'
            : 'Silent notifications for upcoming courses',
        importance: isAlarm ? Importance.max : Importance.defaultImportance,
        priority: isAlarm ? Priority.max : Priority.defaultPriority,
        playSound: isAlarm,
        enableVibration: isAlarm,
        audioAttributesUsage: isAlarm
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        category: isAlarm
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        fullScreenIntent: isAlarm,
        visibility: NotificationVisibility.public,
      ),
    );

    await _notificationsPlugin.show(
      888888,
      isAlarm ? '[Alarm Test] Class Alarm Sound' : '[Push Test] Silent Push Notification',
      isAlarm
          ? 'System alarm is connected! Sound, vibration, and alarm channel verified.'
          : 'Push notification is connected! Visual heads-up banner verified.',
      notificationDetails,
    );
  }

  static tz.TZDateTime _nextInstanceOfReminder(
      int classDayOfWeek, int startHour, int startMinute, int reminderMinutes) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime classTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );

    while (classTime.weekday != classDayOfWeek) {
      classTime = classTime.add(const Duration(days: 1));
    }

    tz.TZDateTime reminderTime =
        classTime.subtract(Duration(minutes: reminderMinutes));

    if (reminderTime.isBefore(now)) {
      classTime = classTime.add(const Duration(days: 7));
      reminderTime = classTime.subtract(Duration(minutes: reminderMinutes));
    }

    return reminderTime;
  }

  static Future<void> cancelAlarm(String courseId) async {
    await _notificationsPlugin.cancel(courseId.hashCode);
    // Cancel potential reminder minute hash IDs
    for (final mins in [5, 10, 15, 30, 45, 60, 120]) {
      await _notificationsPlugin.cancel(Object.hash(courseId, mins));
    }
  }
}

// ==========================================
// 4. MAIN ENTRY POINT
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const FolderlyScheduleApp());
}

class FolderlyScheduleApp extends StatelessWidget {
  const FolderlyScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Schedule',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'serif',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF9E79)),
        textTheme: _buildTightenedTextTheme(
          ThemeData.light().textTheme.apply(
            fontFamily: 'serif',
            fontFamilyFallback: const ['Cambria', 'serif'],
          ),
        ),
      ),
      home: const ScheduleHomeScreen(),
    );
  }

  static TextTheme _buildTightenedTextTheme(TextTheme base) {
    TextStyle tighten(TextStyle? style) {
      final baseStyle = style ?? const TextStyle();
      return baseStyle.copyWith(
        fontFamily: 'serif',
        fontFamilyFallback: const ['Cambria', 'serif'],
        letterSpacing: (baseStyle.letterSpacing ?? 0.0) - 0.3,
      );
    }

    return base.copyWith(
      displayLarge: tighten(base.displayLarge),
      displayMedium: tighten(base.displayMedium),
      displaySmall: tighten(base.displaySmall),
      headlineLarge: tighten(base.headlineLarge),
      headlineMedium: tighten(base.headlineMedium),
      headlineSmall: tighten(base.headlineSmall),
      titleLarge: tighten(base.titleLarge),
      titleMedium: tighten(base.titleMedium),
      titleSmall: tighten(base.titleSmall),
      bodyLarge: tighten(base.bodyLarge),
      bodyMedium: tighten(base.bodyMedium),
      bodySmall: tighten(base.bodySmall),
      labelLarge: tighten(base.labelLarge),
      labelMedium: tighten(base.labelMedium),
      labelSmall: tighten(base.labelSmall),
    );
  }
}

// ==========================================
// 5. HOME SCREEN
// ==========================================
class ScheduleHomeScreen extends StatefulWidget {
  const ScheduleHomeScreen({super.key});

  @override
  State<ScheduleHomeScreen> createState() => _ScheduleHomeScreenState();
}

class _ScheduleHomeScreenState extends State<ScheduleHomeScreen> {
  List<CourseClass> _allCourses = [];
  int _selectedDay = DateTime.now().weekday; // 1 = Mon, 7 = Sun
  bool _isLoading = true;

  final List<String> _weekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final courses = await ScheduleStorage.loadClasses();
    setState(() {
      _allCourses = courses;
      _isLoading = false;
    });
    await NotificationService.requestPermissions();
    _rescheduleAllNotifications();
    _syncToHomeWidget();
  }

  Future<void> _saveCourses() async {
    await ScheduleStorage.saveClasses(_allCourses);
    _rescheduleAllNotifications();
    _syncToHomeWidget();
  }

  void _rescheduleAllNotifications() async {
    for (var course in _allCourses) {
      await NotificationService.scheduleCourseAlarm(course);
    }
  }

  // Returns current active class or next upcoming class for today
  CourseClass? _getCurrentOrNextClassForToday() {
    final now = DateTime.now();
    final today = now.weekday;
    final todayCourses = _allCourses.where((c) => c.dayOfWeek == today).toList()
      ..sort((a, b) =>
          (a.startHour * 60 + a.startMinute).compareTo(b.startHour * 60 + b.startMinute));

    for (var c in todayCourses) {
      final classEndToday =
          DateTime(now.year, now.month, now.day, c.endHour, c.endMinute);
      if (now.isBefore(classEndToday)) {
        return c;
      }
    }
    return todayCourses.isNotEmpty ? todayCourses.first : null;
  }

  // Push updates to Android Native Home Screen Widget
  Future<void> _syncToHomeWidget() async {
    try {
      final currentClass = _getCurrentOrNextClassForToday();
      final now = DateTime.now();
      bool isActive = false;
      if (currentClass != null) {
        final startToday = DateTime(now.year, now.month, now.day,
            currentClass.startHour, currentClass.startMinute);
        final endToday = DateTime(now.year, now.month, now.day,
            currentClass.endHour, currentClass.endMinute);
        if (now.isAfter(startToday) && now.isBefore(endToday)) {
          isActive = true;
        }
      }

      await HomeWidget.saveWidgetData<String>(
          'widget_title', currentClass?.title ?? 'No Class');
      await HomeWidget.saveWidgetData<String>(
          'widget_time',
          currentClass != null
              ? '${currentClass.startTimeFormatted} - ${currentClass.endTimeFormatted}'
              : 'Free Time');
      await HomeWidget.saveWidgetData<String>(
          'widget_room',
          currentClass != null
              ? (currentClass.room.isNotEmpty ? currentClass.room : 'Scheduled')
              : 'Free Time');
      await HomeWidget.saveWidgetData<String>(
          'widget_start_time', currentClass?.startTimeFormatted ?? '00:00');
      await HomeWidget.saveWidgetData<String>(
          'widget_end_time', currentClass?.endTimeFormatted ?? '00:00');
      await HomeWidget.saveWidgetData<String>(
          'widget_image_path', currentClass?.imagePath ?? '');
      await HomeWidget.saveWidgetData<bool>(
          'widget_is_active', isActive);

      await HomeWidget.updateWidget(
        name: 'ScheduleWidgetProvider',
        androidName: 'ScheduleWidgetProvider',
      );
    } catch (_) {
      // HomeWidget runs safely even if native files aren't compiled yet
    }
  }

  CourseClass? _getNextClass() {
    final now = DateTime.now();
    final dayCourses = _allCourses.where((c) => c.dayOfWeek == _selectedDay).toList()
      ..sort((a, b) =>
          (a.startHour * 60 + a.startMinute).compareTo(b.startHour * 60 + b.startMinute));

    if (_selectedDay == now.weekday) {
      for (var c in dayCourses) {
        final classEndToday =
            DateTime(now.year, now.month, now.day, c.endHour, c.endMinute);
        if (now.isBefore(classEndToday)) {
          return c;
        }
      }
    }
    return dayCourses.isNotEmpty ? dayCourses.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final nextClass = _getNextClass();
    final dayClasses = _allCourses.where((c) => c.dayOfWeek == _selectedDay).toList()
      ..sort((a, b) =>
          (a.startHour * 60 + a.startMinute).compareTo(b.startHour * 60 + b.startMinute));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFFEEDB), Color(0xFFFFDAB9)],
            stops: [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const SizedBox(height: 12),
                    // Header Bar
                    _buildHeader(context),
                    const SizedBox(height: 14),

                    // Retro iPod Classic / Folderly Style Widget Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildIpodWidgetCard(nextClass),
                    ),

                    const SizedBox(height: 20),

                    // Day of Week Selector Pills
                    _buildDaySelector(),

                    const SizedBox(height: 12),

                    // Main Timetable / Classes List
                    Expanded(
                      child: dayClasses.isEmpty
                          ? Center(
                              child: Text(
                                'No classes for ${_weekDays[_selectedDay - 1]} 🎉',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              itemCount: dayClasses.length,
                              itemBuilder: (context, index) {
                                return _buildClassTimelineCard(dayClasses[index]);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

// --- Header ---
  Widget _buildHeader(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Class Schedule',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.3,
                  color: Color(0xFF232323),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontFamily: 'sans-serif',
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 30, color: Color(0xFF333333)),
            onPressed: () => _showAddEditClassDialog(),
          ),
        ],
      ),
    );
  }

  // --- Folderly Signature iPod Classic Top Widget ---
  Widget _buildIpodWidgetCard(CourseClass? nextClass) {
    final now = DateTime.now();
    bool isNowActive = false;
    double progress = 0.0;
    if (nextClass != null) {
      final start = DateTime(now.year, now.month, now.day, nextClass.startHour, nextClass.startMinute);
      final end = DateTime(now.year, now.month, now.day, nextClass.endHour, nextClass.endMinute);
      if (now.isAfter(start) && now.isBefore(end)) {
        isNowActive = true;
        final totalMs = end.difference(start).inMilliseconds;
        final currentMs = now.difference(start).inMilliseconds;
        progress = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;
      }
    }

    final customImagePath = nextClass?.imagePath;
    final hasCustomImage = customImagePath != null &&
        File(customImagePath).existsSync();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E4E8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          const BoxShadow(
            color: Colors.white70,
            blurRadius: 4,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Side: iPod LCD Screen
          Expanded(
            flex: 6,
            child: Container(
              height: 124,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2D30), width: 2.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LCD Top Status Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isNowActive
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                      Text(
                        isNowActive
                            ? 'NOW ACTIVE'
                            : (nextClass != null ? 'UPCOMING' : 'NO CLASS'),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontFamily: 'sans-serif',
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Icon(Icons.battery_3_bar, size: 14, color: Colors.black54),
                    ],
                  ),

                  // Center Content
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: nextClass != null
                              ? Color(nextClass.colorValue)
                              : const Color(0xFFEAEAEA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: hasCustomImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.file(
                                  File(customImagePath),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.menu_book_rounded,
                                color: Colors.black.withValues(alpha: 0.55),
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextClass?.title ?? 'No Class',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                            Text(
                              nextClass != null
                                  ? (nextClass.room.isNotEmpty
                                      ? nextClass.room
                                      : 'Scheduled')
                                  : 'Free Time',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bottom Audio Progress Bar
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: isNowActive ? progress : (nextClass != null ? 0.3 : 0.0),
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF333333)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            nextClass?.startTimeFormatted ?? '00:00',
                            style: const TextStyle(
                                fontSize: 9,
                                fontFamily: 'sans-serif',
                                color: Colors.black54),
                          ),
                          Text(
                            nextClass?.endTimeFormatted ?? '00:00',
                            style: const TextStyle(
                                fontSize: 9,
                                fontFamily: 'sans-serif',
                                color: Colors.black54),
                          ),
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right Side: iPod Classic Click Wheel
          Expanded(
            flex: 4,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF9F9F9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 6,
                      child: Text('MENU',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'sans-serif',
                              color: Colors.grey)),
                    ),
                    const Positioned(
                      left: 6,
                      child: Icon(Icons.fast_rewind, size: 14, color: Colors.grey),
                    ),
                    const Positioned(
                      right: 6,
                      child: Icon(Icons.fast_forward, size: 14, color: Colors.grey),
                    ),
                    const Positioned(
                      bottom: 6,
                      child: Icon(Icons.play_arrow, size: 14, color: Colors.grey),
                    ),
                    // Center Button
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Synced schedule to home widget!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        _syncToHomeWidget();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE4E6EA),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Day Selector with Folderly Yellow Oval Pill ---
  Widget _buildDaySelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dayNum = index + 1;
          final isSelected = dayNum == _selectedDay;

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = dayNum),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFDE59) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: Colors.black, width: 1.4)
                    : Border.all(color: Colors.transparent),
              ),
              child: Center(
                child: Text(
                  _weekDays[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.grey.shade600,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Aesthetic Pastel Timetable Card ---
  Widget _buildClassTimelineCard(CourseClass course) {
    return Dismissible(
      key: Key(course.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        NotificationService.cancelAlarm(course.id);
        setState(() {
          _allCourses.removeWhere((c) => c.id == course.id);
        });
        _saveCourses();
      },
      child: GestureDetector(
        onTap: () => _showAddEditClassDialog(classToEdit: course),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Color(course.colorValue),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.85), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top start time
              Text(
                course.startTimeFormatted,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'sans-serif',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // Center Subject
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (course.imagePath != null &&
                            File(course.imagePath!).existsSync()) ...[
                          Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: Colors.black26, width: 1.2),
                              image: DecorationImage(
                                image: FileImage(File(course.imagePath!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            course.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'sans-serif',
                              letterSpacing: -0.2,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (course.room.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        course.room,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'sans-serif',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Bottom end time
              Text(
                course.endTimeFormatted,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'sans-serif',
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Add / Edit Subject Modal ---
  void _showAddEditClassDialog({CourseClass? classToEdit}) {
    final titleController = TextEditingController(text: classToEdit?.title ?? '');
    final roomController = TextEditingController(text: classToEdit?.room ?? '');
    int selectedDay = classToEdit?.dayOfWeek ?? _selectedDay;
    TimeOfDay startTime = classToEdit != null
        ? TimeOfDay(hour: classToEdit.startHour, minute: classToEdit.startMinute)
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = classToEdit != null
        ? TimeOfDay(hour: classToEdit.endHour, minute: classToEdit.endMinute)
        : const TimeOfDay(hour: 9, minute: 30);
    int selectedColor = classToEdit?.colorValue ?? 0xFFD6E8FA;
    String? selectedImagePath = classToEdit?.imagePath;
    List<ClassReminder> selectedReminders = classToEdit != null
        ? List<ClassReminder>.from(classToEdit.reminders)
        : [const ClassReminder(minutesBefore: 15, isAlarm: true)];
    bool isReminderDropdownOpen = false;

    final List<int> pastelPalette = [
      0xFFD6E8FA, // Light Blue
      0xFFFCE2E6, // Pastel Pink
      0xFFFFF8C9, // Pastel Yellow
      0xFFD8F3DC, // Pastel Green
      0xFFE8E0F8, // Soft Purple
      0xFFFFE5D9, // Peach
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF9F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
          final viewPaddingBottom = MediaQuery.of(context).viewPadding.bottom;
          // Position directly on top of system navigation bar with clean 8dp spacing
          final bottomPadding = viewInsetsBottom > 0
              ? viewInsetsBottom + 12
              : viewPaddingBottom + 8;

          Future<void> pickGalleryImage() async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 800,
                maxHeight: 800,
                imageQuality: 85,
              );
              if (picked != null) {
                final appDir = await getApplicationDocumentsDirectory();
                final imgDir = Directory('${appDir.path}/subject_images');
                if (!await imgDir.exists()) {
                  await imgDir.create(recursive: true);
                }
                final filename = 'subj_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final savedImage =
                    await File(picked.path).copy('${imgDir.path}/$filename');
                setModalState(() {
                  selectedImagePath = savedImage.path;
                });
              }
            } catch (e) {
              debugPrint('Error picking image: $e');
            }
          }

          final hasValidImage = selectedImagePath != null &&
              File(selectedImagePath!).existsSync();

          return Padding(
            padding: EdgeInsets.only(
              bottom: bottomPadding,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Dialog Title
                    Text(
                      classToEdit == null ? 'Add Subject' : 'Edit Subject',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        color: Color(0xFF232323),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Gallery Profile Picture Picker
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: pickGalleryImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 74,
                                  height: 74,
                                  decoration: BoxDecoration(
                                    color: Color(selectedColor).withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black26,
                                      width: 2,
                                    ),
                                    image: hasValidImage
                                        ? DecorationImage(
                                            image: FileImage(
                                                File(selectedImagePath!)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: !hasValidImage
                                      ? const Icon(
                                          Icons.add_photo_alternate_rounded,
                                          size: 32,
                                          color: Color(0xFF444444),
                                        )
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF232323),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF333333),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                                icon: const Icon(Icons.photo_library_outlined,
                                    size: 16),
                                label: Text(
                                  !hasValidImage
                                      ? 'Select Picture from Gallery'
                                      : 'Change Picture',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                onPressed: pickGalleryImage,
                              ),
                              if (hasValidImage) ...[
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.redAccent),
                                  tooltip: 'Remove picture',
                                  onPressed: () {
                                    setModalState(() {
                                      selectedImagePath = null;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Course / Subject Name (e.g. CMSC 161)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: roomController,
                      decoration: InputDecoration(
                        labelText: 'Room / Building (e.g. Lab 301)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Day selector in modal
                    DropdownButtonFormField<int>(
                      initialValue: selectedDay,
                      decoration: InputDecoration(
                        labelText: 'Day of Week',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: List.generate(7, (idx) {
                        return DropdownMenuItem(
                          value: idx + 1,
                          child: Text(_weekDays[idx]),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                  context: context, initialTime: startTime);
                              if (picked != null) {
                                setModalState(() => startTime = picked);
                              }
                            },
                            child: Text('Start: ${startTime.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                  context: context, initialTime: endTime);
                              if (picked != null) {
                                setModalState(() => endTime = picked);
                              }
                            },
                            child: Text('End: ${endTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Reminders & Alarms Multi-Select Dropdown
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isReminderDropdownOpen
                              ? const Color(0xFF232323)
                              : Colors.black26,
                          width: isReminderDropdownOpen ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isReminderDropdownOpen
                            ? Colors.black.withValues(alpha: 0.02)
                            : Colors.transparent,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropdown clickable header
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setModalState(() {
                                isReminderDropdownOpen = !isReminderDropdownOpen;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    selectedReminders.any((r) => r.isAlarm)
                                        ? Icons.alarm_on_rounded
                                        : (selectedReminders.isNotEmpty
                                            ? Icons.notifications_active_outlined
                                            : Icons.notifications_off_outlined),
                                    size: 20,
                                    color: const Color(0xFF232323),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reminders & Alarms',
                                          style: TextStyle(
                                            fontFamily: 'serif',
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          selectedReminders.isEmpty
                                              ? 'No reminders (Tap to select)'
                                              : selectedReminders
                                                  .map((r) =>
                                                      '${r.label} (${r.isAlarm ? "Alarm" : "Push"})')
                                                  .join(', '),
                                          style: TextStyle(
                                            fontFamily: 'serif',
                                            fontSize: 13,
                                            color: selectedReminders.isEmpty
                                                ? Colors.grey.shade600
                                                : const Color(0xFF232323),
                                            fontWeight:
                                                selectedReminders.isEmpty
                                                    ? FontWeight.normal
                                                    : FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isReminderDropdownOpen
                                        ? Icons.arrow_drop_up_rounded
                                        : Icons.arrow_drop_down_rounded,
                                    color: const Color(0xFF232323),
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Expanded Dropdown Content
                          if (isReminderDropdownOpen) ...[
                            const Divider(height: 1, color: Colors.black12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Choose reminder timings & sound options:',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...[
                                    {'label': '5 mins before', 'mins': 5},
                                    {'label': '10 mins before', 'mins': 10},
                                    {'label': '15 mins before', 'mins': 15},
                                    {'label': '30 mins before', 'mins': 30},
                                    {'label': '1 hour before', 'mins': 60},
                                  ].map((item) {
                                    final mins = item['mins'] as int;
                                    final label = item['label'] as String;
                                    final existing = selectedReminders
                                        .where((r) => r.minutesBefore == mins)
                                        .firstOrNull;
                                    final isSelected = existing != null;

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF232323)
                                                .withValues(alpha: 0.05)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: isSelected,
                                              activeColor:
                                                  const Color(0xFF232323),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              onChanged: (checked) {
                                                setModalState(() {
                                                  if (checked == true) {
                                                    selectedReminders.add(
                                                        ClassReminder(
                                                            minutesBefore: mins,
                                                            isAlarm: true));
                                                    selectedReminders.sort(
                                                        (a, b) => b.minutesBefore
                                                            .compareTo(a
                                                                .minutesBefore));
                                                  } else {
                                                    selectedReminders
                                                        .removeWhere((r) =>
                                                            r.minutesBefore ==
                                                            mins);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setModalState(() {
                                                  if (isSelected) {
                                                    selectedReminders
                                                        .removeWhere((r) =>
                                                            r.minutesBefore ==
                                                            mins);
                                                  } else {
                                                    selectedReminders.add(
                                                        ClassReminder(
                                                            minutesBefore: mins,
                                                            isAlarm: true));
                                                    selectedReminders.sort(
                                                        (a, b) => b.minutesBefore
                                                            .compareTo(a
                                                                .minutesBefore));
                                                  }
                                                });
                                              },
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  fontFamily: 'serif',
                                                  fontSize: 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color:
                                                      const Color(0xFF232323),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Alarm pill
                                                GestureDetector(
                                                  onTap: () {
                                                    setModalState(() {
                                                      final idx =
                                                          selectedReminders
                                                              .indexWhere((r) =>
                                                                  r.minutesBefore ==
                                                                  mins);
                                                      if (idx != -1) {
                                                        selectedReminders[
                                                            idx] = ClassReminder(
                                                          minutesBefore: mins,
                                                          isAlarm: true,
                                                        );
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: existing.isAlarm
                                                          ? const Color(
                                                              0xFF232323)
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color: existing.isAlarm
                                                            ? const Color(
                                                                0xFF232323)
                                                            : Colors.black26,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.alarm,
                                                          size: 13,
                                                          color: existing
                                                                  .isAlarm
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF232323),
                                                        ),
                                                        const SizedBox(
                                                            width: 3),
                                                        Text(
                                                          'Alarm',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'serif',
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: existing
                                                                    .isAlarm
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFF232323),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                // Push notification pill
                                                GestureDetector(
                                                  onTap: () {
                                                    setModalState(() {
                                                      final idx =
                                                          selectedReminders
                                                              .indexWhere((r) =>
                                                                  r.minutesBefore ==
                                                                  mins);
                                                      if (idx != -1) {
                                                        selectedReminders[
                                                            idx] = ClassReminder(
                                                          minutesBefore: mins,
                                                          isAlarm: false,
                                                        );
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: !existing.isAlarm
                                                          ? const Color(
                                                              0xFF232323)
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color: !existing.isAlarm
                                                            ? const Color(
                                                                0xFF232323)
                                                            : Colors.black26,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .notifications_outlined,
                                                          size: 13,
                                                          color: !existing
                                                                  .isAlarm
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF232323),
                                                        ),
                                                        const SizedBox(
                                                            width: 3),
                                                        Text(
                                                          'Push',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'serif',
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: !existing
                                                                    .isAlarm
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFF232323),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    );
                                   }),
                                  const SizedBox(height: 6),
                                  const Divider(height: 1, color: Colors.black12),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF232323),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.alarm_on,
                                            size: 15),
                                        label: const Text('Test Alarm Sound',
                                            style: TextStyle(
                                                fontFamily: 'serif',
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          await NotificationService
                                              .sendTestNotification(
                                                  isAlarm: true);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Triggered test alarm! Check notification & sound.'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Colors.grey.shade700,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 4),
                                        ),
                                        icon: const Icon(
                                            Icons.notifications_none,
                                            size: 15),
                                        label: const Text('Test Push',
                                            style: TextStyle(
                                                fontFamily: 'serif',
                                                fontSize: 12)),
                                        onPressed: () async {
                                          await NotificationService
                                              .sendTestNotification(
                                                  isAlarm: false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Triggered test push notification!'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pastel color options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: pastelPalette.map((colorVal) {
                        final isChosen = selectedColor == colorVal;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedColor = colorVal),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isChosen ? Colors.black : Colors.black26,
                                width: isChosen ? 2.5 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),

                    // Save Button with plenty of breathing room
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF232323),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (titleController.text.trim().isEmpty) return;
                          final updated = CourseClass(
                            id: classToEdit?.id ??
                                DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleController.text.trim(),
                            room: roomController.text.trim(),
                            dayOfWeek: selectedDay,
                            startHour: startTime.hour,
                            startMinute: startTime.minute,
                            endHour: endTime.hour,
                            endMinute: endTime.minute,
                            colorValue: selectedColor,
                            imagePath: selectedImagePath,
                            reminders: selectedReminders,
                          );

                          setState(() {
                            if (classToEdit != null) {
                              final idx = _allCourses.indexWhere(
                                  (c) => c.id == classToEdit.id);
                              if (idx != -1) _allCourses[idx] = updated;
                            } else {
                              _allCourses.add(updated);
                            }
                          });

                          _saveCourses();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Save Class',
                          style: TextStyle(
                              fontFamily: 'serif',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
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
}

// Extension to allow quick children parameter syntax
extension RowExtension on Row {
  static Row withChildren(
      {required List<Widget> left, required List<Widget> right}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [...left, ...right],
    );
  }
}