import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';
import '../models/contact.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String? _selectedListId;
  bool _importing = false;

  Future<void> _downloadTemplate() async {
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/modele_contacts.csv');
    await file.writeAsString(
        'email,nom,prenom\nexemple@email.com,Dupont,Jean\nexemple2@email.com,Martin,Marie\n');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Modèle CSV sauvegardé : ${file.path}'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      dialogTitle: 'Sélectionner un fichier CSV',
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    final nameCtrl = TextEditingController(
        text: file.name.replaceAll('.csv', '').replaceAll('_', ' '));

    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de la liste'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
              labelText: 'Nom', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: const Text('Importer')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    setState(() => _importing = true);
    final appProvider = context.read<AppProvider>();
    try {
      final list = await appProvider.importContactList(file.path!, name);
      setState(() => _selectedListId = list.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${list.validCount} contacts importés avec succès.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
    setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final lists = app.contactLists;
    final selected =
        _selectedListId != null ? app.getContactList(_selectedListId!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listes de contacts'),
        actions: [
          TextButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download),
            label: const Text('Modèle CSV'),
          ),
          const SizedBox(width: 4),
          if (_importing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Importer CSV'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: lists.isEmpty
          ? _EmptyState(onImport: _importCsv, onDownloadTemplate: _downloadTemplate)
          : Row(
              children: [
                SizedBox(
                  width: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${lists.length} liste(s)',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: lists.length,
                          itemBuilder: (_, i) {
                            final l = lists[i];
                            final isSelected = l.id == _selectedListId;
                            return ListTile(
                              selected: isSelected,
                              leading: const Icon(Icons.people),
                              title: Text(l.name,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text('${l.validCount} contacts',
                                  style: const TextStyle(fontSize: 11)),
                              onTap: () =>
                                  setState(() => _selectedListId = l.id),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  final provider = context.read<AppProvider>();
                                  final messenger = ScaffoldMessenger.of(context);
                                  if (v == 'delete') {
                                    final ok = await _confirmDelete(context);
                                    if (ok == true) {
                                      await provider.deleteContactList(l.id);
                                      if (mounted && _selectedListId == l.id) {
                                        setState(() => _selectedListId = null);
                                      }
                                    }
                                  } else if (v == 'refresh') {
                                    await provider.refreshContactList(l.id);
                                    messenger.showSnackBar(const SnackBar(
                                        content: Text(
                                            'Liste rechargée depuis le CSV.')));
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'refresh',
                                      child: Row(children: [
                                        Icon(Icons.refresh, size: 16),
                                        SizedBox(width: 8),
                                        Text('Recharger')
                                      ])),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete, size: 16,
                                            color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Supprimer',
                                            style:
                                                TextStyle(color: Colors.red))
                                      ])),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? const Center(
                          child: Text('Sélectionnez une liste pour voir les contacts',
                              style: TextStyle(color: Colors.grey)))
                      : _ContactTable(list: selected),
                ),
              ],
            ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Supprimer la liste ?'),
          content:
              const Text('Cette action est irréversible. Continuer ?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer',
                    style: TextStyle(color: Colors.white))),
          ],
        ),
      );
}

class _ContactTable extends StatelessWidget {
  final ContactList list;
  const _ContactTable({required this.list});

  @override
  Widget build(BuildContext context) {
    final contacts = list.contacts;
    if (contacts.isEmpty) {
      return const Center(child: Text('Aucun contact valide trouvé.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text('${list.name} — ${list.validCount} contacts',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 12),
            Text('Colonnes: ${list.headers.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columns: list.headers
                    .map((h) => DataColumn(
                        label: Text(h,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))))
                    .toList(),
                rows: contacts.take(200).map((c) {
                  return DataRow(
                    cells: list.headers
                        .map((h) => DataCell(
                            Text(c.fields[h] ?? '',
                                style: const TextStyle(fontSize: 12))))
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (contacts.length > 200)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Affichage limité à 200 lignes sur ${contacts.length}.',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onDownloadTemplate;
  const _EmptyState({required this.onImport, required this.onDownloadTemplate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucune liste de contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Importez un fichier CSV avec au minimum une colonne "email".',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onDownloadTemplate,
                icon: const Icon(Icons.download),
                label: const Text('Télécharger le modèle CSV'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file),
                label: const Text('Importer un fichier CSV'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
