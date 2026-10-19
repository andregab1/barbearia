typedef Weekday = int;

class ScheduleRange {
  final String id;
  final String start;
  final String end;

  const ScheduleRange({
    required this.id,
    required this.start,
    required this.end,
  });

  ScheduleRange copyWith({String? id, String? start, String? end}) {
    return ScheduleRange(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduleRange &&
        other.id == id &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(id, start, end);

  factory ScheduleRange.fromJson(Map<String, dynamic> json, {int index = 0}) {
    return ScheduleRange(
      id: '${json['id'] ?? 'range-$index'}',
      start:
          '${json['start'] ?? json['hora_inicio'] ?? '08:00'}'.substring(0, 5),
      end: '${json['end'] ?? json['hora_fim'] ?? '18:00'}'.substring(0, 5),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
      };
}

class DaySchedule {
  final Weekday weekday;
  final bool enabled;
  final List<ScheduleRange> ranges;

  const DaySchedule({
    required this.weekday,
    required this.enabled,
    required this.ranges,
  });

  DaySchedule copyWith(
      {Weekday? weekday, bool? enabled, List<ScheduleRange>? ranges}) {
    return DaySchedule(
      weekday: weekday ?? this.weekday,
      enabled: enabled ?? this.enabled,
      ranges: ranges ?? this.ranges,
    );
  }

  factory DaySchedule.fromJson(Weekday weekday, Map<String, dynamic> json) {
    final rawRanges = json['faixas'];
    final ranges = rawRanges is List
        ? rawRanges
            .whereType<Map>()
            .toList()
            .asMap()
            .entries
            .map((entry) => ScheduleRange.fromJson(
                  Map<String, dynamic>.from(entry.value),
                  index: entry.key,
                ))
            .toList()
        : <ScheduleRange>[];

    if (ranges.isEmpty &&
        json['hora_inicio'] != null &&
        json['hora_fim'] != null) {
      ranges.add(ScheduleRange.fromJson(json));
    }

    return DaySchedule(
      weekday: weekday,
      enabled: json['ativo'] == true || json['enabled'] == true,
      ranges: ranges,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'enabled': enabled,
        'ranges': ranges.map((range) => range.toJson()).toList(),
      };
}

class WeeklySchedule {
  final int professionalId;
  final List<DaySchedule> days;
  final int? version;
  final String? updatedAt;

  const WeeklySchedule({
    required this.professionalId,
    required this.days,
    this.version,
    this.updatedAt,
  });

  DaySchedule day(Weekday weekday) {
    return days.firstWhere(
      (item) => item.weekday == weekday,
      orElse: () =>
          DaySchedule(weekday: weekday, enabled: false, ranges: const []),
    );
  }

  WeeklySchedule copyWith(
      {int? professionalId,
      List<DaySchedule>? days,
      int? version,
      String? updatedAt}) {
    return WeeklySchedule(
      professionalId: professionalId ?? this.professionalId,
      days: days ?? this.days,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toApiPayload() {
    final horarios = <String, dynamic>{};
    for (final item in days) {
      final ranges = item.ranges
          .map((range) => {
                'id': range.id,
                'start': range.start,
                'end': range.end,
              })
          .toList();
      horarios['${item.weekday}'] = {
        'ativo': item.enabled,
        'faixas': ranges,
        if (ranges.isNotEmpty) ...{
          'hora_inicio': ranges.first['start'],
          'hora_fim': ranges.last['end'],
        },
      };
    }
    return {'horarios': horarios};
  }

  factory WeeklySchedule.fromApi(
      int professionalId, Map<String, dynamic> json) {
    final days = <DaySchedule>[];
    for (var weekday = 0; weekday < 7; weekday++) {
      final raw = json['$weekday'];
      days.add(DaySchedule.fromJson(
        weekday,
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
      ));
    }
    return WeeklySchedule(professionalId: professionalId, days: days);
  }
}

class ScheduleTemplateDay {
  final bool enabled;
  final List<ScheduleRange> ranges;

  const ScheduleTemplateDay({required this.enabled, required this.ranges});
}

class ScheduleTemplate {
  final String id;
  final String name;
  final String description;
  final Map<Weekday, ScheduleTemplateDay> days;

  const ScheduleTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.days,
  });
}
