import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_app/main.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FolderlyScheduleApp());
    expect(find.byType(FolderlyScheduleApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('CourseClass JSON serialization with imagePath', () {
    final course = CourseClass(
      id: 'test_1',
      title: 'Physics',
      instructor: 'Dr. Maria Santos',
      room: 'Room 101',
      dayOfWeek: 1,
      startHour: 9,
      startMinute: 0,
      endHour: 10,
      endMinute: 30,
      colorValue: 0xFFD6E8FA,
      imagePath:
          '/data/user/0/com.example.schedule_app/app_flutter/subject_images/subj_123.jpg',
    );

    final json = course.toJson();
    expect(
      json['imagePath'],
      '/data/user/0/com.example.schedule_app/app_flutter/subject_images/subj_123.jpg',
    );

    final deserialized = CourseClass.fromJson(json);
    expect(deserialized.id, 'test_1');
    expect(deserialized.title, 'Physics');
    expect(deserialized.instructor, 'Dr. Maria Santos');
    expect(
      deserialized.imagePath,
      '/data/user/0/com.example.schedule_app/app_flutter/subject_images/subj_123.jpg',
    );
    expect(deserialized.startTimeFormatted, '9:00 AM');
    expect(deserialized.endTimeFormatted, '10:30 AM');
  });

  test('CourseClass without imagePath', () {
    final course = CourseClass(
      id: 'test_2',
      title: 'Math',
      room: 'Room 202',
      dayOfWeek: 2,
      startHour: 13,
      startMinute: 15,
      endHour: 14,
      endMinute: 45,
      colorValue: 0xFFFFF8C9,
    );

    final json = course.toJson();
    expect(json['imagePath'], isNull);

    final deserialized = CourseClass.fromJson(json);
    expect(deserialized.id, 'test_2');
    expect(deserialized.instructor, isEmpty);
    expect(deserialized.imagePath, isNull);
    expect(deserialized.reminderMinutes, 15);
    expect(deserialized.playAlarmSound, isTrue);
    expect(deserialized.startTimeFormatted, '1:15 PM');
    expect(deserialized.endTimeFormatted, '2:45 PM');
  });

  test('CourseClass with custom reminderMinutes and alarm disabled', () {
    final course = CourseClass(
      id: 'test_3',
      title: 'Chemistry',
      room: 'Lab 102',
      dayOfWeek: 3,
      startHour: 8,
      startMinute: 0,
      endHour: 10,
      endMinute: 0,
      colorValue: 0xFFD8F3DC,
      reminderMinutes: 30,
      playAlarmSound: false,
    );

    final json = course.toJson();
    expect(json['reminderMinutes'], 30);
    expect(json['playAlarmSound'], isFalse);

    final deserialized = CourseClass.fromJson(json);
    expect(deserialized.reminderMinutes, 30);
    expect(deserialized.playAlarmSound, isFalse);
  });

  test('CourseClass with reminder turned Off (0 minutes)', () {
    final course = CourseClass(
      id: 'test_4',
      title: 'Biology',
      room: 'Bio 1',
      dayOfWeek: 4,
      startHour: 10,
      startMinute: 0,
      endHour: 11,
      endMinute: 30,
      colorValue: 0xFFFCE2E6,
      reminderMinutes: 0,
      playAlarmSound: true,
    );

    final json = course.toJson();
    expect(json['reminderMinutes'], 0);
    expect(json['reminders'], isEmpty);

    final deserialized = CourseClass.fromJson(json);
    expect(deserialized.reminderMinutes, 0);
    expect(deserialized.reminders, isEmpty);
  });

  test('CourseClass with multiple alarm and push notification reminders', () {
    final course = CourseClass(
      id: 'test_5',
      title: 'Operating Systems',
      room: 'Room 404',
      dayOfWeek: 5,
      startHour: 14,
      startMinute: 0,
      endHour: 16,
      endMinute: 0,
      colorValue: 0xFFE8E0F8,
      reminders: const [
        ClassReminder(minutesBefore: 30, isAlarm: false),
        ClassReminder(minutesBefore: 5, isAlarm: true),
      ],
    );

    expect(course.reminders.length, 2);
    expect(course.reminders[0].label, '30m');
    expect(course.reminders[0].isAlarm, isFalse);
    expect(course.reminders[1].label, '5m');
    expect(course.reminders[1].isAlarm, isTrue);

    final json = course.toJson();
    expect(json['reminders'], isA<List>());
    expect((json['reminders'] as List).length, 2);

    final deserialized = CourseClass.fromJson(json);
    expect(deserialized.reminders.length, 2);
    expect(deserialized.reminders[0].minutesBefore, 30);
    expect(deserialized.reminders[0].isAlarm, isFalse);
    expect(deserialized.reminders[1].minutesBefore, 5);
    expect(deserialized.reminders[1].isAlarm, isTrue);
  });

  test('ClassReminder label formats correctly for hours and minutes', () {
    expect(const ClassReminder(minutesBefore: 5).label, '5m');
    expect(const ClassReminder(minutesBefore: 15).label, '15m');
    expect(const ClassReminder(minutesBefore: 60).label, '1h');
    expect(const ClassReminder(minutesBefore: 90).label, '1h 30m');
  });
}
