import 'package:uuid/uuid.dart';

enum SendStatus { success, failed, skipped }

class SendRecord {
  final String id;
  final String campaignId;
  final String campaignName;
  final String recipientEmail;
  final String recipientName;
  final String subject;
  final SendStatus status;
  final String? error;
  final DateTime sentAt;

  SendRecord({
    String? id,
    required this.campaignId,
    required this.campaignName,
    required this.recipientEmail,
    required this.recipientName,
    required this.subject,
    required this.status,
    this.error,
    DateTime? sentAt,
  })  : id = id ?? const Uuid().v4(),
        sentAt = sentAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'campaignId': campaignId,
        'campaignName': campaignName,
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'subject': subject,
        'status': status.name,
        'error': error,
        'sentAt': sentAt.toIso8601String(),
      };

  factory SendRecord.fromJson(Map<String, dynamic> j) => SendRecord(
        id: j['id'],
        campaignId: j['campaignId'] ?? '',
        campaignName: j['campaignName'] ?? '',
        recipientEmail: j['recipientEmail'] ?? '',
        recipientName: j['recipientName'] ?? '',
        subject: j['subject'] ?? '',
        status: SendStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => SendStatus.failed,
        ),
        error: j['error'],
        sentAt: DateTime.tryParse(j['sentAt'] ?? '') ?? DateTime.now(),
      );
}
