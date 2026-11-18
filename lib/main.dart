import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'channel.dart';
import 'focus/app_lock.dart' show AppLockGate;
import 'focus/nav.dart';
import 'focus/player_page.dart' show PlayerPage;
import 'focus/browser_page.dart' show StrictWebPage;
import 'focus/moodle_page.dart' show StrictMoodlePage;
import 'pages/shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  homeBuilder = () => const Shell();
  // Free rotation: landscape video / documents whenever you turn the phone
  SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  runApp(const AlmulzimApp());
}

class AlmulzimApp extends StatelessWidget {
  const AlmulzimApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'المُلزم',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.dark,
        navigatorKey: navKey,
        // Arabic-first: right-to-left, behind the phone's fingerprint / PIN
        builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl, child: AppBackdrop(child: AppLockGate(child: child!))),
        home: const Boot(),
      );
}

// On launch: if a strict video session is still running, jump straight back into it
class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  @override
  void initState() {
    super.initState();
    _resume();
  }

  Future<void> _resume() async {
    Map<String, dynamic>? s;
    try {
      s = await ch.invokeMapMethod<String, dynamic>('getSession');
    } catch (_) {}
    if (!mounted) return;
    Widget next = const Shell(); // a 'study' session is resumed by the Shell itself
    if (s != null) {
      final left = (s['left'] as num).toInt();
      final target = (s['target'] as String?) ?? '';
      final type = s['type'];
      if (left > 0) {
        if (type == 'web') {
          next = StrictWebPage(url: target, leftMs: left);
        } else if (type == 'moodle') {
          next = StrictMoodlePage(url: target, leftMs: left);
        } else if (type == 'local') {
          next = PlayerPage(path: target, leftMs: left);
        }
      }
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext c) =>
      const Scaffold(body: Center(child: CircularProgressIndicator(color: kAccent)));
}
