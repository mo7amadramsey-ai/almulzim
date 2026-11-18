import 'package:flutter/material.dart';
import '../app_state.dart';
import '../channel.dart';
import '../focus/storage.dart' show hasAllFiles;
import '../sync_page.dart';
import '../notifier.dart';
import '../theme.dart';
import 'follow_page.dart';
import 'calendar_page.dart';
import 'courses_page.dart';
import 'more_page.dart';
import 'plan_page.dart';
import 'strict_page.dart';
import 'today_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    app.init();
    askNotifPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      resumeStrictIfAny(context);
      _askStorage();
    });
  }

  // Offer the public folder (videos / documents survive uninstall and show in file managers)
  Future<void> _askStorage() async {
    try {
      if (await hasAllFiles() || !mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حفظ الملفات خارج التطبيق'),
          content: const Text(
              'اسمح بالوصول لمجلد FocusLock على الجهاز لتبقى فيديوهاتك ومستنداتك محفوظة عند حذف التطبيق وإعادة تثبيته.\n\nالمسار: FocusLock/videos و FocusLock/documents',
              style: TextStyle(height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لاحقاً')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('السماح')),
          ],
        ),
      );
      if (ok == true) await ch.invokeMethod('requestAllFiles');
    } catch (_) {}
  }

  Future<void> _sync() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncPage()));
    await app.init();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['اليوم', 'الخطة', 'المواد', 'المتابعة', 'المزيد'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          IconButton(
            tooltip: 'المرشد الذكي',
            icon: const Icon(Icons.auto_awesome, color: kCyan),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MentorScreen())),
          ),
          IconButton(
            tooltip: 'التقويم',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage())),
          ),
          IconButton(tooltip: 'استيراد من مودل', icon: const Icon(Icons.sync), onPressed: _sync),
        ],
      ),
      body: IndexedStack(index: tab, children: [
        TodayPage(onSync: _sync, onPlan: () => setState(() => tab = 1)),
        const PlanPage(),
        const CoursesPage(),
        const FollowPage(),
        const MorePage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'الخطة'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'المواد'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'المتابعة'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'المزيد'),
        ],
      ),
    );
  }
}
