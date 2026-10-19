import 'package:flutter_test/flutter_test.dart';

import 'package:getcutt/features/barbeiro/domain/schedule_models.dart';
import 'package:getcutt/features/barbeiro/domain/schedule_utils.dart';

void main() {
  final weekdayRanges = [
    const ScheduleRange(id: 'morning', start: '08:00', end: '12:00'),
    const ScheduleRange(id: 'afternoon', start: '13:00', end: '18:00'),
  ];

  test('converts times to minutes and back', () {
    expect(timeToMinutes('08:30'), 510);
    expect(minutesToTime(510), '08:30');
  });

  test('detects overlaps but allows adjacent ranges', () {
    expect(
      rangesOverlap(
        const ScheduleRange(id: 'a', start: '08:00', end: '12:00'),
        const ScheduleRange(id: 'b', start: '11:00', end: '13:00'),
      ),
      isTrue,
    );
    expect(
      rangesOverlap(
        const ScheduleRange(id: 'a', start: '08:00', end: '12:00'),
        const ScheduleRange(id: 'b', start: '12:00', end: '13:00'),
      ),
      isFalse,
    );
  });

  test('derives breaks between working ranges', () {
    expect(deriveBreaks(weekdayRanges), [
      const ScheduleRange(
          id: 'break-morning-afternoon', start: '12:00', end: '13:00'),
    ]);
  });

  test('calculates the real weekly total and average', () {
    final schedule = WeeklySchedule(
      professionalId: 1,
      days: [
        for (var weekday = 1; weekday <= 5; weekday++)
          DaySchedule(weekday: weekday, enabled: true, ranges: weekdayRanges),
        const DaySchedule(
          weekday: 6,
          enabled: true,
          ranges: [ScheduleRange(id: 'saturday', start: '09:00', end: '14:00')],
        ),
        const DaySchedule(weekday: 0, enabled: false, ranges: []),
      ],
    );

    expect(calculateWeeklyMinutes(schedule), 3000);
    expect(formatMinutes(calculateWeeklyMinutes(schedule)), '50h');
    expect(calculateAverageMinutes(schedule), 500);
  });

  test('rejects invalid and overlapping days', () {
    final invalid = DaySchedule(
      weekday: 1,
      enabled: true,
      ranges: [
        const ScheduleRange(id: 'a', start: '10:00', end: '08:00'),
        const ScheduleRange(id: 'b', start: '11:00', end: '14:00'),
      ],
    );
    expect(validateDay(invalid), isNotEmpty);
  });
}
