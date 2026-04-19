import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/campaign.dart';

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campagnes'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _openEditor(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle campagne'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: app.campaigns.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Aucune campagne',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      'Créez une campagne pour envoyer vos newsletters.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _openEditor(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer une campagne'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: app.campaigns.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = app.campaigns[i];
                return _CampaignCard(
                  campaign: c,
                  onEdit: () => _openEditor(context, c),
                  onDelete: () async {
                    final ok = await _confirmDelete(context);
                    if (ok == true && context.mounted) {
                      await context.read<AppProvider>().deleteCampaign(c.id);
                    }
                  },
                );
              },
            ),
    );
  }

  void _openEditor(BuildContext context, Campaign? existing) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CampaignEditorScreen(existing: existing),
    ));
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Supprimer la campagne ?'),
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

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CampaignCard({
    required this.campaign,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final list = app.getContactList(campaign.contactListId);
    final today = campaign.todayTemplate;
    final next = campaign.nextTemplate;
    final fmt = DateFormat('dd/MM/yyyy');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.campaign,
              color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(campaign.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (campaign.description.isNotEmpty)
              Text(campaign.description, style: const TextStyle(fontSize: 12)),
            Row(children: [
              const Icon(Icons.people, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                list != null
                    ? '${list.name} (${list.validCount} contacts)'
                    : 'Aucune liste',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.description, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                campaign.scheduledTemplates.isNotEmpty
                    ? '${campaign.scheduledTemplates.length} newsletter(s)'
                    : campaign.bodyTemplate.isNotEmpty
                        ? 'Template intégré'
                        : 'Aucun contenu',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ]),
            if (today != null)
              Row(children: [
                const Icon(Icons.today, size: 12, color: Colors.green),
                const SizedBox(width: 4),
                Text('Aujourd\'hui : ${today.fileName}',
                    style: const TextStyle(fontSize: 12, color: Colors.green)),
              ])
            else if (next != null)
              Row(children: [
                const Icon(Icons.schedule, size: 12, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                    'Prochain : ${next.fileName} le ${fmt.format(next.sendDate!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue)),
              ]),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Modifier'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Supprimer',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ─── Campaign Editor ────────────────────────────────────────────────

class CampaignEditorScreen extends StatefulWidget {
  final Campaign? existing;
  const CampaignEditorScreen({super.key, this.existing});

  @override
  State<CampaignEditorScreen> createState() => _CampaignEditorScreenState();
}

class _CampaignEditorScreenState extends State<CampaignEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name, _desc, _subject, _body;
  String? _contactListId;
  List<ScheduledTemplate> _templates = [];
  bool _useFileTemplates = false;
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _desc = TextEditingController(text: c?.description ?? '');
    _subject = TextEditingController(text: c?.subjectTemplate ?? '');
    _body = TextEditingController(text: c?.bodyTemplate ?? '');
    _contactListId = c?.contactListId;
    _templates = List.from(c?.scheduledTemplates ?? []);
    _useFileTemplates = _templates.isNotEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Sélectionner le dossier de newsletters',
    );
    if (dir == null) return;

    final directory = Directory(dir);
    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return ext == 'html' || ext == 'htm' || ext == 'txt';
        })
        .map((f) => f.path)
        .toList()
      ..sort();

    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Aucun fichier HTML/TXT trouvé dans ce dossier.')));
      }
      return;
    }

    setState(() {
      _templates = files.map((p) {
        // keep existing date if same file already in list
        final existing = _templates.firstWhere(
          (t) => t.filePath == p,
          orElse: () => ScheduledTemplate(filePath: p),
        );
        return existing;
      }).toList();
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm', 'txt'],
      allowMultiple: true,
      dialogTitle: 'Sélectionner des fichiers de template',
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path!).toList()..sort();
    setState(() {
      _templates = paths.map((p) {
        final existing = _templates.firstWhere(
          (t) => t.filePath == p,
          orElse: () => ScheduledTemplate(filePath: p),
        );
        return existing;
      }).toList();
    });
  }

  Future<void> _pickDate(int index) async {
    final current = _templates[index].sendDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Date d\'envoi',
    );
    if (picked == null) return;
    setState(() {
      _templates[index] = _templates[index].copyWith(sendDate: picked);
    });
  }

  void _clearDate(int index) {
    setState(() {
      _templates[index] = _templates[index].copyWith(clearDate: true);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contactListId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionnez une liste de contacts.')));
      return;
    }

    final campaign = Campaign(
      id: widget.existing?.id,
      name: _name.text.trim(),
      description: _desc.text.trim(),
      contactListId: _contactListId!,
      subjectTemplate: _subject.text.trim(),
      bodyTemplate: _useFileTemplates ? '' : _body.text,
      scheduledTemplates: _useFileTemplates ? _templates : [],
      createdAt: widget.existing?.createdAt,
    );

    final app = context.read<AppProvider>();
    if (widget.existing == null) {
      await app.addCampaign(campaign);
    } else {
      await app.updateCampaign(campaign);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final lists = app.contactLists;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Nouvelle campagne'
            : 'Modifier la campagne'),
        actions: [
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Sauvegarder'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Informations générales'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Nom de la campagne *',
                      hintText: 'ex: Newsletter mensuelle',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                _sectionTitle('Liste de contacts'),
                const SizedBox(height: 12),
                // ignore: deprecated_member_use
                DropdownButtonFormField<String>(
                  value: _contactListId,
                  decoration: const InputDecoration(
                      labelText: 'Liste de contacts *',
                      border: OutlineInputBorder()),
                  items: lists
                      .map((l) => DropdownMenuItem(
                          value: l.id,
                          child: Text('${l.name} (${l.validCount} contacts)')))
                      .toList(),
                  onChanged: (v) => setState(() => _contactListId = v),
                  hint: const Text('Sélectionner une liste'),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Sujet de l\'email'),
                const SizedBox(height: 8),
                const Text(
                  'Utilisez {{COLONNE}} pour insérer des valeurs dynamiques depuis votre CSV.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subject,
                  decoration: const InputDecoration(
                      labelText: 'Sujet *',
                      hintText: 'ex: Bonjour {{prenom}}, votre newsletter',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 24),
                _sectionTitle('Contenu du message'),
                const SizedBox(height: 8),
                RadioGroup<bool>(
                  groupValue: _useFileTemplates,
                  onChanged: (v) => setState(() => _useFileTemplates = v!),
                  child: const Row(children: [
                    Radio<bool>(value: false),
                    Text('Éditeur intégré'),
                    SizedBox(width: 24),
                    Radio<bool>(value: true),
                    Text('Dossier de newsletters (avec dates)'),
                  ]),
                ),
                const SizedBox(height: 12),
                if (!_useFileTemplates)
                  TextFormField(
                    controller: _body,
                    decoration: const InputDecoration(
                        labelText: 'Corps du message (HTML ou texte)',
                        hintText:
                            'Bonjour {{prenom}},\n\nContenu de votre newsletter...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true),
                    maxLines: 14,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  )
                else ...[
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: _pickFolder,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Scanner un dossier'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Ajouter des fichiers'),
                    ),
                  ]),
                  if (_templates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TemplateScheduleTable(
                      templates: _templates,
                      dateFmt: _dateFmt,
                      onPickDate: _pickDate,
                      onClearDate: _clearDate,
                      onRemove: (i) =>
                          setState(() => _templates.removeAt(i)),
                      onReorder: (oldIdx, newIdx) {
                        setState(() {
                          if (newIdx > oldIdx) newIdx--;
                          final item = _templates.removeAt(oldIdx);
                          _templates.insert(newIdx, item);
                        });
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );
}

class _TemplateScheduleTable extends StatelessWidget {
  final List<ScheduledTemplate> templates;
  final DateFormat dateFmt;
  final void Function(int index) onPickDate;
  final void Function(int index) onClearDate;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _TemplateScheduleTable({
    required this.templates,
    required this.dateFmt,
    required this.onPickDate,
    required this.onClearDate,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(children: [
              SizedBox(width: 32),
              SizedBox(
                  width: 32,
                  child: Text('#',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(
                  child: Text('Fichier',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(
                  width: 170,
                  child: Text('Date d\'envoi',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 40),
            ]),
          ),
          const Divider(height: 1),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: templates.length,
            onReorder: onReorder,
            itemBuilder: (ctx, i) {
              final t = templates[i];
              final isToday = t.sendDate != null &&
                  t.sendDate!.year == today.year &&
                  t.sendDate!.month == today.month &&
                  t.sendDate!.day == today.day;
              final isPast = t.sendDate != null &&
                  t.sendDate!.isBefore(DateTime(today.year, today.month, today.day));

              return Container(
                key: ValueKey(t.filePath + i.toString()),
                decoration: BoxDecoration(
                  color: isToday
                      ? Colors.green.withValues(alpha: 0.06)
                      : isPast
                          ? Colors.grey.withValues(alpha: 0.04)
                          : null,
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.drag_handle,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                    Expanded(
                      child: Row(children: [
                        Icon(Icons.html,
                            size: 16,
                            color: isToday
                                ? Colors.green
                                : isPast
                                    ? Colors.grey
                                    : Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.fileName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isPast ? Colors.grey : null,
                              decoration: isPast
                                  ? TextDecoration.none
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ),
                    SizedBox(
                      width: 170,
                      child: Row(children: [
                        if (isToday)
                          const Row(children: [
                            Icon(Icons.today, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text("Aujourd'hui",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          ])
                        else if (t.sendDate != null)
                          Row(children: [
                            Text(dateFmt.format(t.sendDate!),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isPast ? Colors.grey : null)),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => onClearDate(i),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.grey),
                            ),
                          ])
                        else
                          Text('Pas de date',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                  fontStyle: FontStyle.italic)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => onPickDate(i),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.calendar_month,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ]),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () => onRemove(i),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
