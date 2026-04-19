import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/smtp_config.dart';
import '../models/campaign.dart';
import '../models/contact.dart';
import '../models/send_record.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';

class AppProvider extends ChangeNotifier {
  SmtpConfig _smtp = SmtpConfig();
  List<Campaign> _campaigns = [];
  List<ContactList> _contactLists = [];
  List<SendRecord> _history = [];
  bool _loading = false;
  String? _error;

  SmtpConfig get smtp => _smtp;
  List<Campaign> get campaigns => _campaigns;
  List<ContactList> get contactLists => _contactLists;
  List<SendRecord> get history => _history;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      await StorageService.instance.init();
      _smtp = await StorageService.instance.loadSmtpConfig();
      _campaigns = await StorageService.instance.loadCampaigns();
      final lists = await StorageService.instance.loadContactLists();
      _contactLists = [];
      for (final meta in lists) {
        try {
          final loaded = await CsvService.reloadContacts(meta);
          _contactLists.add(loaded);
        } catch (_) {
          _contactLists.add(meta);
        }
      }
      _history = await StorageService.instance.loadHistory();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> saveSmtp(SmtpConfig config) async {
    _smtp = config;
    await StorageService.instance.saveSmtpConfig(config);
    notifyListeners();
  }

  Future<void> addCampaign(Campaign campaign) async {
    _campaigns.add(campaign);
    await StorageService.instance.saveCampaigns(_campaigns);
    notifyListeners();
  }

  Future<void> updateCampaign(Campaign campaign) async {
    final idx = _campaigns.indexWhere((c) => c.id == campaign.id);
    if (idx >= 0) _campaigns[idx] = campaign;
    await StorageService.instance.saveCampaigns(_campaigns);
    notifyListeners();
  }

  Future<void> deleteCampaign(String id) async {
    _campaigns.removeWhere((c) => c.id == id);
    await StorageService.instance.saveCampaigns(_campaigns);
    notifyListeners();
  }

  Future<ContactList> importContactList(String filePath, String name) async {
    final id = const Uuid().v4();
    final list = await CsvService.importCsv(
      filePath: filePath,
      listName: name,
      listId: id,
    );
    _contactLists.add(list);
    await StorageService.instance.saveContactLists(_contactLists);
    notifyListeners();
    return list;
  }

  Future<void> deleteContactList(String id) async {
    _contactLists.removeWhere((l) => l.id == id);
    await StorageService.instance.saveContactLists(_contactLists);
    notifyListeners();
  }

  Future<void> refreshContactList(String id) async {
    final idx = _contactLists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    try {
      final refreshed = await CsvService.reloadContacts(_contactLists[idx]);
      _contactLists[idx] = refreshed;
      notifyListeners();
    } catch (_) {}
  }

  ContactList? getContactList(String id) {
    try {
      return _contactLists.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addRecord(SendRecord record) async {
    _history.insert(0, record);
    await StorageService.instance.appendRecord(record);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await StorageService.instance.clearHistory();
    notifyListeners();
  }

  int get totalSent =>
      _history.where((r) => r.status == SendStatus.success).length;
  int get totalFailed =>
      _history.where((r) => r.status == SendStatus.failed).length;

  Set<String> alreadySentKeys(String campaignId) {
    return _history
        .where((r) =>
            r.campaignId == campaignId && r.status == SendStatus.success)
        .map((r) => r.recipientEmail.toLowerCase())
        .toSet();
  }
}
