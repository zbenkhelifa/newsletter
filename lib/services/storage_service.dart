import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/smtp_config.dart';
import '../models/campaign.dart';
import '../models/contact.dart';
import '../models/send_record.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  late Directory _appDir;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final base = await getApplicationSupportDirectory();
    _appDir = Directory('${base.path}/newsletter_app');
    await _appDir.create(recursive: true);
    _initialized = true;
  }

  File _file(String name) => File('${_appDir.path}/$name');

  Future<Map<String, dynamic>> _readJson(String name) async {
    final f = _file(name);
    if (!await f.exists()) return {};
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeJson(String name, dynamic data) async {
    await _file(name).writeAsString(jsonEncode(data));
  }

  // SMTP
  Future<SmtpConfig> loadSmtpConfig() async {
    final data = await _readJson('smtp.json');
    return SmtpConfig.fromJson(data);
  }

  Future<void> saveSmtpConfig(SmtpConfig config) async {
    await _writeJson('smtp.json', config.toJson());
  }

  // Campaigns
  Future<List<Campaign>> loadCampaigns() async {
    final data = await _readJson('campaigns.json');
    final list = data['campaigns'] as List? ?? [];
    return list.map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveCampaigns(List<Campaign> campaigns) async {
    await _writeJson('campaigns.json', {
      'campaigns': campaigns.map((c) => c.toJson()).toList(),
    });
  }

  // Contact Lists (metadata only — contacts loaded from CSV)
  Future<List<ContactList>> loadContactLists() async {
    final data = await _readJson('contact_lists.json');
    final list = data['lists'] as List? ?? [];
    return list
        .map((e) => ContactList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveContactLists(List<ContactList> lists) async {
    await _writeJson('contact_lists.json', {
      'lists': lists.map((l) => l.toJson()).toList(),
    });
  }

  // Send History
  Future<List<SendRecord>> loadHistory() async {
    final data = await _readJson('history.json');
    final list = data['records'] as List? ?? [];
    return list
        .map((e) => SendRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> appendRecord(SendRecord record) async {
    final records = await loadHistory();
    records.insert(0, record);
    // Keep only last 5000 records
    final trimmed = records.length > 5000 ? records.sublist(0, 5000) : records;
    await _writeJson('history.json', {
      'records': trimmed.map((r) => r.toJson()).toList(),
    });
  }

  Future<void> clearHistory() async {
    await _writeJson('history.json', {'records': []});
  }
}
