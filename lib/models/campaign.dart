import 'package:uuid/uuid.dart';

enum SendMode { single, sequential, broadcast }

class ScheduledTemplate {
  final String filePath;
  final DateTime? sendDate;

  ScheduledTemplate({required this.filePath, this.sendDate});

  String get fileName => filePath.split('/').last;

  ScheduledTemplate copyWith({String? filePath, DateTime? sendDate, bool clearDate = false}) =>
      ScheduledTemplate(
        filePath: filePath ?? this.filePath,
        sendDate: clearDate ? null : (sendDate ?? this.sendDate),
      );

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'sendDate': sendDate?.toIso8601String(),
      };

  factory ScheduledTemplate.fromJson(Map<String, dynamic> j) => ScheduledTemplate(
        filePath: j['filePath'] ?? '',
        sendDate: j['sendDate'] != null ? DateTime.tryParse(j['sendDate']) : null,
      );
}

class Campaign {
  final String id;
  String name;
  String description;
  String contactListId;
  String subjectTemplate;
  String bodyTemplate;
  List<ScheduledTemplate> scheduledTemplates;
  SendMode sendMode;
  bool isActive;
  DateTime createdAt;

  Campaign({
    String? id,
    required this.name,
    this.description = '',
    this.contactListId = '',
    this.subjectTemplate = '',
    this.bodyTemplate = '',
    List<ScheduledTemplate>? scheduledTemplates,
    this.sendMode = SendMode.broadcast,
    this.isActive = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        scheduledTemplates = scheduledTemplates ?? [],
        createdAt = createdAt ?? DateTime.now();

  List<String> get templateFiles =>
      scheduledTemplates.map((t) => t.filePath).toList();

  ScheduledTemplate? get todayTemplate {
    final today = DateTime.now();
    try {
      return scheduledTemplates.firstWhere((t) =>
          t.sendDate != null &&
          t.sendDate!.year == today.year &&
          t.sendDate!.month == today.month &&
          t.sendDate!.day == today.day);
    } catch (_) {
      return null;
    }
  }

  ScheduledTemplate? get nextTemplate {
    final now = DateTime.now();
    final upcoming = scheduledTemplates
        .where((t) => t.sendDate != null && t.sendDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.sendDate!.compareTo(b.sendDate!));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'contactListId': contactListId,
        'subjectTemplate': subjectTemplate,
        'bodyTemplate': bodyTemplate,
        'scheduledTemplates': scheduledTemplates.map((t) => t.toJson()).toList(),
        'sendMode': sendMode.name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Campaign.fromJson(Map<String, dynamic> j) {
    List<ScheduledTemplate> templates = [];
    if (j['scheduledTemplates'] != null) {
      templates = (j['scheduledTemplates'] as List)
          .map((t) => ScheduledTemplate.fromJson(t as Map<String, dynamic>))
          .toList();
    } else if (j['templateFiles'] != null) {
      // backward compat: old format with plain file paths
      templates = (j['templateFiles'] as List)
          .map((f) => ScheduledTemplate(filePath: f as String))
          .toList();
    }
    return Campaign(
      id: j['id'],
      name: j['name'] ?? '',
      description: j['description'] ?? '',
      contactListId: j['contactListId'] ?? '',
      subjectTemplate: j['subjectTemplate'] ?? '',
      bodyTemplate: j['bodyTemplate'] ?? '',
      scheduledTemplates: templates,
      sendMode: SendMode.values.firstWhere(
        (e) => e.name == j['sendMode'],
        orElse: () => SendMode.broadcast,
      ),
      isActive: j['isActive'] ?? true,
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Campaign copyWith({
    String? name,
    String? description,
    String? contactListId,
    String? subjectTemplate,
    String? bodyTemplate,
    List<ScheduledTemplate>? scheduledTemplates,
    SendMode? sendMode,
    bool? isActive,
  }) =>
      Campaign(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        contactListId: contactListId ?? this.contactListId,
        subjectTemplate: subjectTemplate ?? this.subjectTemplate,
        bodyTemplate: bodyTemplate ?? this.bodyTemplate,
        scheduledTemplates: scheduledTemplates ?? this.scheduledTemplates,
        sendMode: sendMode ?? this.sendMode,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
