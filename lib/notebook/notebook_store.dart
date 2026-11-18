import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'notebook_models.dart';

Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/notebooks.json');

Future<List<Notebook>> loadNotebooks() async {
  try {
    final f = await _file();
    if (!await f.exists()) return [];
    return (jsonDecode(await f.readAsString()) as List).map((e) => Notebook.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

/// Atomic write: temp file then rename, so a crash mid-save never corrupts the notebooks
Future<void> saveNotebooks(List<Notebook> l) async {
  final f = await _file();
  final tmp = File('${f.path}.tmp');
  await tmp.writeAsString(jsonEncode(l.map((n) => n.toJson()).toList()));
  await tmp.rename(f.path);
}
