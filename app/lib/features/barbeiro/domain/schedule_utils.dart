import 'schedule_models.dart';

const int dayStartMinutes = 7 * 60;
const int dayEndMinutes = 21 * 60;
const int snapMinutes = 15;

int timeToMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return -1;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return -1;
  }
  return hour * 60 + minute;
}

String minutesToTime(int minutes) {
  final safeMinutes = minutes.clamp(0, 23 * 60 + 59);
  final hour = safeMinutes ~/ 60;
  final minute = safeMinutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

int durationMinutes(ScheduleRange range) =>
    timeToMinutes(range.end) - timeToMinutes(range.start);

int snapMinutesValue(int value) => (value / snapMinutes).round() * snapMinutes;

List<ScheduleRange> sortRanges(Iterable<ScheduleRange> ranges) {
  final sorted = [...ranges];
  sorted
      .sort((a, b) => timeToMinutes(a.start).compareTo(timeToMinutes(b.start)));
  return sorted;
}

bool validateRange(ScheduleRange range) {
  final start = timeToMinutes(range.start);
  final end = timeToMinutes(range.end);
  return start >= dayStartMinutes && end <= dayEndMinutes && start < end;
}

bool rangesOverlap(ScheduleRange first, ScheduleRange second) {
  final firstStart = timeToMinutes(first.start);
  final firstEnd = timeToMinutes(first.end);
  final secondStart = timeToMinutes(second.start);
  final secondEnd = timeToMinutes(second.end);
  return firstStart < secondEnd && secondStart < firstEnd;
}

List<String> validateDay(DaySchedule day) {
  if (!day.enabled) return const [];
  final errors = <String>[];
  for (final range in day.ranges) {
    if (!validateRange(range))
      errors.add('${range.start} - ${range.end} é inválido.');
  }
  final sorted = sortRanges(day.ranges);
  for (var index = 1; index < sorted.length; index++) {
    if (rangesOverlap(sorted[index - 1], sorted[index])) {
      errors.add('Existem horários sobrepostos em ${day.weekday}.');
      break;
    }
  }
  return errors;
}

List<String> validateWeeklySchedule(WeeklySchedule schedule) {
  return schedule.days.expand(validateDay).toList();
}

int calculateDayMinutes(DaySchedule day) {
  if (!day.enabled) return 0;
  return day.ranges.fold(0, (total, range) => total + durationMinutes(range));
}

int calculateWeeklyMinutes(WeeklySchedule schedule) {
  return schedule.days
      .fold(0, (total, day) => total + calculateDayMinutes(day));
}

int calculateAverageMinutes(WeeklySchedule schedule) {
  final activeDays = schedule.days.where((day) => day.enabled).length;
  if (activeDays == 0) return 0;
  return (calculateWeeklyMinutes(schedule) / activeDays).round();
}

String formatMinutes(int total) {
  final hours = total ~/ 60;
  final minutes = total % 60;
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}min';
}

List<ScheduleRange> deriveBreaks(Iterable<ScheduleRange> ranges) {
  final sorted = sortRanges(ranges);
  final breaks = <ScheduleRange>[];
  for (var index = 0; index < sorted.length - 1; index++) {
    final current = sorted[index];
    final next = sorted[index + 1];
    if (timeToMinutes(current.end) < timeToMinutes(next.start)) {
      breaks.add(ScheduleRange(
        id: 'break-${current.id}-${next.id}',
        start: current.end,
        end: next.start,
      ));
    }
  }
  return breaks;
}

DaySchedule copyScheduleDay(DaySchedule source, Weekday weekday) {
  return DaySchedule(
    weekday: weekday,
    enabled: source.enabled,
    ranges: source.ranges
        .map((range) => range.copyWith(
            id: '$weekday-${range.id}-${DateTime.now().microsecondsSinceEpoch}'))
        .toList(),
  );
}

WeeklySchedule applyScheduleTemplate(
    WeeklySchedule current, ScheduleTemplate template) {
  final days = current.days.map((day) {
    final templateDay = template.days[day.weekday];
    if (templateDay == null)
      return day.copyWith(enabled: false, ranges: const []);
    return day.copyWith(
      enabled: templateDay.enabled,
      ranges: templateDay.ranges
          .map((range) => range.copyWith(
              id: '${day.weekday}-${range.id}-${DateTime.now().microsecondsSinceEpoch}'))
          .toList(),
    );
  }).toList();
  return current.copyWith(days: days);
}
