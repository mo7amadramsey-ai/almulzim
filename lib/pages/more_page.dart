import 'package:flutter/material.dart';
import '../app_state.dart';
import '../focus/browser_page.dart' show BrowserPage;
import '../focus/docs.dart' show DocsPage;
import '../focus/library_page.dart' show LibraryPage;
import '../focus/moodle_page.dart' show MoodlePage;
import '../notebook/notebooks_page.dart';
import '../sync_page.dart';
import '../theme.dart';
import 'calendar_page.dart';
import 'mentor_page.dart';
import 'settings_page.dart';
import 'strict_page.dart';

/// Scaffold-wrapped mentor chat (the mentor is reachable from the app bar of every tab)
class MentorScreen extends StatelessWidget {
  const MentorScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('المرشد الذكي')), body: const MentorPage());
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  void _go(BuildContext c, Widget page, {bool reload = false}) async {
    await Navigator.push(c, MaterialPageRoute(builder: (_) => page));
    if (reload) app.init();
  }

  Widget _tile(BuildContext c, IconData icon, String title, String sub, Widget page, {Color color = kAccent, bool reload = false}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _go(c, page, reload: reload),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: cardBox(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 11.5, color: kInk2), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext c) => GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          _tile(c, Icons.lock_clock, 'القفل الدراسي', 'جلسة صارمة بمؤقت لا يُكسر', const StrictPage(), color: kErr),
          _tile(c, Icons.sync, 'استيراد المودل', 'قراءة كل المواد ومحتوياتها', const SyncPage(), color: kCyan, reload: true),
          _tile(c, Icons.school, 'تصفّح المودل', 'محاضرات ومستندات وتحميل', const MoodlePage(), color: kAccent),
          _tile(c, Icons.smart_display, 'يوتيوب', 'متصفح مقيّد + تحميل', const BrowserPage(), color: kErr),
          _tile(c, Icons.video_library, 'الفيديوهات', 'المحمّلة حسب المواد', const LibraryPage(), color: kWarn),
          _tile(c, Icons.description, 'المستندات', 'PDF وWord وExcel وPowerPoint', const DocsPage(), color: kOk),
          _tile(c, Icons.menu_book_rounded, 'دفتر المحاضرات', 'ملاحظات ذكية مرتبطة بتوقيت الفيديو', const NotebooksPage(), color: kOk),
          _tile(c, Icons.calendar_month, 'التقويم', 'امتحانات وتسليمات ودراسة', const CalendarPage(), color: kCyan),
          _tile(c, Icons.auto_awesome, 'المرشد الذكي', 'اسأل عن موادك وخطتك', const MentorScreen(), color: kAccent),
          _tile(c, Icons.tune, 'الإعدادات', 'الساعات والذكاء الاصطناعي والتنبيهات', const SettingsPage(), color: kInk2),
        ],
      );
}
