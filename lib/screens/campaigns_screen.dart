import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
                  const Text('Créez une campagne pour envoyer vos newsletters.',
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
              Text(campaign.description,
                  style: const TextStyle(fontSize: 12)),
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
                campaign.templateFiles.isNotEmpty
                    ? '${campaign.templateFiles.length} template(s)'
                    : campaign.bodyTemplate.isNotEmpty
                        ? 'Template intégré'
                        : 'Aucun contenu',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
  List<String> _templateFiles = [];
  bool _useFileTemplates = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _desc = TextEditingController(text: c?.description ?? '');
    _subject = TextEditingController(text: c?.subjectTemplate ?? '');
    _body = TextEditingController(text: c?.bodyTemplate ?? '');
    _contactListId = c?.contactListId;
    _templateFiles = List.from(c?.templateFiles ?? []);
    _useFileTemplates = _templateFiles.isNotEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickTemplateFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm', 'txt'],
      allowMultiple: true,
      dialogTitle: 'Sélectionner des fichiers de template',
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path!).toList()..sort();
    setState(() => _templateFiles = paths);
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
      templateFiles: _useFileTemplates ? _templateFiles : [],
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
          constraints: const BoxConstraints(maxWidth: 700),
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
                    Text('Fichiers HTML externes'),
                  ]),
                ),
                const SizedBox(height: 8),
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
                  OutlinedButton.icon(
                    onPressed: _pickTemplateFiles,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Sélectionner fichiers HTML'),
                  ),
                  if (_templateFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._templateFiles.asMap().entries.map((e) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                              radius: 12,
                              child: Text('${e.key + 1}',
                                  style: const TextStyle(fontSize: 10))),
                          title: Text(e.value.split('/').last,
                              style: const TextStyle(fontSize: 12)),
                          subtitle: Text(e.value,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() =>
                                _templateFiles.removeAt(e.key)),
                          ),
                        )),
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
