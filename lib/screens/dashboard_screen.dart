import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/send_record.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vue d\'ensemble',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  icon: Icons.campaign,
                  label: 'Campagnes',
                  value: app.campaigns.length.toString(),
                  color: Colors.blue,
                ),
                _StatCard(
                  icon: Icons.people,
                  label: 'Listes de contacts',
                  value: app.contactLists.length.toString(),
                  color: Colors.green,
                ),
                _StatCard(
                  icon: Icons.check_circle,
                  label: 'Emails envoyés',
                  value: app.totalSent.toString(),
                  color: Colors.teal,
                ),
                _StatCard(
                  icon: Icons.error,
                  label: 'Échecs',
                  value: app.totalFailed.toString(),
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (!app.smtp.isConfigured)
              _WarningBanner(
                icon: Icons.warning_amber,
                message:
                    'SMTP non configuré. Allez dans "SMTP" pour configurer votre serveur d\'envoi.',
                color: Colors.orange,
              ),
            if (app.campaigns.isEmpty)
              _WarningBanner(
                icon: Icons.info_outline,
                message:
                    'Aucune campagne. Créez une campagne dans "Campagnes" pour commencer.',
                color: Colors.blue,
              ),
            if (app.contactLists.isEmpty)
              _WarningBanner(
                icon: Icons.info_outline,
                message:
                    'Aucune liste de contacts. Importez un fichier CSV dans "Contacts".',
                color: Colors.blue,
              ),
            const SizedBox(height: 24),
            if (app.history.isNotEmpty) ...[
              Text('Derniers envois',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...app.history.take(8).map((r) => _HistoryTile(record: r)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _WarningBanner(
      {required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: color))),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SendRecord record;
  const _HistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final ok = record.status == SendStatus.success;
    return ListTile(
      dense: true,
      leading: Icon(
        ok ? Icons.check_circle : Icons.error,
        color: ok ? Colors.green : Colors.red,
        size: 18,
      ),
      title: Text(record.recipientEmail,
          style: const TextStyle(fontSize: 13)),
      subtitle: Text(record.campaignName,
          style: const TextStyle(fontSize: 11)),
      trailing: Text(
        _formatDate(record.sentAt),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
