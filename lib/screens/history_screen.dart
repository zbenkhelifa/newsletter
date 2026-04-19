import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/send_record.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = '';
  SendStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    var records = app.history;

    if (_filter.isNotEmpty) {
      final q = _filter.toLowerCase();
      records = records
          .where((r) =>
              r.recipientEmail.toLowerCase().contains(q) ||
              r.campaignName.toLowerCase().contains(q) ||
              r.subject.toLowerCase().contains(q))
          .toList();
    }
    if (_statusFilter != null) {
      records = records.where((r) => r.status == _statusFilter).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des envois'),
        actions: [
          if (app.history.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Effacer l\'historique ?'),
                    content: Text(
                        'Supprimer ${app.history.length} entrée(s) ?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler')),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Effacer',
                              style: TextStyle(color: Colors.white))),
                    ],
                  ),
                );
                if (ok == true) await app.clearHistory();
              },
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              label: const Text('Effacer', style: TextStyle(color: Colors.red)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher (email, campagne, sujet...)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<SendStatus?>(
                value: _statusFilter,
                hint: const Text('Tous'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(
                      value: SendStatus.success, child: Text('Réussis')),
                  DropdownMenuItem(
                      value: SendStatus.failed, child: Text('Échecs')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              const SizedBox(width: 12),
              Text('${records.length} / ${app.history.length} entrée(s)',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
          ),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucun historique',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Les emails envoyés apparaîtront ici.',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 40,
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Email destinataire')),
                        DataColumn(label: Text('Campagne')),
                        DataColumn(label: Text('Sujet')),
                        DataColumn(label: Text('Date')),
                      ],
                      rows: records.map((r) {
                        final ok = r.status == SendStatus.success;
                        return DataRow(cells: [
                          DataCell(
                            Tooltip(
                              message: ok ? 'Envoyé' : (r.error ?? 'Échec'),
                              child: Icon(
                                ok ? Icons.check_circle : Icons.error,
                                color: ok ? Colors.green : Colors.red,
                                size: 18,
                              ),
                            ),
                          ),
                          DataCell(Text(r.recipientEmail,
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(r.campaignName,
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(r.subject,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                          DataCell(Text(_formatDate(r.sentAt),
                              style: const TextStyle(fontSize: 12))),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
