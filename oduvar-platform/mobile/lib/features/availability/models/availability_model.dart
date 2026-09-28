// Availability models (Phase 4).
//
// All times are "HH:mm" wall-clock strings in the Oduvar's schedule timezone
// ([BookingRulesModel.timezone]). The app never converts between zones; it
// displays the Oduvar's own local times and labels the timezone.

const List<String> kDaysOfWeek = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

String dayLabel(String dayOfWeek) =>
    dayOfWeek[0] + dayOfWeek.substring(1).toLowerCase();

int timeToMinutes(String t) =>
    int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));

/// "09:00" -> "9:00 AM"
String formatTime12(String t) {
  final m = timeToMinutes(t);
  final h24 = m ~/ 60;
  final min = m % 60;
  final suffix = h24 >= 12 ? 'PM' : 'AM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h:${min.toString().padLeft(2, '0')} $suffix';
}

String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return h == 1 ? '1 hour' : '$h hours';
  return '${h}h ${m}m';
}

class TimeWindowModel {
  final String startTime;
  final String endTime;

  const TimeWindowModel({required this.startTime, required this.endTime});

  bool get isValid => timeToMinutes(startTime) < timeToMinutes(endTime);

  factory TimeWindowModel.fromJson(Map<String, dynamic> j) => TimeWindowModel(
        startTime: (j['startTime'] ?? j['start']) as String,
        endTime: (j['endTime'] ?? j['end']) as String,
      );

  Map<String, dynamic> toJson() => {'startTime': startTime, 'endTime': endTime};

  TimeWindowModel copyWith({String? startTime, String? endTime}) =>
      TimeWindowModel(
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );

  String get label => '${formatTime12(startTime)} – ${formatTime12(endTime)}';
}

class WeeklyAvailabilityModel {
  final String dayOfWeek;
  final bool isActive;
  final List<TimeWindowModel> windows;

  const WeeklyAvailabilityModel({
    required this.dayOfWeek,
    required this.isActive,
    this.windows = const [],
  });

  factory WeeklyAvailabilityModel.fromJson(Map<String, dynamic> j) =>
      WeeklyAvailabilityModel(
        dayOfWeek: j['dayOfWeek'] as String,
        isActive: j['isActive'] as bool? ?? false,
        windows: (j['windows'] as List? ?? [])
            .map((w) => TimeWindowModel.fromJson(w as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'isActive': isActive,
        'windows': windows.map((w) => w.toJson()).toList(),
      };

  WeeklyAvailabilityModel copyWith({bool? isActive, List<TimeWindowModel>? windows}) =>
      WeeklyAvailabilityModel(
        dayOfWeek: dayOfWeek,
        isActive: isActive ?? this.isActive,
        windows: windows ?? this.windows,
      );

  /// Client-side check for immediate form feedback only; the server is authoritative.
  bool get hasValidWindows {
    if (!isActive) return true;
    if (windows.isEmpty) return false;
    final sorted = [...windows]
      ..sort((a, b) => timeToMinutes(a.startTime).compareTo(timeToMinutes(b.startTime)));
    for (var i = 0; i < sorted.length; i++) {
      if (!sorted[i].isValid) return false;
      if (i > 0 && timeToMinutes(sorted[i].startTime) < timeToMinutes(sorted[i - 1].endTime)) {
        return false;
      }
    }
    return true;
  }

  String get summary =>
      isActive && windows.isNotEmpty ? windows.map((w) => w.label).join(', ') : 'Unavailable';
}

class BookingRulesModel {
  final int minimumDurationMinutes;
  final int maximumDurationMinutes;
  final int bufferMinutes;
  final String timezone;

  const BookingRulesModel({
    this.minimumDurationMinutes = 30,
    this.maximumDurationMinutes = 180,
    this.bufferMinutes = 0,
    this.timezone = 'Asia/Kolkata',
  });

  factory BookingRulesModel.fromJson(Map<String, dynamic> j) => BookingRulesModel(
        minimumDurationMinutes: j['minimumDurationMinutes'] as int? ?? 30,
        maximumDurationMinutes: j['maximumDurationMinutes'] as int? ?? 180,
        bufferMinutes: j['bufferMinutes'] as int? ?? 0,
        timezone: j['timezone'] as String? ?? 'Asia/Kolkata',
      );

  BookingRulesModel copyWith({int? minimumDurationMinutes, int? maximumDurationMinutes, int? bufferMinutes}) =>
      BookingRulesModel(
        minimumDurationMinutes: minimumDurationMinutes ?? this.minimumDurationMinutes,
        maximumDurationMinutes: maximumDurationMinutes ?? this.maximumDurationMinutes,
        bufferMinutes: bufferMinutes ?? this.bufferMinutes,
        timezone: timezone,
      );

  /// Selectable durations for clients: min..max in 30-minute steps.
  List<int> get durationOptions => [
        for (var d = minimumDurationMinutes; d <= maximumDurationMinutes; d += 30) d,
      ];
}

class AvailabilityOverrideModel {
  final String id;
  final String date; // YYYY-MM-DD
  final String type; // UNAVAILABLE | AVAILABLE
  final String? startTime;
  final String? endTime;
  final String? reason;

  const AvailabilityOverrideModel({
    required this.id,
    required this.date,
    required this.type,
    this.startTime,
    this.endTime,
    this.reason,
  });

  bool get isAvailable => type == 'AVAILABLE';
  bool get isAllDay => startTime == null || endTime == null;

  factory AvailabilityOverrideModel.fromJson(Map<String, dynamic> j) =>
      AvailabilityOverrideModel(
        id: j['id'] as String,
        date: j['date'] as String,
        type: j['type'] as String,
        startTime: j['startTime'] as String?,
        endTime: j['endTime'] as String?,
        reason: j['reason'] as String?,
      );

  Map<String, dynamic> toPayload() => {
        'date': date,
        'type': type,
        'startTime': startTime,
        'endTime': endTime,
        'reason': (reason == null || reason!.isEmpty) ? null : reason,
      };
}

/// Calendar day status. PENDING / BOOKED are reserved for the booking phase and
/// are only rendered if the backend ever returns them; nothing is faked here.
enum DayStatus { available, unavailable, pending, booked }

DayStatus dayStatusFrom(String? s) {
  switch (s) {
    case 'AVAILABLE':
      return DayStatus.available;
    case 'PENDING':
      return DayStatus.pending;
    case 'BOOKED':
      return DayStatus.booked;
    default:
      return DayStatus.unavailable;
  }
}

class CalendarDayModel {
  final String date;
  final DayStatus status;

  const CalendarDayModel({required this.date, required this.status});

  factory CalendarDayModel.fromJson(Map<String, dynamic> j) => CalendarDayModel(
        date: j['date'] as String,
        status: dayStatusFrom(j['status'] as String?),
      );
}

/// Backend-computed availability for one date (windows + bookable start times).
class DayAvailabilityModel {
  final String date;
  final bool isAvailable;
  final int? durationMinutes;
  final List<TimeWindowModel> workingWindows;
  final List<String> slots;

  const DayAvailabilityModel({
    required this.date,
    required this.isAvailable,
    this.durationMinutes,
    this.workingWindows = const [],
    this.slots = const [],
  });

  factory DayAvailabilityModel.fromJson(Map<String, dynamic> j) => DayAvailabilityModel(
        date: j['date'] as String,
        isAvailable: j['isAvailable'] as bool? ?? false,
        durationMinutes: j['durationMinutes'] as int?,
        workingWindows: (j['workingWindows'] as List? ?? [])
            .map((w) => TimeWindowModel.fromJson(w as Map<String, dynamic>))
            .toList(),
        slots: (j['slots'] as List? ?? []).map((s) => s as String).toList(),
      );
}

/// Full availability payload (owner or public).
class AvailabilityModel {
  final BookingRulesModel rules;
  final List<WeeklyAvailabilityModel> weekly;
  final List<AvailabilityOverrideModel> overrides;

  const AvailabilityModel({
    required this.rules,
    required this.weekly,
    this.overrides = const [],
  });

  factory AvailabilityModel.fromJson(Map<String, dynamic> j) {
    final byDay = {
      for (final w in (j['weekly'] as List? ?? []))
        (w as Map<String, dynamic>)['dayOfWeek'] as String: WeeklyAvailabilityModel.fromJson(w),
    };
    return AvailabilityModel(
      rules: BookingRulesModel.fromJson(
          (j['rules'] as Map<String, dynamic>?) ?? {'timezone': j['timezone']}),
      weekly: [
        for (final d in kDaysOfWeek)
          byDay[d] ?? WeeklyAvailabilityModel(dayOfWeek: d, isActive: false),
      ],
      overrides: (j['overrides'] as List? ?? [])
          .map((o) => AvailabilityOverrideModel.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  factory AvailabilityModel.empty() => AvailabilityModel(
        rules: const BookingRulesModel(),
        weekly: [for (final d in kDaysOfWeek) WeeklyAvailabilityModel(dayOfWeek: d, isActive: false)],
      );
}
