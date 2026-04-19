import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/smtp_config.dart';
import '../services/email_service.dart';

class SmtpScreen extends StatefulWidget {
  const SmtpScreen({super.key});

  @override
  State<SmtpScreen> createState() => _SmtpScreenState();
}

class _SmtpScreenState extends State<SmtpScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _host, _port, _user, _pass, _name;
  bool _tls = true;
  bool _obscure = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final smtp = context.read<AppProvider>().smtp;
    _host = TextEditingController(text: smtp.host);
    _port = TextEditingController(text: smtp.port.toString());
    _user = TextEditingController(text: smtp.username);
    _pass = TextEditingController(text: smtp.password);
    _name = TextEditingController(text: smtp.senderName);
    _tls = smtp.useTls;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  SmtpConfig _buildConfig() => SmtpConfig(
        host: _host.text.trim(),
        port: int.tryParse(_port.text) ?? 587,
        username: _user.text.trim(),
        password: _pass.text,
        senderName: _name.text.trim(),
        useTls: _tls,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppProvider>().saveSmtp(_buildConfig());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration SMTP sauvegardée.')));
    }
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final svc = EmailService(_buildConfig());
      await svc.testConnection();
      setState(() {
        _testOk = true;
        _testResult = 'Connexion réussie ! Email de test envoyé.';
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testResult = 'Échec: $e';
      });
    }
    setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration SMTP')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Serveur d\'envoi',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _host,
                      decoration: const InputDecoration(
                          labelText: 'Serveur SMTP',
                          hintText: 'smtp.gmail.com',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _port,
                      decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: '587',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (int.tryParse(v ?? '') == null) ? 'Invalide' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _user,
                  decoration: const InputDecoration(
                      labelText: 'Adresse email (expéditeur)',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Email invalide' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Nom affiché (optionnel)',
                      hintText: 'ex: Mon Association',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Utiliser TLS/STARTTLS'),
                  subtitle: const Text('Recommandé pour la sécurité'),
                  value: _tls,
                  onChanged: (v) => setState(() => _tls = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exemples de configuration SMTP :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(height: 6),
                      Text('Gmail: smtp.gmail.com:587 (utiliser un mot de passe d\'application)',
                          style: TextStyle(fontSize: 11)),
                      Text('Outlook: smtp.office365.com:587',
                          style: TextStyle(fontSize: 11)),
                      Text('OVH: ssl0.ovh.net:587',
                          style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_testResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: (_testOk ? Colors.green : Colors.red)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: (_testOk ? Colors.green : Colors.red)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(_testOk ? Icons.check_circle : Icons.error,
                          color: _testOk ? Colors.green : Colors.red,
                          size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_testResult!,
                              style: TextStyle(
                                  color: _testOk ? Colors.green : Colors.red,
                                  fontSize: 13))),
                    ]),
                  ),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Sauvegarder'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt),
                    label: Text(_testing ? 'Test en cours...' : 'Tester la connexion'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
