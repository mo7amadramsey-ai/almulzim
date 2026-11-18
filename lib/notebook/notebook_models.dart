// Smart lecture notebook: data model + pure helpers (no Flutter imports, so they are unit-testable).
import 'dart:convert';

const nbTypes = <String, String>{
  'concept': 'مفهوم',
  'definition': 'تعريف',
  'law': 'قانون',
  'example': 'مثال',
  'note': 'ملاحظة',
  'warning': 'تنبيه',
  'review': 'سؤال مراجعة',
};

/// Where a piece of information comes from (spec §14.6: never pass AI wording off as the lecturer's)
const nbSources = <String, String>{
  'lecturer': 'من كلام المحاضر',
  'ai': 'صياغة/توضيح الذكاء الاصطناعي',
  'me': 'ملاحظتي',
};

const nbModes = <String, String>{
  'student': 'دفتر الطالب',
  'quick': 'المراجعة السريعة',
  'exam': 'ليلة الامتحان',
};

String fmtTs(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  final mm = m.toString().padLeft(2, '0'), ss = x.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class NbSection {
  String id, title, body, type, src;
  int? t; // seconds in the video this part refers to
  bool uncertain;
  NbSection({String? id, required this.title, required this.body, this.type = 'note', this.src = 'ai', this.t, this.uncertain = false})
      : id = id ?? newId();

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'body': body, 'type': type, 'src': src, 't': t, 'uncertain': uncertain};

  factory NbSection.fromJson(Map<String, dynamic> j) => NbSection(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        type: nbTypes.containsKey(j['type']) ? j['type'] as String : 'note',
        src: nbSources.containsKey(j['src']) ? j['src'] as String : 'ai',
        t: (j['t'] as num?)?.toInt(),
        uncertain: j['uncertain'] == true,
      );
}

class Notebook {
  String id, title, mode;
  String? courseTitle, videoId, url;
  DateTime created;
  final List<NbSection> sections;
  Notebook({String? id, required this.title, this.mode = 'student', this.courseTitle, this.videoId, this.url, DateTime? created, List<NbSection>? sections})
      : id = id ?? newId(),
        created = created ?? DateTime.now(),
        sections = sections ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mode': mode,
        'courseTitle': courseTitle,
        'videoId': videoId,
        'url': url,
        'created': created.toIso8601String(),
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory Notebook.fromJson(Map<String, dynamic> j) => Notebook(
        id: j['id'] as String?,
        title: (j['title'] as String?) ?? 'دفتر',
        mode: nbModes.containsKey(j['mode']) ? j['mode'] as String : 'student',
        courseTitle: j['courseTitle'] as String?,
        videoId: j['videoId'] as String?,
        url: j['url'] as String?,
        created: DateTime.tryParse((j['created'] as String?) ?? ''),
        sections: ((j['sections'] as List?) ?? []).map((e) => NbSection.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Reads the AI reply: {"sections":[{title, body, type, t, src, uncertain}]}. Throws a readable Arabic message.
List<NbSection> parseSections(String raw) {
  final a = raw.indexOf('{');
  final b = raw.lastIndexOf('}');
  if (a < 0 || b <= a) throw 'ردّ غير مفهوم من الذكاء الاصطناعي';
  final dynamic j;
  try {
    j = jsonDecode(raw.substring(a, b + 1));
  } catch (_) {
    throw 'تعذّرت قراءة ردّ الذكاء الاصطناعي (JSON غير صالح)';
  }
  final list = (j is Map ? j['sections'] : null);
  if (list is! List) throw 'الردّ لا يحتوي أقساماً';
  final out = <NbSection>[];
  for (final e in list) {
    if (e is! Map) continue;
    final title = ('${e['title'] ?? ''}').trim();
    final body = ('${e['body'] ?? ''}').trim();
    if (title.isEmpty && body.isEmpty) continue;
    final t = (e['t'] as num?)?.toInt();
    out.add(NbSection(
      title: title.isEmpty ? 'ملاحظة' : title,
      body: body,
      type: nbTypes.containsKey(e['type']) ? e['type'] as String : 'note',
      src: nbSources.containsKey(e['src']) && e['src'] != 'me' ? e['src'] as String : 'ai',
      t: (t != null && t >= 0 && t < 86400) ? t : null,
      uncertain: e['uncertain'] == true,
    ));
  }
  return out;
}

/// Splits transcript lines into chunks of at most [maxChars] characters (lines are never cut)
List<String> chunkLines(List<String> lines, {int maxChars = 12000}) {
  final out = <String>[];
  final cur = StringBuffer();
  for (final l in lines) {
    if (cur.length + l.length + 1 > maxChars && cur.isNotEmpty) {
      out.add(cur.toString());
      cur.clear();
    }
    cur.writeln(l);
  }
  if (cur.isNotEmpty) out.add(cur.toString());
  return out;
}

bool notebookMatches(Notebook n, String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return true;
  if (n.title.toLowerCase().contains(s) || (n.courseTitle ?? '').toLowerCase().contains(s)) return true;
  return n.sections.any((x) => x.title.toLowerCase().contains(s) || x.body.toLowerCase().contains(s));
}

String notebookToMarkdown(Notebook n) {
  final b = StringBuffer('# ${n.title}\n');
  b.writeln('> ${nbModes[n.mode]}${n.courseTitle == null ? '' : ' — ${n.courseTitle}'}');
  if (n.url != null) b.writeln('> ${n.url}');
  for (final s in n.sections) {
    b.writeln('\n## ${s.t != null ? '[${fmtTs(s.t!)}] ' : ''}${s.title}  (${nbTypes[s.type]} · ${nbSources[s.src]}${s.uncertain ? ' · غير مؤكد' : ''})');
    b.writeln(s.body);
  }
  return b.toString();
}
