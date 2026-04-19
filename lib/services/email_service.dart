import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/smtp_config.dart';
import '../models/contact.dart';
import '../models/campaign.dart';
import '../models/send_record.dart';
import 'template_service.dart';

class SendResult {
  final int sent;
  final int failed;
  final int skipped;
  final List<String> errors;

  SendResult({
    required this.sent,
    required this.failed,
    required this.skipped,
    required this.errors,
  });
}

class EmailService {
  final SmtpConfig config;

  EmailService(this.config);

  SmtpServer _buildServer() {
    if (config.useTls) {
      return SmtpServer(
        config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        ssl: config.port == 465,
        ignoreBadCertificate: false,
        allowInsecure: false,
      );
    } else {
      return SmtpServer(
        config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        ssl: false,
        allowInsecure: true,
      );
    }
  }

  Future<void> testConnection() async {
    final server = _buildServer();
    final conn = PersistentConnection(server);
    try {
      await conn.send(Message()
        ..from = Address(config.username, config.senderName)
        ..recipients = [config.username]
        ..subject = 'Test Newsletter App'
        ..text = 'Connexion SMTP réussie.');
    } finally {
      await conn.close();
    }
  }

  Future<SendRecord> sendToContact({
    required Campaign campaign,
    required Contact contact,
    required String subject,
    required String htmlBody,
  }) async {
    try {
      final server = _buildServer();
      final message = Message()
        ..from = Address(config.username, config.senderName)
        ..recipients = [contact.email]
        ..subject = subject
        ..html = htmlBody;

      await send(message, server);

      return SendRecord(
        campaignId: campaign.id,
        campaignName: campaign.name,
        recipientEmail: contact.email,
        recipientName: contact.name,
        subject: subject,
        status: SendStatus.success,
      );
    } catch (e) {
      return SendRecord(
        campaignId: campaign.id,
        campaignName: campaign.name,
        recipientEmail: contact.email,
        recipientName: contact.name,
        subject: subject,
        status: SendStatus.failed,
        error: e.toString(),
      );
    }
  }

  Future<void> sendBatch({
    required Campaign campaign,
    required List<Contact> contacts,
    required String subjectTemplate,
    required String bodyTemplate,
    required Set<String> alreadySent,
    required void Function(int current, int total, SendRecord record) onProgress,
    required void Function(String error) onError,
  }) async {
    final server = _buildServer();
    final conn = PersistentConnection(server);

    try {
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        if (!contact.isValid) continue;

        if (alreadySent.contains(contact.email.toLowerCase())) {
          final record = SendRecord(
            campaignId: campaign.id,
            campaignName: campaign.name,
            recipientEmail: contact.email,
            recipientName: contact.name,
            subject: subjectTemplate,
            status: SendStatus.skipped,
          );
          onProgress(i + 1, contacts.length, record);
          continue;
        }

        try {
          final subject =
              TemplateService.applyTemplate(subjectTemplate, contact);
          final body = TemplateService.applyTemplate(bodyTemplate, contact);
          final html = TemplateService.buildHtmlBody(body);

          final message = Message()
            ..from = Address(config.username, config.senderName)
            ..recipients = [contact.email]
            ..subject = subject
            ..html = html;

          await conn.send(message);

          final record = SendRecord(
            campaignId: campaign.id,
            campaignName: campaign.name,
            recipientEmail: contact.email,
            recipientName: contact.name,
            subject: subject,
            status: SendStatus.success,
          );
          onProgress(i + 1, contacts.length, record);
        } catch (e) {
          final record = SendRecord(
            campaignId: campaign.id,
            campaignName: campaign.name,
            recipientEmail: contact.email,
            recipientName: contact.name,
            subject: subjectTemplate,
            status: SendStatus.failed,
            error: e.toString(),
          );
          onProgress(i + 1, contacts.length, record);
          onError('${contact.email}: $e');
        }
      }
    } finally {
      await conn.close();
    }
  }
}
