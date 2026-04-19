import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../providers/app_provider.dart';
import '../models/campaign.dart';
import '../models/contact.dart';
import '../models/send_record.dart';
import '../services/email_service.dart';
import '../services/template_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  Campaign? _selectedCampaign;
  int _templateIndex = 0;
  bool _sending = false;
  String _testEmail = '';
  int _progress = 0;
  int _total = 0;
  int _sent = 0;
  int _failed = 0;
  int _skipped = 0;
  final List<({String text, Color color})> _log = [];
  final _scrollCtrl = ScrollController();

  Future<String> _getBodyTemplate() async {
    final c = _selectedCampaign!;
    if (c.templateFiles.isNotEmpty) {
      final idx = _templateIndex.clamp(0, c.templateFiles.length - 1);
      return await TemplateService.loadHtmlFile(c.templateFiles[idx]);
    }
    return c.bodyTemplate;
  }

  Future<void> _showPreview() async {
    if (_selectedCampaign == null) return;
    final app = context.read<AppProvider>();
    final list = app.getContactList(_selectedCampaign!.contactListId);

    String bodyTemplate;
    try {
      bodyTemplate = await _getBodyTemplate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur template: $e')));
      }
      return;
    }
    if (!mounted) return;

    final sampleContact = (list != null && list.contacts.isNotEmpty)
        ? list.contacts.firstWhere((c) => c.isValid,
            orElse: () => Contact(
                id: 'sample',
                fields: {'email': 'exemple@email.com', 'nom': 'Dupont', 'prenom': 'Jean'}))
        : Contact(
            id: 'sample',
            fields: {'email': 'exemple@email.com', 'nom': 'Dupont', 'prenom': 'Jean'});

    final subject = TemplateService.applyTemplate(
        _selectedCampaign!.subjectTemplate, sampleContact);
    final body = TemplateService.applyTemplate(bodyTemplate, sampleContact);
    final html = TemplateService.buildHtmlBody(body);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: Column(
            children: [
              AppBar(
                title: const Text('Prévisualisation'),
                leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
                automaticallyImplyLeading: false,
              ),
              Container(
                color: Colors.grey.shade100,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Text('Sujet : ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(subject)),
                  ],
                ),
              ),
              if (list != null && list.validCount > 0)
                Container(
                  color: Colors.blue.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Prévisualisé avec le 1er contact : ${sampleContact.name} <${sampleContact.email}>',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: HtmlWidget(html),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendAll() async {
    if (_selectedCampaign == null) return;
    final app = context.read<AppProvider>();

    if (!app.smtp.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configurez le SMTP avant d\'envoyer.')));
      return;
    }

    final list = app.getContactList(_selectedCampaign!.contactListId);
    if (list == null || list.validCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aucun contact valide dans cette liste.')));
      return;
    }

    String bodyTemplate;
    try {
      bodyTemplate = await _getBodyTemplate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur template: $e')));
      }
      return;
    }
    if (!mounted) return;

    final alreadySent = app.alreadySentKeys(_selectedCampaign!.id);
    final toSend = list.contacts.where((c) => c.isValid).length;
    final willSkip = list.contacts
        .where((c) => c.isValid && alreadySent.contains(c.email.toLowerCase()))
        .length;
    final willSend = toSend - willSkip;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer l\'envoi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Campagne : ${_selectedCampaign!.name}'),
            Text('Liste : ${list.name}'),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.send, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text('$willSend email(s) à envoyer'),
            ]),
            if (willSkip > 0)
              Row(children: [
                const Icon(Icons.skip_next, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Text('$willSkip déjà envoyé(s) — ignoré(s)'),
              ]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Envoyer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _sending = true;
      _progress = 0;
      _total = toSend;
      _sent = 0;
      _failed = 0;
      _skipped = 0;
      _log.clear();
    });

    final svc = EmailService(app.smtp);
    final contacts = list.contacts.where((c) => c.isValid).toList();

    await svc.sendBatch(
      campaign: _selectedCampaign!,
      contacts: contacts,
      subjectTemplate: _selectedCampaign!.subjectTemplate,
      bodyTemplate: bodyTemplate,
      alreadySent: alreadySent,
      onProgress: (current, total, record) {
        if (record.status != SendStatus.skipped) app.addRecord(record);
        setState(() {
          _progress = current;
          if (record.status == SendStatus.success) {
            _sent++;
            _log.add((
              text: '✓ ${record.recipientEmail}',
              color: Colors.greenAccent
            ));
          } else if (record.status == SendStatus.skipped) {
            _skipped++;
            _log.add((
              text: '⏭ ${record.recipientEmail} (déjà envoyé)',
              color: Colors.orangeAccent
            ));
          } else {
            _failed++;
            _log.add((
              text: '✗ ${record.recipientEmail}: ${record.error ?? ''}',
              color: Colors.redAccent
            ));
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      },
      onError: (_) {},
    );

    setState(() => _sending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _failed == 0 ? Colors.green : Colors.orange,
          content: Text(
              'Terminé : $_sent envoyé(s), $_skipped ignoré(s), $_failed échec(s).')));
    }
  }

  Future<void> _sendTest() async {
    if (_selectedCampaign == null) return;
    if (_testEmail.isEmpty || !_testEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrez un email de test valide.')));
      return;
    }
    final app = context.read<AppProvider>();
    if (!app.smtp.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configurez le SMTP avant d\'envoyer.')));
      return;
    }

    String bodyTemplate;
    try {
      bodyTemplate = await _getBodyTemplate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur template: $e')));
      }
      return;
    }
    if (!mounted) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fakeContact = Contact(
        id: _testEmail,
        fields: {'email': _testEmail, 'nom': 'Test', 'prenom': 'Test'},
      );
      final svc = EmailService(app.smtp);
      final record = await svc.sendToContact(
        campaign: _selectedCampaign!,
        contact: fakeContact,
        subject: TemplateService.applyTemplate(
            _selectedCampaign!.subjectTemplate, fakeContact),
        htmlBody: TemplateService.buildHtmlBody(
            TemplateService.applyTemplate(bodyTemplate, fakeContact)),
      );
      messenger.showSnackBar(SnackBar(
          backgroundColor:
              record.status == SendStatus.success ? Colors.green : Colors.red,
          content: Text(record.status == SendStatus.success
              ? 'Email de test envoyé à $_testEmail'
              : 'Échec: ${record.error}')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final campaigns = app.campaigns;

    return Scaffold(
      appBar: AppBar(title: const Text('Envoyer une newsletter')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('1. Campagne'),
                    const SizedBox(height: 8),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<Campaign>(
                      value: _selectedCampaign,
                      decoration: const InputDecoration(
                          labelText: 'Campagne',
                          border: OutlineInputBorder()),
                      items: campaigns
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (c) => setState(() {
                        _selectedCampaign = c;
                        _templateIndex = 0;
                      }),
                      hint: const Text('Sélectionner...'),
                    ),
                    if (_selectedCampaign != null) ...[
                      const SizedBox(height: 16),
                      _CampaignInfo(campaign: _selectedCampaign!, app: app),
                      if (_selectedCampaign!.templateFiles.length > 1) ...[
                        const SizedBox(height: 16),
                        _sectionTitle('2. Template'),
                        const SizedBox(height: 8),
                        // ignore: deprecated_member_use
                        DropdownButtonFormField<int>(
                          value: _templateIndex,
                          decoration: const InputDecoration(
                              labelText: 'Fichier template',
                              border: OutlineInputBorder()),
                          items: _selectedCampaign!.templateFiles
                              .asMap()
                              .entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                      '${e.key + 1}. ${e.value.split('/').last}',
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _templateIndex = v ?? 0),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _sectionTitle('3. Prévisualiser'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _sending ? null : _showPreview,
                          icon: const Icon(Icons.preview, size: 18),
                          label: const Text('Prévisualiser le template'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('4. Email de test'),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _testEmail,
                        decoration: const InputDecoration(
                            labelText: 'Email de test',
                            hintText: 'test@exemple.com',
                            border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => _testEmail = v),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _sending ? null : _sendTest,
                        icon: const Icon(Icons.science, size: 18),
                        label: const Text('Envoyer un test'),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('5. Envoi groupé'),
                      const SizedBox(height: 8),
                      _DedupeInfo(
                          campaign: _selectedCampaign!, app: app),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _sending ? null : _sendAll,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send),
                          label: Text(_sending
                              ? 'Envoi en cours...'
                              : 'Envoyer à tous les contacts'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Journal d\'envoi'),
                  if (_total > 0) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('$_progress / $_total',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      const Icon(Icons.check_circle,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('$_sent', style: const TextStyle(color: Colors.green)),
                      const SizedBox(width: 12),
                      const Icon(Icons.skip_next,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('$_skipped',
                          style: const TextStyle(color: Colors.orange)),
                      if (_failed > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.error, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('$_failed',
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _total > 0 ? _progress / _total : 0,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: _log.isEmpty
                          ? const Text(
                              'Les logs d\'envoi apparaîtront ici...',
                              style: TextStyle(
                                  color: Colors.grey, fontFamily: 'monospace'))
                          : ListView.builder(
                              controller: _scrollCtrl,
                              itemCount: _log.length,
                              itemBuilder: (_, i) => Text(
                                _log[i].text,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: _log[i].color,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (_total > 0 && _progress == _total && !_sending)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _log.clear();
                          _progress = 0;
                          _total = 0;
                          _sent = 0;
                          _failed = 0;
                          _skipped = 0;
                        }),
                        icon: const Icon(Icons.clear),
                        label: const Text('Effacer le journal'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold));
}

class _CampaignInfo extends StatelessWidget {
  final Campaign campaign;
  final AppProvider app;

  const _CampaignInfo({required this.campaign, required this.app});

  @override
  Widget build(BuildContext context) {
    final list = app.getContactList(campaign.contactListId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info('Contacts',
              list != null
                  ? '${list.name} (${list.validCount})'
                  : 'Non trouvé'),
          _info('Sujet', campaign.subjectTemplate),
          if (campaign.templateFiles.isNotEmpty)
            _info('Templates', '${campaign.templateFiles.length} fichier(s)'),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: ',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}

class _DedupeInfo extends StatelessWidget {
  final Campaign campaign;
  final AppProvider app;

  const _DedupeInfo({required this.campaign, required this.app});

  @override
  Widget build(BuildContext context) {
    final list = app.getContactList(campaign.contactListId);
    if (list == null) return const SizedBox.shrink();
    final alreadySent = app.alreadySentKeys(campaign.id);
    final total = list.validCount;
    final skipped = list.contacts
        .where((c) =>
            c.isValid && alreadySent.contains(c.email.toLowerCase()))
        .length;
    final toSend = total - skipped;

    if (skipped == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$toSend à envoyer · $skipped déjà reçu(s) seront ignoré(s)',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
