import 'package:flutter/material.dart';
import '../ai.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notebook_ai.dart';
import 'notebook_models.dart';
import 'notebook_page.dart';
import 'notebook_store.dart';
import 'transcript.dart';

/// All notebooks, with search across every notebook's titles and text.
class NotebooksPage extends StatefulWidget {
  const NotebooksPage({super.key});
  @override
  State<NotebooksPage> createState() => _NotebooksPageState();
}

class _NotebooksPageState extends State<NotebooksPage> {
  List<Notebook>? list;
  String q = '';

  @override
  void initState() {
    super.initState();
    loadNotebooks().then((l) {
      if (mounted) setState(() => list = l..sort((a, b) => b.created.compareTo(a.created)));
    });
  }

  Future<void> _persist() async {
    await saveNotebooks(list!);
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final nb = await Navigator.push<Notebook>(context, MaterialPageRoute(builder: (_) => const NewNotebookPage()));
    if (nb == null || !mounted) return;
    list!.insert(0, nb);
    await _persist();
    if (mounted) _open(nb);
  }

  void _open(Notebook nb) => Navigator.push(context, MaterialPageRoute(builder: (_) => NotebookPage(nb: nb, onChanged: _persist)));

  Future<void> _delete(Notebook nb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف «${nb.title}»؟'),
        content: const Text('يُحذف الدفتر وملاحظاتك فيه نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    list!.remove(nb);
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final l = list;
    return Scaffold(
      appBar: AppBar(title: const Text('دفتر المحاضرات')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('دفتر جديد')),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => q = v),
                  decoration: const InputDecoration(hintText: 'ابحث في كل الدفاتر', prefixIcon: Icon(Icons.search)),
                ),
              ),
              Expanded(
                child: Builder(builder: (_) {
                  final shown = l.where((n) => notebookMatches(n, q)).toList();
                  if (shown.isEmpty) {
                    return EmptyNote(
                      icon: Icons.menu_book_outlined,
                      title: l.isEmpty ? 'لا دفاتر بعد' : 'لا نتائج',
                      body: l.isEmpty ? 'حوّل أي محاضرة (رابط يوتيوب أو نص) إلى دفتر منظّم مرتبط بتوقيت الفيديو.' : 'جرّب كلمة أخرى.',
                    );
                  }
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), children: [
                    for (final n in shown)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: cardBox(16),
                        child: ListTile(
                          onTap: () => _open(n),
                          onLongPress: () => _delete(n),
                          leading: const Icon(Icons.menu_book, color: kOk),
                          title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${nbModes[n.mode]} · ${n.sections.length} قسم${n.courseTitle == null ? '' : ' · ${n.courseTitle}'}',
                              style: const TextStyle(color: kInk2, fontSize: 12)),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: kInk2), onPressed: () => _delete(n)),
                        ),
                      ),
                  ]);
                }),
              ),
            ]),
    );
  }
}

/// Creates a notebook from a YouTube link (its own captions) or from pasted lecture text.
class NewNotebookPage extends StatefulWidget {
  const NewNotebookPage({super.key});
  @override
  State<NewNotebookPage> createState() => _NewNotebookPageState();
}

class _NewNotebookPageState extends State<NewNotebookPage> {
  final titleC = TextEditingController(), urlC = TextEditingController(), textC = TextEditingController();
  bool fromYoutube = true, busy = false;
  String mode = 'student';
  String? course, error, progress;

  Future<void> _go() async {
    if (!aiReady(app.settings)) {
      setState(() => error = 'أضف مفتاح الذكاء الاصطناعي من الإعدادات أولاً (المزيد ← الإعدادات).');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      progress = 'جاري التحضير...';
    });
    try {
      List<String> lines;
      String title = titleC.text.trim();
      String? videoId, url;
      if (fromYoutube) {
        if (urlC.text.trim().isEmpty) throw 'ألصق رابط الفيديو';
        setState(() => progress = 'جلب الترجمة النصية للفيديو...');
        final t = await fetchTranscript(urlC.text);
        lines = t.lines;
        videoId = t.videoId;
        url = urlC.text.trim();
        if (title.isEmpty) title = t.title;
      } else {
        final raw = textC.text.trim();
        if (raw.length < 80) throw 'النص قصير جداً. ألصق نص المحاضرة.';
        lines = raw.split(RegExp(r'\n+')).where((e) => e.trim().isNotEmpty).toList();
        if (title.isEmpty) title = 'محاضرة ${fmtDm(DateTime.now())}';
      }
      final secs = await generateSections(
        settings: app.settings,
        mode: mode,
        title: title,
        lines: lines,
        timed: fromYoutube,
        onProgress: (d, n) {
          if (mounted) setState(() => progress = 'كتابة الدفتر... ($d/$n)');
        },
      );
      if (!mounted) return;
      Navigator.pop(context, Notebook(title: title, mode: mode, courseTitle: course, videoId: videoId, url: url, sections: secs));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = app.tree?.courses ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('دفتر جديد')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('من رابط يوتيوب'), selected: fromYoutube, onSelected: busy ? null : (_) => setState(() => fromYoutube = true)),
          ChoiceChip(label: const Text('من نص ملصوق'), selected: !fromYoutube, onSelected: busy ? null : (_) => setState(() => fromYoutube = false)),
        ]),
        const SizedBox(height: 14),
        TextField(controller: titleC, decoration: const InputDecoration(labelText: 'عنوان الدفتر (اختياري)')),
        const SizedBox(height: 12),
        if (fromYoutube)
          TextField(controller: urlC, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'رابط الفيديو', hintText: 'https://youtu.be/...'))
        else
          TextField(controller: textC, minLines: 6, maxLines: 14, decoration: const InputDecoration(labelText: 'نص المحاضرة', alignLabelWithHint: true)),
        const SizedBox(height: 14),
        const Text('نمط الدفتر', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final e in nbModes.entries) ChoiceChip(label: Text(e.value), selected: mode == e.key, onSelected: busy ? null : (_) => setState(() => mode = e.key)),
        ]),
        if (courses.isNotEmpty) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: course,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المادة (اختياري)'),
            items: [for (final c in courses) DropdownMenuItem(value: c.title, child: Text(c.title, overflow: TextOverflow.ellipsis))],
            onChanged: busy ? null : (v) => setState(() => course = v),
          ),
        ],
        const SizedBox(height: 14),
        Text(
            'يُرسَل نص المحاضرة فقط إلى مزوّد الذكاء الاصطناعي الذي اخترته بمفتاحك، ولا يُرسَل شيء غيره. '
            'التوليد يحتاج إنترنت؛ عرض الدفاتر المحفوظة لا يحتاجه.',
            style: const TextStyle(fontSize: 12, color: kInk2, height: 1.6)),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: kErr, height: 1.5)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : _go,
          icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
          label: Text(busy ? (progress ?? '...') : 'أنشئ الدفتر'),
        ),
      ]),
    );
  }
}
