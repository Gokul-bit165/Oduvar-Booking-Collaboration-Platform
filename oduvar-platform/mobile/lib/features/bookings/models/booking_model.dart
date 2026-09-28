// Phase 6: booking models.
//
// All display values come from the server's stored price SNAPSHOT (never recomputed from the
// Oduvar's current pricing). The app never sends an amount when creating a booking.

enum BookingStatus { pending, confirmed, rejected, cancelled, completed }

BookingStatus bookingStatusFrom(String? s) {
  switch (s) {
    case 'CONFIRMED':
      return BookingStatus.confirmed;
    case 'REJECTED':
      return BookingStatus.rejected;
    case 'CANCELLED':
      return BookingStatus.cancelled;
    case 'COMPLETED':
      return BookingStatus.completed;
    default:
      return BookingStatus.pending;
  }
}

extension BookingStatusX on BookingStatus {
  String get apiValue => name.toUpperCase();
  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }
}

/// Event types a booking can be for (same set the backend validates).
const List<MapEntry<String, String>> kBookingEventTypes = [
  MapEntry('HOSPITAL', 'Hospital'),
  MapEntry('BEDRIDDEN_PATIENT', 'Bedridden Patient'),
  MapEntry('GENERAL', 'General'),
  MapEntry('FUNCTION', 'Function'),
  MapEntry('TEMPLE', 'Temple'),
  MapEntry('FUNERAL', 'Funeral'),
  MapEntry('OTHER', 'Other'),
];

String eventTypeLabel(String key) {
  for (final e in kBookingEventTypes) {
    if (e.key == key) return e.value;
  }
  return key;
}

/// 1200 -> "₹1,200", 1200.5 -> "₹1,200.50"
String formatMoney(double v) {
  final isInt = v == v.roundToDouble();
  final s = isInt ? v.toInt().toString() : v.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'(\d+?)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '₹$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "2026-10-20" -> "20 October 2026"
String formatBookingDate(String date) =>
    '${int.parse(date.substring(8, 10))} ${_months[int.parse(date.substring(5, 7)) - 1]} ${date.substring(0, 4)}';

/// "18:00" -> "6:00 PM"
String formatBookingTime(String t) {
  final h24 = int.parse(t.substring(0, 2));
  final m = t.substring(3, 5);
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h:$m ${h24 >= 12 ? 'PM' : 'AM'}';
}

String bookingDurationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return h == 1 ? '1 hour' : '$h hours';
  return '${h}h ${m}m';
}

class BookingPriceModel {
  final double? serviceAmount;
  final double? transportFee;

  /// null => "To Be Discussed" (server never invents a total).
  final double? totalAmount;
  final bool totalKnown;
  final String currency;

  const BookingPriceModel({
    this.serviceAmount,
    this.transportFee,
    this.totalAmount,
    this.totalKnown = false,
    this.currency = 'INR',
  });

  factory BookingPriceModel.fromJson(Map<String, dynamic> j) => BookingPriceModel(
        serviceAmount: (j['serviceAmount'] as num?)?.toDouble(),
        transportFee: (j['transportFee'] as num?)?.toDouble(),
        totalAmount: (j['totalAmount'] as num?)?.toDouble(),
        totalKnown: j['totalKnown'] as bool? ?? (j['totalAmount'] != null),
        currency: j['currency'] as String? ?? 'INR',
      );

  String get totalLabel => totalKnown && totalAmount != null ? formatMoney(totalAmount!) : 'To Be Discussed';
}

class BookingModel {
  final String id;
  final BookingStatus status;
  final String? statusReason;
  final String oduvarId;
  final String oduvarName;
  final String? oduvarPhoto;
  final String clientId;
  final String clientName;
  final String serviceName;
  final String date; // YYYY-MM-DD, wall-clock in the Oduvar's timezone
  final String startTime; // HH:mm
  final String? endTime;
  final int durationMinutes;
  final String timezone;
  final String eventType;
  final String songType;
  final String description;
  final String eventLocation;
  final String phone1;
  final String? phone2;
  final String transportOption;
  final BookingPriceModel price;
  final DateTime? createdAt;

  const BookingModel({
    required this.id,
    required this.status,
    this.statusReason,
    required this.oduvarId,
    required this.oduvarName,
    this.oduvarPhoto,
    required this.clientId,
    required this.clientName,
    required this.serviceName,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    this.timezone = 'Asia/Kolkata',
    required this.eventType,
    this.songType = '',
    this.description = '',
    this.eventLocation = '',
    this.phone1 = '',
    this.phone2,
    this.transportOption = 'TO_BE_DISCUSSED',
    this.price = const BookingPriceModel(),
    this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> j) {
    final oduvar = (j['oduvar'] as Map<String, dynamic>?) ?? const {};
    final client = (j['client'] as Map<String, dynamic>?) ?? const {};
    final service = (j['service'] as Map<String, dynamic>?) ?? const {};
    final transport = (j['transport'] as Map<String, dynamic>?) ?? const {};
    return BookingModel(
      id: j['id'] as String,
      status: bookingStatusFrom(j['status'] as String?),
      statusReason: j['statusReason'] as String?,
      oduvarId: oduvar['id'] as String? ?? '',
      oduvarName: oduvar['name'] as String? ?? '',
      oduvarPhoto: oduvar['profilePhoto'] as String?,
      clientId: client['id'] as String? ?? '',
      clientName: client['name'] as String? ?? '',
      serviceName: service['name'] as String? ?? '',
      date: j['date'] as String,
      startTime: j['startTime'] as String,
      endTime: j['endTime'] as String?,
      durationMinutes: j['durationMinutes'] as int? ?? 0,
      timezone: j['timezone'] as String? ?? 'Asia/Kolkata',
      eventType: j['eventType'] as String? ?? '',
      songType: j['songType'] as String? ?? '',
      description: j['description'] as String? ?? '',
      eventLocation: j['eventLocation'] as String? ?? '',
      phone1: j['phone1'] as String? ?? '',
      phone2: j['phone2'] as String?,
      transportOption: transport['option'] as String? ?? 'TO_BE_DISCUSSED',
      price: BookingPriceModel.fromJson((j['price'] as Map<String, dynamic>?) ?? const {}),
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
    );
  }

  BookingModel copyWithStatus(BookingStatus s, {String? reason}) => BookingModel(
        id: id, status: s, statusReason: reason ?? statusReason, oduvarId: oduvarId, oduvarName: oduvarName,
        oduvarPhoto: oduvarPhoto, clientId: clientId, clientName: clientName, serviceName: serviceName,
        date: date, startTime: startTime, endTime: endTime, durationMinutes: durationMinutes, timezone: timezone,
        eventType: eventType, songType: songType, description: description, eventLocation: eventLocation,
        phone1: phone1, phone2: phone2, transportOption: transportOption, price: price, createdAt: createdAt,
      );

  bool get canBeCancelledByClient => status == BookingStatus.pending || status == BookingStatus.confirmed;
}

class BookingPage {
  final List<BookingModel> items;
  final int page;
  final int total;
  final bool hasNext;
  const BookingPage({required this.items, this.page = 1, this.total = 0, this.hasNext = false});

  factory BookingPage.fromJson(Map<String, dynamic> j) => BookingPage(
        items: (j['items'] as List? ?? []).map((e) => BookingModel.fromJson(e as Map<String, dynamic>)).toList(),
        page: j['page'] as int? ?? 1,
        total: j['total'] as int? ?? 0,
        hasNext: j['hasNext'] as bool? ?? false,
      );
}
