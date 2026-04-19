class Contact {
  final String id;
  final Map<String, String> fields;

  Contact({required this.id, required this.fields});

  String get email => fields['email'] ?? fields['Email'] ?? fields['EMAIL'] ?? '';
  String get name =>
      fields['nom'] ??
      fields['name'] ??
      fields['Name'] ??
      fields['Nom'] ??
      fields['prenom'] ??
      fields['Prenom'] ??
      '';

  factory Contact.fromCsvRow(List<String> headers, List<String> values) {
    final fields = <String, String>{};
    for (int i = 0; i < headers.length && i < values.length; i++) {
      fields[headers[i].trim()] = values[i].trim();
    }
    return Contact(
      id: fields['email'] ?? fields['Email'] ?? fields['EMAIL'] ?? '',
      fields: fields,
    );
  }

  bool get isValid => email.isNotEmpty && email.contains('@');
}

class ContactList {
  final String id;
  String name;
  String filePath;
  List<String> headers;
  List<Contact> contacts;

  ContactList({
    required this.id,
    required this.name,
    required this.filePath,
    required this.headers,
    required this.contacts,
  });

  int get count => contacts.length;
  int get validCount => contacts.where((c) => c.isValid).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'headers': headers,
      };

  factory ContactList.fromJson(Map<String, dynamic> j) => ContactList(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        filePath: j['filePath'] ?? '',
        headers: List<String>.from(j['headers'] ?? []),
        contacts: [],
      );
}
