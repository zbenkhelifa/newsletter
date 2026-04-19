import 'dart:io';
import 'package:csv/csv.dart';
import '../models/contact.dart';

class CsvService {
  static Future<ContactList> importCsv({
    required String filePath,
    required String listName,
    required String listId,
  }) async {
    final content = await File(filePath).readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(content);

    if (rows.isEmpty) {
      throw Exception('Le fichier CSV est vide.');
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final hasEmail = headers.any((h) =>
        h.toLowerCase() == 'email' ||
        h.toLowerCase() == 'e-mail' ||
        h.toLowerCase() == 'mail' ||
        h.toLowerCase() == 'courriel');

    if (!hasEmail) {
      throw Exception(
          'Le CSV doit contenir une colonne "email". Colonnes trouvées: ${headers.join(', ')}');
    }

    final contacts = <Contact>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i].map((e) => e.toString()).toList();
      if (row.every((v) => v.trim().isEmpty)) continue;
      final contact = Contact.fromCsvRow(headers, row);
      if (contact.email.isNotEmpty) {
        contacts.add(contact);
      }
    }

    return ContactList(
      id: listId,
      name: listName,
      filePath: filePath,
      headers: headers,
      contacts: contacts,
    );
  }

  static Future<ContactList> reloadContacts(ContactList list) async {
    return importCsv(
      filePath: list.filePath,
      listName: list.name,
      listId: list.id,
    );
  }
}
