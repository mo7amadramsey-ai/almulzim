import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../viewer/youtube_page.dart';
import '../widgets.dart';
import 'notebook_models.dart';

Color typeColor(String t) => switch (t) {
      'definition' => kCyan,
      'law' => kAccent,
      'example' => kOk,
      'warning' => kWarn,
      'review' => kErr,
      _ => kInk2,
    };

/// One notebook: sections tied to video timestamps, editable by hand.
class NotebookPage extends StatefulWidget {
  final Notebook nb;
  final Future<void> Function() onChanged;
  const NotebookPage({super.key, required this.nb, required this.onChanged});
  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  Notebook get nb => widget.nb;

  Future<void> _save() async {
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  void _play(int t) {
    final id = nb.videoId;
    if (id == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => YoutubePlayerPage(videoId: id, title: nb.title, originalUrl: nb.url ?? 'https://m.youtube.com/watch?v=$id', start: t)));
  }

  Future<void> _edit(NbSection? s) async {
    final isNew = s == null;
    final sec = s ?? NbSection(title: '', body: '', src: 'me', type: 'note');
    final tc = TextEditingController(text: sec.title), bc = TextEditingController(text: sec.body);
    var type = sec.type;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isNew ? 'ملاحظة جديدة' : 'تعديل القسم'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: tc, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 10),
              TextField(controller: bc, minLines: 4, maxLines: 10, decoration: const InputDecoration(labelText: 'المحتوى')),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final e in nbTypes.entries)
                  ChoiceChip(label: Text(e.value), selected: type == e.key, onSelected: (_) => setD(() => type = e.key)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    sec.title = tc.text.trim().isEmpty ? 'ملاحظة' : tc.text.trim();
    sec.body = bc.text.trim();
    sec.type = type;
    if (!isNew && sec.src != 'me') sec.src = sec.src; // edited text keeps its original source label
    if (isNew) nb.sections.add(sec);
    await _save();
  }

  Future<void> _delete(NbSection s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القسم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    nb.sections.remove(s);
    await _save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(nb.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
          actions: [
            IconButton(
              tooltip: 'نسخ كنص',
              icon: const Icon(Icons.copy_all),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: notebookToMarkdown(nb)));
                if (context.mounted) toast(context, 'نُسخ الدفتر كاملاً');
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(null),
          icon: const Icon(Icons.edit_note),
          label: const Text('ملاحظتي'),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
          Panel(
            child: Row(children: [
              const Icon(Icons.info_outline, color: kCyan, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    '${nbModes[nb.mode]} · ${nb.sections.length} قسم. الأقسام الموسومة «الذكاء الاصطناعي» صياغة إضافية وليست كلام المحاضر، '
                    'وما عليه «غير مؤكد» راجعه مع المحاضرة. الدفتر مبني على النص فقط ولا يحلّل صورة الفيديو.',
                    style: const TextStyle(fontSize: 12.5, height: 1.6, color: kInk2)),
              ),
            ]),
          ),
          for (final s in nb.sections) _card(s),
          if (nb.sections.isEmpty) const EmptyNote(icon: Icons.menu_book, title: 'الدفتر فارغ', body: 'أضف ملاحظتك الأولى.'),
        ]),
      );

  Widget _card(NbSection s) {
    final col = typeColor(s.type);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: cardBox(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _edit(s),
        onLongPress: () => _delete(s),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _pill(nbTypes[s.type]!, col),
              if (s.t != null && nb.videoId != null)
                ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 16),
                  label: Text(fmtTs(s.t!)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _play(s.t!),
                )
              else if (s.t != null)
                _pill(fmtTs(s.t!), kInk2),
              _pill(nbSources[s.src]!, s.src == 'lecturer' ? kOk : (s.src == 'me' ? kAccent : kInk2)),
              if (s.uncertain) _pill('غير مؤكد', kWarn),
            ]),
            const SizedBox(height: 10),
            Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4)),
            if (s.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(s.body, style: const TextStyle(height: 1.7)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w700)),
      );
}
