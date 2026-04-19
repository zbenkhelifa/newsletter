import 'package:uuid/uuid.dart';

enum SendMode { single, sequential, broadcast }

class Campaign {
  final String id;
  String name;
  String description;
  String contactListId;
  String subjectTemplate;
  String bodyTemplate;
  List<String> templateFiles;
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
    List<String>? templateFiles,
    this.sendMode = SendMode.broadcast,
    this.isActive = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        templateFiles = templateFiles ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'contactListId': contactListId,
        'subjectTemplate': subjectTemplate,
        'bodyTemplate': bodyTemplate,
        'templateFiles': templateFiles,
        'sendMode': sendMode.name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id'],
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        contactListId: j['contactListId'] ?? '',
        subjectTemplate: j['subjectTemplate'] ?? '',
        bodyTemplate: j['bodyTemplate'] ?? '',
        templateFiles: List<String>.from(j['templateFiles'] ?? []),
        sendMode: SendMode.values.firstWhere(
          (e) => e.name == j['sendMode'],
          orElse: () => SendMode.broadcast,
        ),
        isActive: j['isActive'] ?? true,
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );

  Campaign copyWith({
    String? name,
    String? description,
    String? contactListId,
    String? subjectTemplate,
    String? bodyTemplate,
    List<String>? templateFiles,
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
        templateFiles: templateFiles ?? this.templateFiles,
        sendMode: sendMode ?? this.sendMode,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
