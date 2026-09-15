import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool
  isAlarm; // true = audible alarm sound + vibration, false = silent push notification

  const ClassReminder({required this.minutesBefore, this.isAlarm = true});

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
  final String instructor;
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
    this.instructor = '',
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
  }) : reminders =
           reminders ??
           (reminderMinutes != null && reminderMinutes > 0
               ? [
                   ClassReminder(
                     minutesBefore: reminderMinutes,
                     isAlarm: playAlarmSound ?? true,
                   ),
                 ]
               : (reminderMinutes == 0
                     ? []
                     : [
                         const ClassReminder(minutesBefore: 15, isAlarm: true),
                       ]));

  // Backward compatibility getters
  int get reminderMinutes =>
      reminders.isNotEmpty ? reminders.first.minutesBefore : 0;
  bool get playAlarmSound =>
      reminders.isNotEmpty ? reminders.first.isAlarm : true;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'instructor': instructor,
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
        parsedReminders = [
          ClassReminder(minutesBefore: oldMins, isAlarm: oldAlarm),
        ];
      }
    } else {
      parsedReminders = [const ClassReminder(minutesBefore: 15, isAlarm: true)];
    }

    return CourseClass(
      id: json['id'],
      title: json['title'],
      instructor: json['instructor'] ?? '',
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
// 3. TO-DO MODEL + LOCAL STORAGE
// ==========================================
enum TodoFilter { ongoing, all, missed, completed }

class TodoTask {
  final String id;
  final String title;
  final String subject;
  final DateTime dueAt;
  final bool completed;
  final int iconCodePoint;
  final int iconColorValue;

  const TodoTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueAt,
    this.completed = false,
    this.iconCodePoint = 0xe873, // Icons.description_outlined
    this.iconColorValue = 0xFFFFD966,
  });

  bool get isMissed => !completed && dueAt.isBefore(DateTime.now());
  bool get isOngoing => !completed && !isMissed;

  TodoTask copyWith({
    String? id,
    String? title,
    String? subject,
    DateTime? dueAt,
    bool? completed,
    int? iconCodePoint,
    int? iconColorValue,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dueAt: dueAt ?? this.dueAt,
      completed: completed ?? this.completed,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconColorValue: iconColorValue ?? this.iconColorValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'dueAt': dueAt.toIso8601String(),
    'completed': completed,
    'iconCodePoint': iconCodePoint,
    'iconColorValue': iconColorValue,
  };

  factory TodoTask.fromJson(Map<String, dynamic> json) => TodoTask(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] ?? '',
    subject: json['subject'] ?? '',
    dueAt: DateTime.tryParse(json['dueAt'] ?? '') ?? DateTime.now(),
    completed: json['completed'] ?? false,
    iconCodePoint: json['iconCodePoint'] ?? 0xe873,
    iconColorValue: json['iconColorValue'] ?? 0xFFFFD966,
  );
}

class TodoStorage {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/todo_data.json');
  }

  static Future<List<TodoTask>> loadTasks() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        final now = DateTime.now();
        return [
          TodoTask(
            id: 'todo-1',
            title: 'Laboratory Report',
            subject: 'Biology',
            dueAt: DateTime(now.year, now.month, now.day + 1, 23, 59),
            iconCodePoint: Icons.folder_copy_outlined.codePoint,
            iconColorValue: 0xFFFFD85C,
          ),
          TodoTask(
            id: 'todo-2',
            title: 'Problem Set',
            subject: 'Calculus',
            dueAt: DateTime(now.year, now.month, now.day + 2, 7, 30),
            iconCodePoint: Icons.calculate_outlined.codePoint,
            iconColorValue: 0xFFBDBDBD,
          ),
          TodoTask(
            id: 'todo-3',
            title: 'Position Paper',
            subject: 'English',
            dueAt: DateTime(now.year, now.month, now.day + 3, 18, 0),
            iconCodePoint: Icons.edit_note_outlined.codePoint,
            iconColorValue: 0xFFD6E8FA,
          ),
          TodoTask(
            id: 'todo-4',
            title: 'Code Game',
            subject: 'CMSC',
            dueAt: DateTime(now.year, now.month, now.day - 1, 13, 30),
            iconCodePoint: Icons.laptop_mac_outlined.codePoint,
            iconColorValue: 0xFFBFE5EA,
          ),
        ];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonData = jsonDecode(contents);
      return jsonData.map((e) => TodoTask.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTasks(List<TodoTask> tasks) async {
    final file = await _getFile();
    await file.writeAsString(
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }
}



class StudentIdProfile {
  final String name;
  final String school;
  final DateTime birthday;
  final String yearLevel;
  final int cardColorValue;
  final String? photoPath;
  final String logoStyle;
  final String? customLogoPath;

  StudentIdProfile({
    this.name = 'Mike',
    this.school = 'Cebu Institute of Technology - University',
    DateTime? birthday,
    this.yearLevel = '4',
    this.cardColorValue = 0xFFBFDDFB,
    this.photoPath,
    this.logoStyle = 'ssc',
    this.customLogoPath,
  }) : birthday = birthday ?? DateTime(2004, 9, 13);

  StudentIdProfile copyWith({
    String? name,
    String? school,
    DateTime? birthday,
    String? yearLevel,
    int? cardColorValue,
    String? photoPath,
    bool clearPhoto = false,
    String? logoStyle,
    String? customLogoPath,
    bool clearCustomLogo = false,
  }) {
    return StudentIdProfile(
      name: name ?? this.name,
      school: school ?? this.school,
      birthday: birthday ?? this.birthday,
      yearLevel: yearLevel ?? this.yearLevel,
      cardColorValue: cardColorValue ?? this.cardColorValue,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      logoStyle: logoStyle ?? this.logoStyle,
      customLogoPath: clearCustomLogo
          ? null
          : (customLogoPath ?? this.customLogoPath),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'school': school,
    'birthday': birthday.toIso8601String(),
    'yearLevel': yearLevel,
    'cardColorValue': cardColorValue,
    'photoPath': photoPath,
    'logoStyle': logoStyle,
    'customLogoPath': customLogoPath,
  };

  factory StudentIdProfile.fromJson(Map<String, dynamic> json) {
    return StudentIdProfile(
      name: json['name']?.toString() ?? 'Mike',
      school:
          json['school']?.toString() ??
          'Cebu Institute of Technology - University',
      birthday:
          DateTime.tryParse(json['birthday']?.toString() ?? '') ??
          DateTime(2004, 9, 13),
      yearLevel: json['yearLevel']?.toString() ?? '4',
      cardColorValue: json['cardColorValue'] ?? 0xFFBFDDFB,
      photoPath: json['photoPath']?.toString(),
      logoStyle: json['logoStyle']?.toString() ?? 'ssc',
      customLogoPath: json['customLogoPath']?.toString(),
    );
  }
}

class StudentIdStorage {
  static Future<File> _getProfileFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/student_id_profile.json');
  }

  static Future<StudentIdProfile> loadProfile() async {
    try {
      final file = await _getProfileFile();
      if (!await file.exists()) return StudentIdProfile();
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return StudentIdProfile.fromJson(data);
    } catch (_) {
      return StudentIdProfile();
    }
  }

  static Future<void> saveProfile(StudentIdProfile profile) async {
    final file = await _getProfileFile();
    await file.writeAsString(jsonEncode(profile.toJson()), flush: true);
  }

  static Future<String> persistPickedImage(
    String sourcePath, {
    required String prefix,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final assetDir = Directory('${dir.path}/student_id_assets');
    if (!await assetDir.exists()) {
      await assetDir.create(recursive: true);
    }

    final lastDot = sourcePath.lastIndexOf('.');
    final extension = lastDot >= 0 ? sourcePath.substring(lastDot) : '.jpg';
    final filename =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}$extension';
    final saved = await File(sourcePath).copy('${assetDir.path}/$filename');
    return saved.path;
  }
}

class StudentIdCardVisual extends StatelessWidget {
  final StudentIdProfile profile;
  final bool compact;

  const StudentIdCardVisual({
    super.key,
    required this.profile,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        profile.photoPath != null && File(profile.photoPath!).existsSync();
    final cardHeight = compact ? 142.0 : 176.0;
    final photoWidth = compact ? 94.0 : 116.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        compact ? 10 : 15,
        compact ? 10 : 14,
        compact ? 9 : 13,
      ),
      decoration: BoxDecoration(
        color: Color(profile.cardColorValue),
        borderRadius: BorderRadius.circular(compact ? 15 : 18),
        border: Border.all(color: const Color(0xFF242424), width: 1.6),
      ),
      child: SizedBox(
        height: cardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: photoWidth,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        border: Border.all(
                          color: const Color(0xFF242424),
                          width: 1.4,
                        ),
                      ),
                      child: hasPhoto
                          ? Image.file(
                              File(profile.photoPath!),
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: compact ? 54 : 68,
                              color: const Color(0xFF9AA2AA),
                            ),
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 3),
                  _barcode(compact),
                ],
              ),
            ),
            SizedBox(width: compact ? 11 : 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: compact ? 7 : 8,
                    child: Center(child: _logo(profile, compact)),
                  ),
                  SizedBox(height: compact ? 5 : 8),
                  Row(
                    children: List.generate(
                      compact ? 14 : 17,
                      (_) => Expanded(
                        child: Container(
                          height: 1.35,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: const Color(0xFF222222),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 7 : 10),
                  Expanded(
                    flex: 6,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('NAME', compact),
                              _value(
                                profile.name.toUpperCase(),
                                compact,
                                maxLines: 1,
                              ),
                              SizedBox(height: compact ? 5 : 8),
                              _label('SCHOOL', compact),
                              _value(
                                profile.school.toUpperCase(),
                                compact,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: compact ? 8 : 12),
                        SizedBox(
                          width: compact ? 86 : 104,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('BIRTHDAY', compact),
                              _value(
                                DateFormat(
                                  'MM-dd-yyyy',
                                ).format(profile.birthday),
                                compact,
                                maxLines: 1,
                              ),
                              SizedBox(height: compact ? 5 : 8),
                              _label('YEAR LEVEL', compact),
                              _value(profile.yearLevel, compact, maxLines: 1),
                            ],
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
      ),
    );
  }

  static Widget _barcode(bool compact) {
    final widths = [
      2.0,
      1.0,
      3.0,
      1.0,
      2.0,
      4.0,
      1.0,
      2.0,
      1.0,
      3.0,
      2.0,
      1.0,
      4.0,
      2.0,
      1.0,
      3.0,
      1.0,
      2.0,
    ];
    final height = compact ? 17.0 : 23.0;
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Row(
          children: [
            for (final width in widths) ...[
              Container(
                width: width,
                height: height,
                color: const Color(0xFF202020),
              ),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _label(String text, bool compact) => Text(
    text,
    style: TextStyle(
      fontFamily: 'sans-serif',
      fontSize: compact ? 7.2 : 8.5,
      height: 1,
      color: const Color(0xFF3D4650),
    ),
  );

  static Widget _value(
    String text,
    bool compact, {
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: compact ? 11.2 : 13.5,
        height: 1.02,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF161B20),
      ),
    ),
  );

  static Widget _logo(StudentIdProfile profile, bool compact) {
    final customPath = profile.customLogoPath;
    if (profile.logoStyle == 'custom' &&
        customPath != null &&
        File(customPath).existsSync()) {
      return Image.file(
        File(customPath),
        height: compact ? 54 : 72,
        fit: BoxFit.contain,
      );
    }

    switch (profile.logoStyle) {
      case 'student':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: compact ? 17 : 22,
              color: const Color(0xFF161616),
            ),
            Text(
              'Student ID',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: compact ? 23 : 30,
                height: .9,
                color: const Color(0xFF161616),
              ),
            ),
          ],
        );
      case 'iskolar':
        return Text(
          '✦ ISKOLAR NG\nBAYAN',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: compact ? 14 : 18,
            height: .9,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFE74691),
          ),
        );
      case 'slayer':
        return Text(
          'ACADEMIC\nSLAYER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: compact ? 15 : 20,
            height: .85,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF5B57),
          ),
        );
      case 'victim':
        return Text(
          'Academic\nVictim',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: compact ? 18 : 24,
            height: .85,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8D69DF),
          ),
        );
      case 'ssc':
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  'SSC',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: compact ? 34 : 44,
                    height: .86,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.3,
                    color: const Color(0xFF438BE8),
                    shadows: const [
                      Shadow(
                        color: Colors.white,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: compact ? 32 : 42,
                  bottom: -2,
                  child: Icon(
                    Icons.star_rounded,
                    size: compact ? 13 : 16,
                    color: const Color(0xFFFFD800),
                  ),
                ),
                Positioned(
                  right: compact ? 24 : 31,
                  bottom: -2,
                  child: Icon(
                    Icons.star_rounded,
                    size: compact ? 13 : 16,
                    color: const Color(0xFFFFD800),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 3 : 5),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7 : 9,
                vertical: compact ? 2 : 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF438BE8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'STRUGGLING STUDENTS CLUB',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: compact ? 7.4 : 9.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: .1,
                ),
              ),
            ),
          ],
        );
    }
  }
}


// ==========================================
// 3. NOTIFICATION SERVICE
// ==========================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String alarmChannelId = 'class_alarms_channel_v5';
  static const String silentChannelId = 'class_silent_channel_v5';

  static const MethodChannel _channel = MethodChannel(
    'com.example.schedule_app/settings',
  );

  // Pulsed rhythm: 1s vibrate, 200ms rest, 1s vibrate, 200ms rest, 1s vibrate (3s total active buzz)
  static final Int64List threeSecVibrationPattern = Int64List.fromList([
    0,
    1000,
    200,
    1000,
    200,
    1000,
  ]);

  /// Triggers a 3-second physical vibration on the device
  static Future<void> triggerVibration({int durationMs = 3000}) async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': durationMs});
    } catch (e) {
      debugPrint('Error triggering physical vibration: $e');
    }
  }

  /// Opens Android app notification settings directly
  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint(
        'Error opening notification settings via platform channel: $e',
      );
      try {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  /// Opens Android system settings for "Alarms & reminders" special app access
  static Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('Error opening exact alarm settings via platform channel: $e');
      try {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  /// Requests ignoring battery optimizations so background alarms always fire on time
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('Error requesting battery optimization ignore: $e');
    }
  }

  /// Checks if battery optimization is disabled for this app
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool? isIgnoring = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return isIgnoring ?? false;
    } catch (e) {
      debugPrint('Error checking battery optimization status: $e');
      return false;
    }
  }

  static Future<void> init() async {
    // 1. Initialize Timezones using actual device local timezone
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Error getting device local timezone: $e');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification clicked: ${details.payload}');
      },
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Delete older channel versions so new vibration pattern takes effect immediately
    try {
      await androidImplementation?.deleteNotificationChannel(
        'class_alarms_channel_v2',
      );
      await androidImplementation?.deleteNotificationChannel(
        'class_alarms_channel_v3',
      );
      await androidImplementation?.deleteNotificationChannel(
        'class_alarms_channel_v4',
      );
    } catch (_) {}

    // 2. Register Android Notification Channels
    final alarmChannel = AndroidNotificationChannel(
      alarmChannelId,
      'Class Alarms',
      description: 'Audible alarms and 3-second vibration for upcoming classes',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: threeSecVibrationPattern,
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

    await androidImplementation?.createNotificationChannel(alarmChannel);
    await androidImplementation?.createNotificationChannel(silentChannel);
  }

  /// Request runtime permissions for notifications (Android 13+)
  static Future<bool> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation == null) return true;

      // Request standard POST_NOTIFICATIONS runtime permission
      final notifGranted = await androidImplementation
          .requestNotificationsPermission();
      return notifGranted ?? true;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Checks whether Android allows scheduling exact alarms (Android 12+)
  static Future<bool> canScheduleExact() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidImplementation?.canScheduleExactNotifications() ??
          true;
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return true;
    }
  }

  static Future<void> scheduleCourseAlarm(CourseClass course) async {
    // Cancel any existing alarms/notifications for this course
    await cancelAlarm(course.id);

    if (course.reminders.isEmpty) {
      return;
    }

    final bool canExact = await canScheduleExact();
    if (!canExact) {
      await openExactAlarmSettings();
    }

    for (final reminder in course.reminders) {
      if (reminder.minutesBefore <= 0) continue;

      final int notificationId =
          (Object.hash(course.id, reminder.minutesBefore) & 0x7FFFFFFF);

      final reminderTime = _nextInstanceOfReminder(
        course.dayOfWeek,
        course.startHour,
        course.startMinute,
        reminder.minutesBefore,
      );

      final String prefix = reminder.isAlarm ? 'Alarm' : 'Reminder';
      final String title = '[$prefix] Upcoming Class: ${course.title}';
      final String body =
          'Starts in ${reminder.minutesBefore} mins at ${course.startTimeFormatted} (${course.room.isNotEmpty ? course.room : "No Room"})';

      try {
        await _channel.invokeMethod('scheduleAlarm', {
          'id': notificationId,
          'triggerAtMillis': reminderTime.millisecondsSinceEpoch,
          'title': title,
          'body': body,
          'isAlarm': reminder.isAlarm,
          'repeatWeekly': true,
        });
      } catch (e) {
        debugPrint('Error scheduling native alarm: $e');
      }

      // If the class is today and starts within the reminder window, fire an immediate alert
      final nowTime = tz.TZDateTime.now(tz.local);
      if (course.dayOfWeek == nowTime.weekday) {
        final todayClassTime = tz.TZDateTime(
          tz.local,
          nowTime.year,
          nowTime.month,
          nowTime.day,
          course.startHour,
          course.startMinute,
        );
        final diffSeconds = todayClassTime.difference(nowTime).inSeconds;
        if (todayClassTime.isAfter(nowTime) &&
            diffSeconds <= reminder.minutesBefore * 60) {
          try {
            await _notificationsPlugin.show(
              (Object.hash(course.id, reminder.minutesBefore, 'immediate') &
                  0x7FFFFFFF),
              '[$prefix] Class Starting Soon: ${course.title}',
              'Starts at ${course.startTimeFormatted} (${course.room.isNotEmpty ? course.room : "No Room"})',
              NotificationDetails(
                android: AndroidNotificationDetails(
                  reminder.isAlarm ? alarmChannelId : silentChannelId,
                  reminder.isAlarm ? 'Class Alarms' : 'Silent Class Reminders',
                  channelDescription: reminder.isAlarm
                      ? 'Audible alarms and 3-second vibration for upcoming courses'
                      : 'Silent notifications for upcoming courses',
                  importance: reminder.isAlarm
                      ? Importance.max
                      : Importance.defaultImportance,
                  priority: reminder.isAlarm
                      ? Priority.max
                      : Priority.defaultPriority,
                  playSound: reminder.isAlarm,
                  enableVibration: reminder.isAlarm,
                  vibrationPattern: reminder.isAlarm
                      ? threeSecVibrationPattern
                      : null,
                  audioAttributesUsage: reminder.isAlarm
                      ? AudioAttributesUsage.alarm
                      : AudioAttributesUsage.notification,
                  category: reminder.isAlarm
                      ? AndroidNotificationCategory.alarm
                      : AndroidNotificationCategory.reminder,
                  visibility: NotificationVisibility.public,
                ),
              ),
            );
            if (reminder.isAlarm) {
              triggerVibration(durationMs: 3000);
            }
          } catch (_) {}
        }
      }
    }
  }

  /// Sends an immediate test alert so the user can verify sound, vibration, and channels
  static Future<bool> sendTestNotification({required bool isAlarm}) async {
    try {
      // Ensure notification permission is requested if not already granted
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.requestNotificationsPermission();

      if (isAlarm) {
        // Immediately trigger 3-second vibration on device hardware
        triggerVibration(durationMs: 3000);
      }

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          isAlarm ? alarmChannelId : silentChannelId,
          isAlarm ? 'Class Alarms' : 'Silent Class Reminders',
          channelDescription: isAlarm
              ? 'Audible alarms and 3-second vibration for upcoming courses'
              : 'Silent notifications for upcoming courses',
          importance: isAlarm ? Importance.max : Importance.defaultImportance,
          priority: isAlarm ? Priority.max : Priority.defaultPriority,
          playSound: isAlarm,
          enableVibration: isAlarm,
          vibrationPattern: isAlarm ? threeSecVibrationPattern : null,
          audioAttributesUsage: isAlarm
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          category: isAlarm
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
      );

      await _notificationsPlugin.show(
        888888,
        isAlarm
            ? '[Alarm Test] Class Alarm Sound'
            : '[Push Test] Silent Push Notification',
        isAlarm
            ? 'Alarm verified! Playing sound and 3-second vibration.'
            : 'Push notification is connected! Visual heads-up banner verified.',
        notificationDetails,
      );
      return true;
    } catch (e, stack) {
      debugPrint('sendTestNotification error: $e\n$stack');
      return false;
    }
  }

  /// Schedules an alarm to fire in 10 seconds.
  /// Wakes the phone to the lock screen (does NOT open the app) and reliably vibrates 3 seconds.
  static Future<bool> scheduleTestCountdownAlarm({int seconds = 10}) async {
    try {
      await requestPermissions();
      final canExact = await canScheduleExact();
      if (!canExact) {
        await openExactAlarmSettings();
      }

      final triggerTime = DateTime.now().add(Duration(seconds: seconds));
      const int testId = 777777;

      await cancelAlarm('test_countdown');

      await _channel.invokeMethod('scheduleAlarm', {
        'id': testId,
        'triggerAtMillis': triggerTime.millisecondsSinceEpoch,
        'title': '[Countdown Alarm Test] 10s Alarm Triggered!',
        'body':
            'Alarm successfully woke up your lock screen with 3s vibration.',
        'isAlarm': true,
        'repeatWeekly': false,
      });

      return true;
    } catch (e, stack) {
      debugPrint('scheduleTestCountdownAlarm error: $e\n$stack');
      return false;
    }
  }

  static tz.TZDateTime _nextInstanceOfReminder(
    int classDayOfWeek,
    int startHour,
    int startMinute,
    int reminderMinutes,
  ) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime classTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );

    // Advance until we match the class day of the week
    while (classTime.weekday != classDayOfWeek) {
      classTime = classTime.add(const Duration(days: 1));
    }

    tz.TZDateTime reminderTime = classTime.subtract(
      Duration(minutes: reminderMinutes),
    );

    // If the reminder time has already passed for this week, advance by 7 days
    while (reminderTime.isBefore(now)) {
      reminderTime = reminderTime.add(const Duration(days: 7));
    }

    return reminderTime;
  }

  static Future<void> cancelAlarm(String courseId) async {
    final int mainId = courseId.hashCode & 0x7FFFFFFF;
    await _notificationsPlugin.cancel(mainId);
    try {
      await _channel.invokeMethod('cancelAlarm', {'id': mainId});
    } catch (_) {}

    // Cancel potential reminder minute hash IDs
    for (final mins in [5, 10, 15, 30, 45, 60, 120]) {
      final int remId = Object.hash(courseId, mins) & 0x7FFFFFFF;
      await _notificationsPlugin.cancel(remId);
      try {
        await _channel.invokeMethod('cancelAlarm', {'id': remId});
      } catch (_) {}
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
      home: const FolderlyRootNavigation(),
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
// 5. ROOT NAVIGATION + TO-DO PAGE
// ==========================================
class FolderlyRootNavigation extends StatefulWidget {
  const FolderlyRootNavigation({super.key});

  @override
  State<FolderlyRootNavigation> createState() => _FolderlyRootNavigationState();
}

class _FolderlyRootNavigationState extends State<FolderlyRootNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ScheduleHomeScreen(),
    TodoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(
                1,
                Icons.checklist_rounded,
                Icons.checklist_rounded,
                'To Do',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final selected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFDE59) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: const Color(0xFF222222), width: 1.2)
                      : null,
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 23,
                  color: selected ? const Color(0xFF222222) : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? const Color(0xFF222222) : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<TodoTask> _tasks = [];
  TodoFilter _filter = TodoFilter.ongoing;
  StudentIdProfile _profile = StudentIdProfile();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await TodoStorage.loadTasks();
    final profile = await StudentIdStorage.loadProfile();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _saveTasks() => TodoStorage.saveTasks(_tasks);

  List<TodoTask> get _visibleTasks {
    final list = switch (_filter) {
      TodoFilter.ongoing => _tasks.where((t) => t.isOngoing).toList(),
      TodoFilter.all => _tasks.where((t) => !t.completed).toList(),
      TodoFilter.missed => _tasks.where((t) => t.isMissed).toList(),
      TodoFilter.completed => _tasks.where((t) => t.completed).toList(),
    };
    list.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return list;
  }

  String get _filterLabel => switch (_filter) {
    TodoFilter.ongoing => 'Ongoing',
    TodoFilter.all => 'All',
    TodoFilter.missed => 'Missed',
    TodoFilter.completed => 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTasks;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  _buildStudentIdCard(),
                  const SizedBox(height: 18),
                  _buildTodoHeader(),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    _buildEmptyState()
                  else
                    ...visible.map(_buildTodoCard),
                ],
              ),
      ),
    );
  }

  Widget _buildStudentIdCard() {
    return Hero(
      tag: 'student-id-card',
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            return Material(
              color: Colors.transparent,
              child: StudentIdCardVisual(profile: _profile, compact: true),
            );
          },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openIdCustomization,
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              StudentIdCardVisual(profile: _profile, compact: true),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: Color(0xFF242424),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openIdCustomization() async {
    final result = await Navigator.of(context).push<StudentIdProfile>(
      PageRouteBuilder<StudentIdProfile>(
        transitionDuration: const Duration(milliseconds: 430),
        reverseTransitionDuration: const Duration(milliseconds: 330),
        pageBuilder: (context, animation, secondaryAnimation) {
          return IdCardCustomizationScreen(initialProfile: _profile);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.055),
            end: Offset.zero,
          ).animate(curved);
          final scale = Tween<double>(
            begin: 0.985,
            end: 1,
          ).animate(curved);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      setState(() => _profile = result);
    }
  }

  Widget _buildTodoHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'To-do',
          style: TextStyle(
            fontSize: 25,
            fontStyle: FontStyle.italic,
            color: Color(0xFF232323),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<TodoFilter>(
          onSelected: (value) => setState(() => _filter = value),
          offset: const Offset(0, 38),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF242424), width: 1.2),
          ),
          itemBuilder: (_) => [
            _filterMenuItem(
              TodoFilter.ongoing,
              'Ongoing',
              Icons.schedule_rounded,
            ),
            _filterMenuItem(TodoFilter.all, 'All', Icons.list_alt_rounded),
            _filterMenuItem(
              TodoFilter.missed,
              'Missed',
              Icons.history_toggle_off_rounded,
            ),
            _filterMenuItem(
              TodoFilter.completed,
              'Completed',
              Icons.check_rounded,
            ),
          ],
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFD6E8FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF242424), width: 1.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _filterLabel,
                  style: const TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
              ],
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _showAddEditTodoSheet(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2025),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 18),
                SizedBox(width: 3),
                Text(
                  'To-do',
                  style: TextStyle(
                    fontFamily: 'sans-serif',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<TodoFilter> _filterMenuItem(
    TodoFilter value,
    String label,
    IconData icon,
  ) {
    final selected = value == _filter;
    return PopupMenuItem(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD6E8FA) : Colors.white,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(icon, size: 21, color: const Color(0xFF222222)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoCard(TodoTask task) {
    final missed = task.isMissed;
    final date = DateFormat('MMM d, yyyy').format(task.dueAt);
    final time = DateFormat('h:mm a').format(task.dueAt);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 18),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade300,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => _tasks.removeWhere((t) => t.id == task.id));
        _saveTasks();
      },
      child: InkWell(
        onTap: () => _showAddEditTodoSheet(task: task),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(9, 6, 7, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFF333333), width: 1.1),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(task.iconColorValue),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  IconData(task.iconCodePoint, fontFamily: 'MaterialIcons'),
                  color: const Color(0xFF363636),
                  size: 20,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 13.5,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        decoration:
                            task.completed ? TextDecoration.lineThrough : null,
                        color: task.completed
                            ? Colors.grey.shade500
                            : const Color(0xFF202020),
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 10,
                          color: Color(0xFF383838),
                        ),
                        children: [
                          TextSpan(
                            text: task.subject.isEmpty
                                ? 'General'
                                : task.subject,
                          ),
                          const TextSpan(text: ' | '),
                          TextSpan(
                            text: '$date $time',
                            style: TextStyle(
                              color: missed
                                  ? const Color(0xFFD94A4A)
                                  : const Color(0xFF5A9A35),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              InkWell(
                onTap: () {
                  setState(() {
                    final i = _tasks.indexWhere((t) => t.id == task.id);
                    if (i != -1) {
                      _tasks[i] = task.copyWith(completed: !task.completed);
                    }
                  });
                  _saveTasks();
                },
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: task.completed
                        ? const Color(0xFFFFDE59)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: const Color(0xFF333333),
                      width: 1.1,
                    ),
                  ),
                  child: task.completed
                      ? const Icon(
                          Icons.check_rounded,
                          size: 19,
                          color: Color(0xFF222222),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 55),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 90,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            _filter == TodoFilter.completed
                ? 'No completed tasks yet.'
                : 'No tasks to accomplish.',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditTodoSheet({TodoTask? task}) {
    final title = TextEditingController(text: task?.title ?? '');
    final subject = TextEditingController(text: task?.subject ?? '');
    DateTime dueAt =
        task?.dueAt ?? DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFFF9F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickDate() async {
            final value = await showDatePicker(
              context: context,
              initialDate: dueAt,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (value != null) {
              setSheetState(() {
                dueAt = DateTime(
                  value.year,
                  value.month,
                  value.day,
                  dueAt.hour,
                  dueAt.minute,
                );
              });
            }
          }

          Future<void> pickTime() async {
            final value = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(dueAt),
            );
            if (value != null) {
              setSheetState(() {
                dueAt = DateTime(
                  dueAt.year,
                  dueAt.month,
                  dueAt.day,
                  value.hour,
                  value.minute,
                );
              });
            }
          }

          final media = MediaQuery.of(context);
          final keyboardOpen = media.viewInsets.bottom > 0;
          final bottomPadding = keyboardOpen
              ? media.viewInsets.bottom + 24
              : media.viewPadding.bottom + 42;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    task == null ? 'Add To-do' : 'Edit To-do',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Task title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subject,
                    decoration: const InputDecoration(
                      labelText: 'Subject / course',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                          label: Text(
                            DateFormat('MMM d, yyyy').format(dueAt),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickTime,
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(DateFormat('h:mm a').format(dueAt)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF232323),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (title.text.trim().isEmpty) return;

                        final value = TodoTask(
                          id:
                              task?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title.text.trim(),
                          subject: subject.text.trim(),
                          dueAt: dueAt,
                          completed: task?.completed ?? false,
                          iconCodePoint:
                              task?.iconCodePoint ??
                              Icons.description_outlined.codePoint,
                          iconColorValue:
                              task?.iconColorValue ?? 0xFFFFD966,
                        );

                        setState(() {
                          if (task == null) {
                            _tasks.add(value);
                          } else {
                            final index = _tasks.indexWhere(
                              (t) => t.id == task.id,
                            );
                            if (index != -1) _tasks[index] = value;
                          }
                        });

                        _saveTasks();
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        task == null ? 'Add To-do' : 'Save Changes',
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

class IdCardCustomizationScreen extends StatefulWidget {
  final StudentIdProfile initialProfile;

  const IdCardCustomizationScreen({
    super.key,
    required this.initialProfile,
  });

  @override
  State<IdCardCustomizationScreen> createState() =>
      _IdCardCustomizationScreenState();
}

class _IdCardCustomizationScreenState
    extends State<IdCardCustomizationScreen> {
  late StudentIdProfile _profile;
  late final TextEditingController _nameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _yearController;
  bool _saving = false;

  final List<int> _cardColors = const [
    0xFFF1F1F1,
    0xFFF7C9DC,
    0xFFBFDDFB,
    0xFFD3C7F6,
    0xFFCFE8C5,
    0xFFFFF693,
    0xFFFFBE86,
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _nameController = TextEditingController(text: _profile.name);
    _schoolController = TextEditingController(text: _profile.school);
    _yearController = TextEditingController(text: _profile.yearLevel);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (picked == null) return;

      final savedPath = await StudentIdStorage.persistPickedImage(
        picked.path,
        prefix: 'student_photo',
      );
      if (!mounted) return;
      setState(() {
        _profile = _profile.copyWith(photoPath: savedPath);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select photo: $e')),
      );
    }
  }

  Future<void> _pickCustomLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 800,
        imageQuality: 92,
      );
      if (picked == null) return;

      final savedPath = await StudentIdStorage.persistPickedImage(
        picked.path,
        prefix: 'student_logo',
      );
      if (!mounted) return;
      setState(() {
        _profile = _profile.copyWith(
          logoStyle: 'custom',
          customLogoPath: savedPath,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select logo: $e')),
      );
    }
  }

  Future<void> _pickBirthday() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _profile.birthday,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (value != null) {
      setState(() {
        _profile = _profile.copyWith(birthday: value);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final school = _schoolController.text.trim();
    final year = _yearController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }

    setState(() => _saving = true);
    final updated = _profile.copyWith(
      name: name,
      school: school.isEmpty ? 'School' : school,
      yearLevel: year.isEmpty ? '-' : year,
    );

    await StudentIdStorage.saveProfile(updated);
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 36,
            color: Color(0xFF1F2025),
          ),
        ),
        title: const Text(
          'Edit ID Card',
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202126),
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Hero(
            tag: 'student-id-card',
            child: Material(
              color: Colors.transparent,
              child: StudentIdCardVisual(profile: _previewProfile),
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Photo'),
          const SizedBox(height: 10),
          _photoEditor(),
          const SizedBox(height: 22),
          _sectionTitle('Color'),
          const SizedBox(height: 10),
          _colorPicker(),
          const SizedBox(height: 24),
          _sectionTitle('Logo'),
          const SizedBox(height: 10),
          _logoPicker(),
          const SizedBox(height: 24),
          _sectionTitle('Card details'),
          const SizedBox(height: 10),
          _detailsEditor(),
          const SizedBox(height: 18),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF232429),
              disabledBackgroundColor: const Color(0xFFEAEAEA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  StudentIdProfile get _previewProfile => _profile.copyWith(
    name: _nameController.text.trim().isEmpty
        ? _profile.name
        : _nameController.text.trim(),
    school: _schoolController.text.trim().isEmpty
        ? _profile.school
        : _schoolController.text.trim(),
    yearLevel: _yearController.text.trim().isEmpty
        ? _profile.yearLevel
        : _yearController.text.trim(),
  );

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF202126),
      ),
    );
  }

  Widget _photoEditor() {
    final hasPhoto =
        _profile.photoPath != null && File(_profile.photoPath!).existsSync();

    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD2D2D2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? Image.file(File(_profile.photoPath!), fit: BoxFit.cover)
              : const Icon(
                  Icons.person_rounded,
                  size: 44,
                  color: Color(0xFF9AA2AA),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickPhoto,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF232429),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 19),
            label: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
          ),
        ),
        if (hasPhoto) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove photo',
            onPressed: () {
              setState(() {
                _profile = _profile.copyWith(clearPhoto: true);
              });
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _colorPicker() {
    return Wrap(
      spacing: 13,
      runSpacing: 12,
      children: [
        for (final value in _cardColors)
          GestureDetector(
            onTap: () {
              setState(() {
                _profile = _profile.copyWith(cardColorValue: value);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _profile.cardColorValue == value
                      ? const Color(0xFF202126)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _logoPicker() {
    final items = <({String id, String label})>[
      (id: 'student', label: 'Student ID'),
      (id: 'ssc', label: 'SSC'),
      (id: 'iskolar', label: 'Iskolar ng Bayan'),
      (id: 'slayer', label: 'Academic Slayer'),
      (id: 'victim', label: 'Academic Victim'),
      (id: 'custom', label: 'Custom logo'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.05,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = _profile.logoStyle == item.id;

        return InkWell(
          onTap: () {
            if (item.id == 'custom') {
              _pickCustomLogo();
            } else {
              setState(() {
                _profile = _profile.copyWith(logoStyle: item.id);
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFF202126)
                    : const Color(0xFFD7D7D7),
                width: selected ? 1.8 : 1,
              ),
            ),
            child: item.id == 'custom'
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.file_upload_outlined,
                        size: 22,
                        color: Color(0xFF444444),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profile.customLogoPath == null
                            ? 'Custom logo'
                            : 'Change custom logo',
                        style: const TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : _logoTilePreview(item.id, item.label),
          ),
        );
      },
    );
  }

  Widget _logoTilePreview(String id, String label) {
    switch (id) {
      case 'ssc':
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SSC',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 24,
                height: .9,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Color(0xFF438BE8),
              ),
            ),
            SizedBox(height: 3),
            Text(
              'STRUGGLING STUDENTS CLUB',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 6.8,
                fontWeight: FontWeight.w900,
                color: Color(0xFF438BE8),
              ),
            ),
          ],
        );
      case 'iskolar':
        return const Center(
          child: Text(
            '✦ ISKOLAR NG BAYAN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Color(0xFFE74691),
            ),
          ),
        );
      case 'slayer':
        return const Center(
          child: Text(
            'ACADEMIC SLAYER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Color(0xFFFF5B57),
            ),
          ),
        );
      case 'victim':
        return const Center(
          child: Text(
            'Academic Victim',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Color(0xFF8D69DF),
            ),
          ),
        );
      case 'student':
      default:
        return const Center(
          child: Text(
            'Student ID',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 20,
              color: Color(0xFF202126),
            ),
          ),
        );
    }
  }

  Widget _detailsEditor() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration('Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _schoolController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration('School'),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickBirthday,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration('Birthday'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MM-dd-yyyy').format(_profile.birthday),
                    style: const TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 15,
                      color: Color(0xFF202126),
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 21,
                  color: Color(0xFF555555),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _yearController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.number,
          decoration: _fieldDecoration('Year level'),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF202126),
          width: 1.6,
        ),
      ),
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

  final List<String> _weekDays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

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
    await _rescheduleAllNotifications();
    await _syncToHomeWidget();
  }

  Future<void> _saveCourses() async {
    await ScheduleStorage.saveClasses(_allCourses);
    await _rescheduleAllNotifications();
    await _syncToHomeWidget();
  }

  Future<void> _rescheduleAllNotifications() async {
    for (var course in _allCourses) {
      await NotificationService.scheduleCourseAlarm(course);
    }
  }

  // Returns current active class or next upcoming class for today
  CourseClass? _getCurrentOrNextClassForToday() {
    final now = DateTime.now();
    final today = now.weekday;
    final todayCourses = _allCourses.where((c) => c.dayOfWeek == today).toList()
      ..sort(
        (a, b) => (a.startHour * 60 + a.startMinute).compareTo(
          b.startHour * 60 + b.startMinute,
        ),
      );

    for (var c in todayCourses) {
      final classEndToday = DateTime(
        now.year,
        now.month,
        now.day,
        c.endHour,
        c.endMinute,
      );
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
      int progress = 0;
      if (currentClass != null) {
        final startToday = DateTime(
          now.year,
          now.month,
          now.day,
          currentClass.startHour,
          currentClass.startMinute,
        );
        final endToday = DateTime(
          now.year,
          now.month,
          now.day,
          currentClass.endHour,
          currentClass.endMinute,
        );
        if (now.isAfter(startToday) && now.isBefore(endToday)) {
          isActive = true;
          final totalMilliseconds = endToday
              .difference(startToday)
              .inMilliseconds;
          if (totalMilliseconds > 0) {
            progress =
                ((now.difference(startToday).inMilliseconds /
                            totalMilliseconds) *
                        100)
                    .round()
                    .clamp(0, 100);
          }
        }
      }

      await HomeWidget.saveWidgetData<String>(
        'widget_title',
        currentClass?.title ?? 'No Class',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_time',
        currentClass != null
            ? '${currentClass.startTimeFormatted} - ${currentClass.endTimeFormatted}'
            : 'Free Time',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_instructor',
        currentClass?.instructor ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_room',
        currentClass != null
            ? (currentClass.room.isNotEmpty ? currentClass.room : 'Scheduled')
            : 'Free Time',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_start_time',
        currentClass?.startTimeFormatted ?? '00:00',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_end_time',
        currentClass?.endTimeFormatted ?? '00:00',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_image_path',
        currentClass?.imagePath ?? '',
      );
      await HomeWidget.saveWidgetData<bool>('widget_is_active', isActive);
      await HomeWidget.saveWidgetData<int>('widget_progress', progress);

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
    final dayCourses =
        _allCourses.where((c) => c.dayOfWeek == _selectedDay).toList()..sort(
          (a, b) => (a.startHour * 60 + a.startMinute).compareTo(
            b.startHour * 60 + b.startMinute,
          ),
        );

    if (_selectedDay == now.weekday) {
      for (var c in dayCourses) {
        final classEndToday = DateTime(
          now.year,
          now.month,
          now.day,
          c.endHour,
          c.endMinute,
        );
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
    final dayClasses =
        _allCourses.where((c) => c.dayOfWeek == _selectedDay).toList()..sort(
          (a, b) => (a.startHour * 60 + a.startMinute).compareTo(
            b.startHour * 60 + b.startMinute,
          ),
        );

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
                                horizontal: 20,
                                vertical: 8,
                              ),
                              itemCount: dayClasses.length,
                              itemBuilder: (context, index) {
                                return _buildClassTimelineCard(
                                  dayClasses[index],
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 28,
                  color: Color(0xFF333333),
                ),
                tooltip: 'Test Alarms & Notifications',
                onPressed: () => _showNotificationTestModal(),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 30, color: Color(0xFF333333)),
                tooltip: 'Add Subject',
                onPressed: () => _showAddEditClassDialog(),
              ),
            ],
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
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        nextClass.startHour,
        nextClass.startMinute,
      );
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        nextClass.endHour,
        nextClass.endMinute,
      );
      if (now.isAfter(start) && now.isBefore(end)) {
        isNowActive = true;
        final totalMs = end.difference(start).inMilliseconds;
        final currentMs = now.difference(start).inMilliseconds;
        progress = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;
      }
    }

    final customImagePath = nextClass?.imagePath;
    final hasCustomImage =
        customImagePath != null && File(customImagePath).existsSync();

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
                      const Icon(
                        Icons.battery_3_bar,
                        size: 14,
                        color: Colors.black54,
                      ),
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
                          value: isNowActive
                              ? progress
                              : (nextClass != null ? 0.3 : 0.0),
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF333333),
                          ),
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
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            nextClass?.endTimeFormatted ?? '00:00',
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'sans-serif',
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 6,
                      child: Text(
                        'MENU',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'sans-serif',
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 6,
                      child: Icon(
                        Icons.fast_rewind,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const Positioned(
                      right: 6,
                      child: Icon(
                        Icons.fast_forward,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const Positioned(
                      bottom: 6,
                      child: Icon(
                        Icons.play_arrow,
                        size: 14,
                        color: Colors.grey,
                      ),
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
                color: isSelected
                    ? const Color(0xFFFFDE59)
                    : Colors.transparent,
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
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.85),
              width: 1.2,
            ),
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
                              border: Border.all(
                                color: Colors.black26,
                                width: 1.2,
                              ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
    final titleController = TextEditingController(
      text: classToEdit?.title ?? '',
    );
    final instructorController = TextEditingController(
      text: classToEdit?.instructor ?? '',
    );
    final roomController = TextEditingController(text: classToEdit?.room ?? '');
    int selectedDay = classToEdit?.dayOfWeek ?? _selectedDay;
    TimeOfDay startTime = classToEdit != null
        ? TimeOfDay(
            hour: classToEdit.startHour,
            minute: classToEdit.startMinute,
          )
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
                final filename =
                    'subj_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final savedImage = await File(
                  picked.path,
                ).copy('${imgDir.path}/$filename');
                setModalState(() {
                  selectedImagePath = savedImage.path;
                });
              }
            } catch (e) {
              debugPrint('Error picking image: $e');
            }
          }

          final hasValidImage =
              selectedImagePath != null &&
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
                                  color: Color(
                                    selectedColor,
                                  ).withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 2,
                                  ),
                                  image: hasValidImage
                                      ? DecorationImage(
                                          image: FileImage(
                                            File(selectedImagePath!),
                                          ),
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
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 16,
                              ),
                              label: Text(
                                !hasValidImage
                                    ? 'Select Picture from Gallery'
                                    : 'Change Picture',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: pickGalleryImage,
                            ),
                            if (hasValidImage) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instructorController,
                    decoration: InputDecoration(
                      labelText: 'Instructor Name (e.g. Prof. Dela Cruz)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: roomController,
                    decoration: InputDecoration(
                      labelText: 'Room / Building (e.g. Lab 301)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Day selector in modal
                  DropdownButtonFormField<int>(
                    initialValue: selectedDay,
                    decoration: InputDecoration(
                      labelText: 'Day of Week',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                              context: context,
                              initialTime: startTime,
                            );
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
                              context: context,
                              initialTime: endTime,
                            );
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
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedReminders.any((r) => r.isAlarm)
                                      ? Icons.alarm_on_rounded
                                      : (selectedReminders.isNotEmpty
                                            ? Icons
                                                  .notifications_active_outlined
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
                                                  .map(
                                                    (r) =>
                                                        '${r.label} (${r.isAlarm ? "Alarm" : "Push"})',
                                                  )
                                                  .join(', '),
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 13,
                                          color: selectedReminders.isEmpty
                                              ? Colors.grey.shade600
                                              : const Color(0xFF232323),
                                          fontWeight: selectedReminders.isEmpty
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
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                                      vertical: 3,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(
                                              0xFF232323,
                                            ).withValues(alpha: 0.05)
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
                                            activeColor: const Color(
                                              0xFF232323,
                                            ),
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
                                                      isAlarm: true,
                                                    ),
                                                  );
                                                  selectedReminders.sort(
                                                    (a, b) => b.minutesBefore
                                                        .compareTo(
                                                          a.minutesBefore,
                                                        ),
                                                  );
                                                } else {
                                                  selectedReminders.removeWhere(
                                                    (r) =>
                                                        r.minutesBefore == mins,
                                                  );
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
                                                  selectedReminders.removeWhere(
                                                    (r) =>
                                                        r.minutesBefore == mins,
                                                  );
                                                } else {
                                                  selectedReminders.add(
                                                    ClassReminder(
                                                      minutesBefore: mins,
                                                      isAlarm: true,
                                                    ),
                                                  );
                                                  selectedReminders.sort(
                                                    (a, b) => b.minutesBefore
                                                        .compareTo(
                                                          a.minutesBefore,
                                                        ),
                                                  );
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
                                                color: const Color(0xFF232323),
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
                                                    final idx = selectedReminders
                                                        .indexWhere(
                                                          (r) =>
                                                              r.minutesBefore ==
                                                              mins,
                                                        );
                                                    if (idx != -1) {
                                                      selectedReminders[idx] =
                                                          ClassReminder(
                                                            minutesBefore: mins,
                                                            isAlarm: true,
                                                          );
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: existing.isAlarm
                                                        ? const Color(
                                                            0xFF232323,
                                                          )
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: existing.isAlarm
                                                          ? const Color(
                                                              0xFF232323,
                                                            )
                                                          : Colors.black26,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.alarm,
                                                        size: 13,
                                                        color: existing.isAlarm
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF232323,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Alarm',
                                                        style: TextStyle(
                                                          fontFamily: 'serif',
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              existing.isAlarm
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF232323,
                                                                ),
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
                                                    final idx = selectedReminders
                                                        .indexWhere(
                                                          (r) =>
                                                              r.minutesBefore ==
                                                              mins,
                                                        );
                                                    if (idx != -1) {
                                                      selectedReminders[idx] =
                                                          ClassReminder(
                                                            minutesBefore: mins,
                                                            isAlarm: false,
                                                          );
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: !existing.isAlarm
                                                        ? const Color(
                                                            0xFF232323,
                                                          )
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: !existing.isAlarm
                                                          ? const Color(
                                                              0xFF232323,
                                                            )
                                                          : Colors.black26,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .notifications_outlined,
                                                        size: 13,
                                                        color: !existing.isAlarm
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF232323,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Push',
                                                        style: TextStyle(
                                                          fontFamily: 'serif',
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              !existing.isAlarm
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF232323,
                                                                ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        final updated = CourseClass(
                          id:
                              classToEdit?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          instructor: instructorController.text.trim(),
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
                              (c) => c.id == classToEdit.id,
                            );
                            if (idx != -1) _allCourses[idx] = updated;
                          } else {
                            _allCourses.add(updated);
                          }
                        });

                        await NotificationService.scheduleCourseAlarm(updated);
                        await _saveCourses();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        'Save Class',
                        style: TextStyle(
                          fontFamily: 'serif',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  void _showNotificationTestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF9F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final viewPaddingBottom = MediaQuery.of(ctx).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.only(
            bottom: viewPaddingBottom + 16,
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

                // Title Header
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      size: 24,
                      color: Color(0xFF232323),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Alarms & Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.3,
                        color: Color(0xFF232323),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Card 1: Instant Alarm Sound
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9E79).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.alarm_on,
                          size: 22,
                          color: Color(0xFF232323),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alarm Sound',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF232323),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Alarm sound + 3s vibration.',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF232323),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final ok =
                              await NotificationService.sendTestNotification(
                                isAlarm: true,
                              );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? '🔔 Alarm triggered with 3s vibration!'
                                      : '⚠️ Failed to trigger alarm.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Test',
                          style: TextStyle(fontFamily: 'serif', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Card 2: Instant Push Notification
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6E8FA).withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none,
                          size: 22,
                          color: Color(0xFF232323),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Silent Push',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF232323),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Visual banner without sound.',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF232323),
                          side: const BorderSide(color: Colors.black26),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final ok =
                              await NotificationService.sendTestNotification(
                                isAlarm: false,
                              );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? '🔕 Test push notification sent!'
                                      : '⚠️ Failed to send push.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Test',
                          style: TextStyle(fontFamily: 'serif', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Card 3: 10s Background Countdown Alarm
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFC0392B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFCE2E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          size: 22,
                          color: Color(0xFFC0392B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '10s Test Alarm',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC0392B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rings & vibrates 3s while locked.',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC0392B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final ok =
                              await NotificationService.scheduleTestCountdownAlarm(
                                seconds: 10,
                              );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? '⏱️ 10s alarm scheduled! Lock phone now to test.'
                                      : '⚠️ Failed to schedule 10s alarm.',
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Start 10s',
                          style: TextStyle(fontFamily: 'serif', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Settings Link Tile (Opens Android Notification Settings)
                InkWell(
                  onTap: () async {
                    await NotificationService.openNotificationSettings();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF232323).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: Color(0xFF232323),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notification Settings',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF232323),
                                ),
                              ),
                              Text(
                                'Open app permissions in Android settings.',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Battery Optimization Tile (Opens dialog/settings to allow background running)
                InkWell(
                  onTap: () async {
                    await NotificationService.requestIgnoreBatteryOptimizations();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF232323).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.battery_charging_full_outlined,
                          size: 18,
                          color: Color(0xFF232323),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Background Battery Settings',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF232323),
                                ),
                              ),
                              Text(
                                'Allow app to run alarms unrestricted in background.',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF232323),
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Extension to allow quick children parameter syntax
extension RowExtension on Row {
  static Row withChildren({
    required List<Widget> left,
    required List<Widget> right,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [...left, ...right],
    );
  }
}
