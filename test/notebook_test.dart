import 'package:flutter_test/flutter_test.dart';
import 'package:almulzim/notebook/notebook_models.dart';
import 'package:almulzim/notebook/transcript.dart';

void main() {
  test('fmtTs formats minutes and hours', () {
    expect(fmtTs(75), '01:15');
    expect(fmtTs(3725), '1:02:05');
  });

  test('parseSections reads valid sections and never attributes unknown sources to the lecturer', () {
    final s = parseSections('''نص قبل
{"sections":[
 {"title":"تعريف الاشتقاق","body":"- ميل المماس","type":"definition","t":125,"src":"lecturer","uncertain":false},
 {"title":"توضيح","body":"شرح","type":"weird","t":-5,"src":"xx","uncertain":true},
 {"title":"","body":""}
]} نص بعد''');
    expect(s.length, 2);
    expect(s[0].type, 'definition');
    expect(s[0].t, 125);
    expect(s[0].src, 'lecturer');
    expect(s[1].type, 'note');
    expect(s[1].t, isNull);
    expect(s[1].src, 'ai');
    expect(s[1].uncertain, isTrue);
  });

  test('parseSections rejects garbage with an Arabic message', () {
    expect(() => parseSections('لا json هنا'), throwsA(isA<String>()));
    expect(() => parseSections('{"x":1}'), throwsA(isA<String>()));
  });

  test('chunkLines never cuts a line and respects the limit', () {
    final lines = List.generate(50, (i) => '[00:${i.toString().padLeft(2, '0')}] ${'ك' * 100}');
    final c = chunkLines(lines, maxChars: 1000);
    expect(c.length, greaterThan(3));
    expect(c.every((x) => x.length <= 1100), isTrue);
    expect(c.join().split('\n').where((e) => e.isNotEmpty).length, 50);
  });

  test('lineSeconds parses timestamps', () {
    expect(lineSeconds('[01:15] hi'), 75);
    expect(lineSeconds('[1:02:05] hi'), 3725);
    expect(lineSeconds('no stamp'), isNull);
  });

  test('notebook JSON round trip and search', () {
    final n = Notebook(title: 'التفاضل', sections: [NbSection(title: 'قاعدة السلسلة', body: 'مشتقة الدالة المركبة', t: 60, src: 'lecturer')]);
    final back = Notebook.fromJson(n.toJson());
    expect(back.sections.single.t, 60);
    expect(notebookMatches(back, 'المركبة'), isTrue);
    expect(notebookMatches(back, 'غير موجود'), isFalse);
    expect(notebookToMarkdown(back), contains('[01:00] قاعدة السلسلة'));
  });
}
