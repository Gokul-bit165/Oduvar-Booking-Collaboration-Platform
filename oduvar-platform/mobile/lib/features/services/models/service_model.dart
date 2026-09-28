// Phase 3: Service, Pricing, and OduvarService models

class ServiceModel {
  final String id;
  final String name;
  final String category;
  final String? description;
  final bool isActive;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.isActive = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'isActive': isActive,
      };
}

class PricingModel {
  final String id;
  final String oduvarServiceId;
  final int durationMinutes;
  final double amount;
  final String currency;
  final bool isActive;

  const PricingModel({
    required this.id,
    required this.oduvarServiceId,
    required this.durationMinutes,
    required this.amount,
    this.currency = 'INR',
    this.isActive = true,
  });

  String get durationLabel {
    if (durationMinutes < 60) {
      return '$durationMinutes minutes';
    } else if (durationMinutes % 60 == 0) {
      final hours = durationMinutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    } else {
      final hours = durationMinutes / 60.0;
      final formatted = hours.toStringAsFixed(1).replaceAll('.0', '');
      return '$formatted hours';
    }
  }

  String get formattedAmount {
    // Format without decimal if integer (e.g. ₹500, ₹1,200)
    final isInt = amount == amount.roundToDouble();
    final valueStr = isInt ? amount.toInt().toString() : amount.toStringAsFixed(2);
    // Add comma formatting for thousands
    final parts = valueStr.split('.');
    final whole = parts[0];
    final reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$formattedWhole';
  }

  factory PricingModel.fromJson(Map<String, dynamic> json) {
    return PricingModel(
      id: json['id'] as String,
      oduvarServiceId: json['oduvarServiceId'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'oduvarServiceId': oduvarServiceId,
        'durationMinutes': durationMinutes,
        'amount': amount,
        'currency': currency,
        'isActive': isActive,
      };
}

class OduvarServiceModel {
  final String id;
  final String profileId;
  final String serviceId;
  final String name;
  final String category;
  final String? baseDescription;
  final String? customDescription;
  final String transport;
  final double? transportFee;
  final bool isActive;
  final List<PricingModel> pricings;

  const OduvarServiceModel({
    required this.id,
    required this.profileId,
    required this.serviceId,
    required this.name,
    required this.category,
    this.baseDescription,
    this.customDescription,
    this.transport = 'TO_BE_DISCUSSED',
    this.transportFee,
    this.isActive = true,
    this.pricings = const [],
  });

  String get transportDisplay {
    switch (transport) {
      case 'INCLUDED':
        return 'Included';
      case 'NOT_INCLUDED':
        return 'Not Included';
      case 'ADDITIONAL_FEE':
        if (transportFee != null && transportFee! > 0) {
          final isInt = transportFee == transportFee!.roundToDouble();
          return 'Additional Fee (₹${isInt ? transportFee!.toInt() : transportFee!.toStringAsFixed(2)})';
        }
        return 'Additional Fee';
      case 'TO_BE_DISCUSSED':
      default:
        return 'To Be Discussed';
    }
  }

  factory OduvarServiceModel.fromJson(Map<String, dynamic> json) {
    final rawPricings = json['pricings'] as List? ?? [];
    return OduvarServiceModel(
      id: json['id'] as String,
      profileId: json['profileId'] as String? ?? '',
      serviceId: json['serviceId'] as String,
      name: json['name'] as String? ?? 'Devotional Service',
      category: json['category'] as String? ?? 'Other',
      baseDescription: json['baseDescription'] as String?,
      customDescription: json['customDescription'] as String?,
      transport: json['transport'] as String? ?? 'TO_BE_DISCUSSED',
      transportFee: json['transportFee'] != null ? (json['transportFee'] as num).toDouble() : null,
      isActive: json['isActive'] as bool? ?? true,
      pricings: rawPricings.map((p) => PricingModel.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'serviceId': serviceId,
        'name': name,
        'category': category,
        'baseDescription': baseDescription,
        'customDescription': customDescription,
        'transport': transport,
        'transportFee': transportFee,
        'isActive': isActive,
        'pricings': pricings.map((p) => p.toJson()).toList(),
      };
}
