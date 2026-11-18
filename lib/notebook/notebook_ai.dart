import '../ai.dart';
import '../study_models.dart';
import 'notebook_models.dart';

const _modeRules = {
  'student': 'اكتب دفتراً شاملاً ومنظماً كأنك طالب مجتهد دوّن المحاضرة: عناوين، تعريفات، قوانين، أمثلة، وملاحظات مهمة وأسئلة مراجعة.',
  'quick': 'اكتب مراجعة سريعة: أهم المفاهيم والتعريفات والقوانين فقط، بإيجاز.',
  'exam': 'اكتب خلاصة ليلة الامتحان: نقاط مركزة جداً مما يُرجّح السؤال عنه، مع القوانين والتعريفات الجوهرية.',
};

/// Builds the notebook sections from transcript lines. Only the text sent here leaves the phone.
Future<List<NbSection>> generateSections({
  required Settings settings,
  required String mode,
  required String title,
  required List<String> lines,
  required bool timed,
  void Function(int done, int total)? onProgress,
}) async {
  final chunks = chunkLines(lines);
  if (chunks.length > 10) throw 'النص طويل جداً (${chunks.length} أجزاء). قسّمه إلى محاضرتين.';
  final system = 'أنت طالب جامعي منظّم يدوّن المحاضرات بالعربية الطبيعية. '
      '${_modeRules[mode] ?? _modeRules['student']} '
      'قواعد صارمة: استخدم فقط ما ورد في النص المعطى. لا تخترع معلومة أو معادلة أو مثالاً وتنسبه إلى المحاضر. '
      'ما قاله المحاضر فعلاً يوسم src="lecturer". أي شرح إضافي أو إعادة صياغة من عندك يوسم src="ai". '
      'إن لم تتأكد من معلومة (نص مشوّش أو ترجمة آلية غير واضحة) ضع uncertain=true. '
      'أجب بكائن JSON واحد فقط بدون أي نص آخر.';
  final out = <NbSection>[];
  for (var i = 0; i < chunks.length; i++) {
    onProgress?.call(i, chunks.length);
    final user = 'عنوان المحاضرة: $title\n'
        '${timed ? 'كل سطر يبدأ بالتوقيت [mm:ss] ضمن الفيديو.\n' : 'النص بلا توقيتات: اجعل t=null.\n'}'
        'الجزء ${i + 1} من ${chunks.length}.\n---\n${chunks[i]}\n---\n'
        'المطلوب JSON بهذا الشكل بالضبط:\n'
        '{"sections":[{"title":"عنوان قصير","body":"المحتوى بالعربية، نقاط مفصولة بأسطر تبدأ بـ - عند الحاجة",'
        '"type":"concept|definition|law|example|note|warning|review",'
        '"t":ثوانٍ من بداية الفيديو لأول توقيت يخص القسم أو null,'
        '"src":"lecturer|ai","uncertain":true|false}]}';
    final reply = await aiAsk(settings: settings, system: system, messages: [
      {'role': 'user', 'content': user}
    ], maxTokens: 4000);
    out.addAll(parseSections(reply));
  }
  onProgress?.call(chunks.length, chunks.length);
  if (out.isEmpty) throw 'لم يُنتج الذكاء الاصطناعي أي قسم. جرّب نموذجاً آخر من الإعدادات.';
  return out;
}
