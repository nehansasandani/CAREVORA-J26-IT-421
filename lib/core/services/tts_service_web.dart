// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'cognitive_sinhala_audio_data.dart';
import 'tts_service.dart';

TtsService createTtsService() => WebTtsService();

class WebTtsService implements TtsService {
  html.AudioElement? _audio;
  bool _isSpeaking = false;

  @override
  VoidCallback? onComplete;

  /// Dedicated mapping of native Sinhala text phrases to high-fidelity,
  /// studio-quality neural Sinhala audio recordings.
  static final Map<String, String> _sinhalaAudioFiles = {
    // Assessment Questions (Q1 - Q10)
    'අද දවසේ ඔබට සිතට සතුටක් සහ සැනසීමක් දැනෙනවාද?': 'q1.mp3',
    'ඉදිරි දින පිළිබඳව ඔබ තුළ බලාපොරොත්තු සහගත හැඟීමක් තිබෙනවාද?': 'q2.mp3',
    'මෙහි ඔබ සමඟ සමීපව කතාබහ කිරීමට හෝ අදහස් බෙදා ගැනීමට කෙනෙකු සිටිනවාද?': 'q3.mp3',
    'අන් අය එකතු වී සිටින විට, ඔබට තනි වී ඇති බවක් හෝ කොන් වී ඇති බවක් දැනෙනවාද?': 'q4.mp3',
    'ඔබේ දවසෙන් වැඩි කාලයක් කාමරය තුළ තනිවම ගත කරනවාද?': 'q5.mp3',
    'ඔබව බැලීමට පැමිණෙන හෝ නිතර දුරකථනයෙන් කතා කරන පවුලේ අය හෝ හිතවතුන් සිටිනවාද?': 'q6.mp3',
    'මෙහි පැවැත්වෙන උදෑසන තේ පැන්, ව්‍යායාම හෝ උත්සව සඳහා සහභාගී වීමට ඔබ කැමතිද?': 'q7.mp3',
    'ඔබ සමඟ සහභාගී වීමට තවත් කෙනෙකු සිටී නම්, තවත් ක්‍රියාකාරකම්වලට එක්වීමට ඔබ කැමතිද?': 'q8.mp3',
    'ඔබේ සිතේ ඇති කරදර හෝ ගැටලු ඔබේ රැකවරණ නිලධාරීන් (caregivers) සමඟ පහසුවෙන් බෙදා ගැනීමට හැකිද?': 'q9.mp3',
    'ඔබේ සිතේ ඇති කරදර හෝ ගැටලු ඔබේ රැකවරණ නිලධාරීන් සමඟ පහසුවෙන් බෙදා ගැනීමට හැකිද?': 'q9.mp3',
    'සිතට නොසන්සුන්තාවයක් දැනෙන විට, සන්සුන් සංගීතයකට හෝ ආගමික වතාවත්වලට (පිරිත්/ගාථා වැනි) සවන් දීමෙන් සිත සන්සුන් වෙනවාද?': 'q10.mp3',
    'සිතට නොසන්සුන්තාවයක් දැනෙන විට, සන්සුන් සංගීතයකට හෝ ආගමික වතාවත්වලට සවන් දීමෙන් සිත සන්සුන් වෙනවාද?': 'q10.mp3',

    // AI Celebrations & Positive Feedbacks
    'ගොඩක් ඒ ගැන ස්තූතියි! අද දවසේ ඔබ සිතින් සතුටින් සහ සහනයෙන් පසුවීම ගැන මම ගොඩක් සතුටු වෙනවා!': 'praise_q1.mp3',
    'ඉදිරි දින පිළිබඳව ඔබ තුළ සුබවාදී, ප්‍රීතිමත් බලාපොරොත්තු තිබීම ගැන මම ඉතාමත් සතුටු වෙනවා! ඔබ සැමදා සතුටින් සහ ජයග්‍රාහීව සිටින්න!': 'praise_q2.mp3',
    'මෙහි ඔබ සමඟ සමීපව කතාබහ කිරීමට කෙනෙකු සිටීම මහත් භාග්‍යයක්! ඔබේ මිත්‍රත්වය සහ සතුට සදා රැඳේවා!': 'praise_q3.mp3',
    'අන් අය එකතු වී සිටින විට ඔබ සතුටින්, සුහදව සහ ආදරයෙන් එක්ව සිටීම ගැන මම ඉතාමත් සතුටු වෙනවා!': 'praise_q4.mp3',
    'ඔබ කාමරයට පමණක් සීමා නොවී, නිරතුරුවම ක්‍රියාශීලීව සහ සමාජශීලීව කාලය ගත කිරීම ගැන මම ඉතාමත් සතුටු වෙනවා!': 'praise_q5.mp3',
    'විශිෂ්ටයි! ඔබ සහ ඔබේ රැකවරණ නිලධාරීන් අතර ඇති සුහද සන්නිවේදනය ඉතා අගනේය. ඒ ගැන මම සතුටු වෙනවා.': 'praise_q9.mp3',

    // AI Comforting & Clinical Interventions
    'ඔබේ දවසෙන් වැඩි කාලයක් කාමරය තුළ තනිවම ගත කිරීම වෙහෙසකර විය හැකිය. අපි සුහදව කතාබහ කර ඔබේ සිත සතුටු වන ක්‍රියාකාරකම් සොයා ගනිමු.': 'comfort_q5.mp3',
    'කරුණාකර එසේ සිතන්න එපා. ඔබ අප සැමට ඉතාමත් වටිනා සහ ආදරණීය කෙනෙක්. අපි සුහදව කතාබහ කරමු.': 'comfort_q4.mp3',
    'සිත දුකට පත් කරගන්න එපා. සෑම අලුත් දවසක්ම ජයග්‍රාහී බලාපොරොත්තුවක් සහ සැනසීමක් ගෙනෙනවා. අපි සුහදව කතා කරමු.': 'comfort_q2.mp3',
    'කරුණාකර තනිකමක් දැනෙන්න දෙන්න එපා. ඔබ කිසිවිටෙකත් තනි වී නැහැ, මම ඔබ ළඟින්ම සිටිනවා. ඔබේ සිත සන්සුන් කරන ගීතයකට අපි සවන් දෙමු.': 'comfort_q3.mp3',
    'කරුණාකර තනිකමක් දැනෙන්න දෙන්න එපා. ඔබ කිසිවිටෙකත් තනි වී නැහැ, මම ඔබ ළඟින්ම සිටිනවා. අමරදේවයන්ගේ සහ නන්දා මාලිනියන්ගේ සන්සුන් ගීතයකට අපි සවන් දෙමු.': 'comfort_q6.mp3',
    'ඒ ගැන ඇසීම කනගාටුදායකයි. ඔබට මේ ආකාරයට දැනෙන්නට හේතුව මට පැහැදිලි කරන්න පුළුවන්ද?': 'comfort_general.mp3',
    'ඔබ ඖෂධ ලබා ගත්තාද? ඔබට දැඩි අපහසුතාවයක් තිබේද? ඔබට වෛද්‍යවරයකු හමුවීමට අවශ්‍යද?': 'unwell.mp3',
    'ඔබේ සිත සන්සුන් කරගැනීමට මිහිරි ගීතයකට සවන් දීමට හෝ පොතක් කියවීමට ඔබ කැමතිද?': 'quiet.mp3',
    'ඔබේ සත්කාරක නිලධාරියාට සහ වෛද්‍යවරයාට හදිසි දැනුම්දීමක් යවන ලදී. කරුණාකර සන්සුන්ව විවේක ගන්න, ඔවුන් ඉක්මනින්ම පැමිණෙනු ඇත.': 'caregiver_alert.mp3',
    'පොත් කියවීමේ සැසිය වෙත සාදරයෙන් පිළිගනිමු. ඔබ කැමති පොතක් තෝරාගෙන සන්සුන්ව කියවන්න.': 'book_intro.mp3',
    'සන්සුන් සංගීත චිකිත්සාව වෙත සාදරයෙන් පිළිගනිමු. ඔබ කැමති ගීතයක් තෝරාගෙන මිනිත්තු 10 ක් සන්සුන්ව විවේක ගන්න.': 'music_intro.mp3',

    // Cognitive Assessment Questions (Q1 - Q10) & Navigation
    'අද මොන දවසද?': 'cog_q1.mp3',
    'මේ මොන අවුරුද්දද?': 'cog_q2.mp3',
    'මෙම වචන නැවත කියන්න: ඉර, පොත, ගස.': 'cog_q3.mp3',
    'මෙම වචන නැවත කියන්න: Sun (ඉර), Book (පොත), Tree (ගස).': 'cog_q3.mp3',
    'ඒ වචන තුන තවත් වරක් කියන්න.': 'cog_q4.mp3',
    '2 යි 3 යි එකතු කළාම කීයද?': 'cog_q5.mp3',
    '3 සහ 8 අතරින් විශාල අංකය කුමක්ද?': 'cog_q6.mp3',
    'කලින් කියපු වචන තුන මොනවාද?': 'cog_q7.mp3',
    'කලින් ඉර කියන වචනය ඔබට ඇසුණාද?': 'cog_q8.mp3',
    'කලින් Sun (ඉර) කියන වචනය ඔබට ඇසුණාද?': 'cog_q8.mp3',
    'වේලාව බලාගන්න ඔබ භාවිතා කරන්නේ මොනවාද?': 'cog_q9.mp3',
    'ඇපල් සහ දොඩම් යන දෙකම පලතුරුද?': 'cog_q10.mp3',
    'ඊළඟ ප්‍රශ්නය': 'cog_next.mp3',
  };

  static String? _matchSinhalaAudioFile(String rawText) {
    final text = rawText.trim();
    if (_sinhalaAudioFiles.containsKey(text)) {
      return _sinhalaAudioFiles[text];
    }

    // Cognitive Assessment exact/keyword match first
    if (text.contains('අද මොන දවසද')) return 'cog_q1.mp3';
    if (text.contains('මේ මොන අවුරුද්දද')) return 'cog_q2.mp3';
    if (text.contains('මෙම වචන නැවත කියන්න')) return 'cog_q3.mp3';
    if (text.contains('ඒ වචන තුන තවත් වරක් කියන්න')) return 'cog_q4.mp3';
    if (text.contains('එකතු කළාම කීයද')) return 'cog_q5.mp3';
    if (text.contains('විශාල අංකය කුමක්ද')) return 'cog_q6.mp3';
    if (text.contains('කලින් කියපු වචන තුන')) return 'cog_q7.mp3';
    if (text.contains('කියන වචනය ඔබට ඇසුණාද')) return 'cog_q8.mp3';
    if (text.contains('වේලාව බලාගන්න')) return 'cog_q9.mp3';
    if (text.contains('ඇපල් සහ දොඩම්')) return 'cog_q10.mp3';
    if (text == 'ඊළඟ ප්‍රශ්නය') return 'cog_next.mp3';

    for (final entry in _sinhalaAudioFiles.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    // Keyword heuristics ONLY for the 10 Clinical Social Assessment Questions (q1.mp3 - q10.mp3) and their specific praise/comfort responses
    if (text.contains('අද දවසේ') && text.contains('සතුටක් සහ සැනසීමක්')) return 'q1.mp3';
    if (text.contains('ඉදිරි දින') && text.contains('බලාපොරොත්තු සහගත')) {
      if (text.contains('සුබවාදී') || text.contains('ප්‍රීතිමත්')) return 'praise_q2.mp3';
      return 'q2.mp3';
    }
    if (text.contains('මෙහි ඔබ සමඟ සමීපව කතාබහ කිරීමට') || text.contains('අදහස් බෙදා ගැනීමට කෙනෙකු සිටිනවාද')) {
      if (text.contains('භාග්‍යයක්')) return 'praise_q3.mp3';
      return 'q3.mp3';
    }
    if (text.contains('අන් අය එකතු වී සිටින විට, ඔබට තනි වී ඇති බවක්')) return 'q4.mp3';
    if (text.contains('අන් අය එකතු වී සිටින විට ඔබ සතුටින්')) return 'praise_q4.mp3';
    if (text.contains('ඔබේ දවසෙන් වැඩි කාලයක් කාමරය තුළ තනිවම ගත කරනවාද')) return 'q5.mp3';
    if (text.contains('ඔබේ දවසෙන් වැඩි කාලයක් කාමරය තුළ තනිවම ගත කිරීම වෙහෙසකර')) return 'comfort_q5.mp3';
    if (text.contains('කාමරයට පමණක් සීමා නොවී, නිරතුරුවම ක්‍රියාශීලීව')) return 'praise_q5.mp3';
    if (text.contains('බැලීමට පැමිණෙන හෝ නිතර දුරකථනයෙන් කතා කරන')) return 'q6.mp3';
    if (text.contains('මෙහි පැවැත්වෙන උදෑසන තේ පැන්, ව්‍යායාම හෝ උත්සව')) return 'q7.mp3';
    if (text.contains('තවත් කෙනෙකු සිටී නම්, තවත් ක්‍රියාකාරකම්වලට එක්වීමට')) return 'q8.mp3';
    if (text.contains('කරදර හෝ ගැටලු ඔබේ රැකවරණ නිලධාරීන් සමඟ')) return 'q9.mp3';
    if (text.contains('සුහද සන්නිවේදනය ඉතා අගනේය')) return 'praise_q9.mp3';
    if (text.contains('නොසන්සුන්තාවයක් දැනෙන විට, සන්සුන් සංගීතයකට හෝ ආගමික වතාවත්වලට')) return 'q10.mp3';

    if (text.contains('ගොඩක් ඒ ගැන ස්තූතියි! අද දවසේ ඔබ සිතින් සතුටින්')) return 'praise_q1.mp3';
    if (text.contains('කරුණාකර එසේ සිතන්න එපා. ඔබ අප සැමට ඉතාමත් වටිනා')) return 'comfort_q4.mp3';
    if (text.contains('සිත දුකට පත් කරගන්න එපා. සෑම අලුත් දවසක්ම ජයග්‍රාහී')) return 'comfort_q2.mp3';
    if (text.contains('අමරදේවයන්ගේ සහ නන්දා මාලිනියන්ගේ සන්සුන් ගීතයකට')) return 'comfort_q6.mp3';
    if (text.contains('කරුණාකර තනිකමක් දැනෙන්න දෙන්න එපා. ඔබ කිසිවිටෙකත් තනි වී නැහැ')) return 'comfort_q3.mp3';
    if (text.contains('ඒ ගැන ඇසීම කනගාටුදායකයි. ඔබට මේ ආකාරයට දැනෙන්නට හේතුව')) return 'comfort_general.mp3';
    if (text.contains('දැඩි අපහසුතාවයක් තිබේද? ඔබට වෛද්‍යවරයකු හමුවීමට අවශ්‍යද')) return 'unwell.mp3';
    if (text.contains('ඔබේ සිත සන්සුන් කරගැනීමට මිහිරි ගීතයකට සවන් දීමට හෝ පොතක් කියවීමට ඔබ කැමතිද')) return 'quiet.mp3';
    if (text.contains('ඔබේ සත්කාරක නිලධාරියාට සහ වෛද්‍යවරයාට හදිසි දැනුම්දීමක් යවන ලදී')) return 'caregiver_alert.mp3';
    if (text.contains('පොත් කියවීමේ සැසිය වෙත සාදරයෙන් පිළිගනිමු')) return 'book_intro.mp3';
    if (text.contains('සන්සුන් සංගීත චිකිත්සාව වෙත සාදරයෙන් පිළිගනිමු')) return 'music_intro.mp3';

    return null;
  }

  static final Map<String, String> _knownSinhalaMap = {
    'අද දවසේ ඔබට සිතට සතුටක් සහ සැනසීමක් දැනෙනවාද?':
        'Ada dawase obata sithata sathutak saha saneeseemak denenawaada?',
    'ඉදිරි දින පිළිබඳව ඔබ තුළ බලාපොරොත්තු සහගත හැඟීමක් තිබෙනවාද?':
        'Idiri dina pilibandawa oba thula balaporoththu sahagatha hengeemak thiyenawaada?',
    'මෙහි ඔබ සමඟ සමීපව කතාබහ කිරීමට හෝ අදහස් බෙදා ගැනීමට කෙනෙකු සිටිනවාද?':
        'Mehi oba samanga sameepawa kathabaha kireemata ho adahas bedaa geneemata keneku sitinawaada?',
    'අන් අය එකතු වී සිටින විට, ඔබට තනි වී ඇති බවක් හෝ කොන් වී ඇති බවක් දැනෙනවාද?':
        'An aya ekathu vee sitina vita, obata thani vee ethi bawak ho kon vee ethi bawak denenawaada?',
    'ඔබේ දවසෙන් වැඩි කාලයක් කාමරය තුළ තනිවම ගත කරනවාද?':
        'Obe dawasen wedie kaalayak kaamaraya thula thaniwama gatha karanawaada?',
    'ඔබව බැලීමට පැමිණෙන හෝ නිතර දුරකථනයෙන් කතා කරන පවුලේ අය හෝ හිතවතුන් සිටිනවාද?':
        'Obawa beleemata peminena ho nithara durakathanayen katha karana pawle aya ho hithawathun sitinawaada?',
    'මෙහි පැවැත්වෙන උදෑසන තේ පැන්, ව්‍යායාම හෝ උත්සව සඳහා සහභාගී වීමට ඔබ කැමතිද?':
        'Mehi pewethwena udaasana thee pen, wyaayaama ho uthsawa sandahaa sahbhaagee veemata oba kemathida?',
    'ඔබ සමඟ සහභාගී වීමට තවත් කෙනෙකු සිටී නම්, තවත් ක්‍රියාකාරකම්වලට එක්වීමට ඔබ කැමතිද?':
        'Oba samanga sahbhaagee veemata thawath keneku sitie nam, thawath kriyaakaarakamwalata ekveemata oba kemathida?',
    'ඔබේ සිතේ ඇති කරදර හෝ ගැටලු ඔබේ රැකවරණ නිලධාරීන් (caregivers) සමඟ පහසුවෙන් බෙදා ගැනීමට හැකිද?':
        'Obe sithe ethi karadara ho getalu obe rekawarana niladhaareen samanga pahasuwen bedaa geneemata hekida?',
    'ඔබේ සිතේ ඇති කරදර හෝ ගැටලු ඔබේ රැකවරණ නිලධාරීන් සමඟ පහසුවෙන් බෙදා ගැනීමට හැකිද?':
        'Obe sithe ethi karadara ho getalu obe rekawarana niladhaareen samanga pahasuwen bedaa geneemata hekida?',
    'සිතට නොසන්සුන්තාවයක් දැනෙන විට, සන්සුන් සංගීතයකට හෝ ආගමික වතාවත්වලට (පිරිත්/ගාථා වැනි) සවන් දීමෙන් සිත සන්සුන් වෙනවාද?':
        'Sithata nosansunthawayak denena vita, sansun sangeethayakata ho aagamika wathaawathwalata sawan deemen sitha sansun wenawaada?',
    'සිතට නොසන්සුන්තාවයක් දැනෙන විට, සන්සුන් සංගීතයකට හෝ ආගමික වතාවත්වලට සවන් දීමෙන් සිත සන්සුන් වෙනවාද?':
        'Sithata nosansunthawayak denena vita, sansun sangeethayakata ho aagamika wathaawathwalata sawan deemen sitha sansun wenawaada?',
    'ගොඩක් ඒ ගැන ස්තූතියි! අද දවසේ ඔබ සිතින් සතුටින් සහ සහනයෙන් පසුවීම ගැන මම ගොඩක් සතුටු වෙනවා!':
        'Godaak ee gena sthuthiyi! Ada dawase oba sithin sathutin saha sahanayen pasuveema gena mama godaak sathutu wenawaa!',
    'ඉදිරි දින පිළිබඳව ඔබ තුළ සුබවාදී, ප්‍රීතිමත් බලාපොරොත්තු තිබීම ගැන මම ඉතාමත් සතුටු වෙනවා! ඔබ සැමදා සතුටින් සහ ජයග්‍රාහීව සිටින්න!':
        'Idiri dina pilibandawa oba thula subawaadee, preethimath balaporoththu thibeema gena mama ithaa math sathutu wenawaa! Oba semadaa sathutin saha jayagraaheewa sitinna!',
    'මෙහි ඔබ සමඟ සමීපව කතාබහ කිරීමට කෙනෙකු සිටීම මහත් භාග්‍යයක්! ඔබේ මිත්‍රත්වය සහ සතුට සදා රැඳේවා!':
        'Mehi oba samanga sameepawa kathabaha kireemata keneku sitheema mahath bhaagyayak! Obe mithrathwaya saha sathuta sadaa redheewaa!',
    'අන් අය එකතු වී සිටින විට ඔබ සතුටින්, සුහදව සහ ආදරයෙන් එක්ව සිටීම ගැන මම ඉතාමත් සතුටු වෙනවා!':
        'An aya ekathu vee sitina vita oba sathutin, suhadawa saha aadarayen ekwa sitheema gena mama ithaa math sathutu wenawaa!',
    'ඔබ කාමරයට පමණක් සීමා නොවී, නිරතුරුවම ක්‍රියාශීලීව සහ සමාජශීලීව කාලය ගත කිරීම ගැන මම ඉතාමත් සතුටු වෙනවා!':
        'Oba kaamarayata pamanak seemaa nowee, nirathuruwama kriyaasheeleewa saha samaajasheeleewa kaalaya gatha kireema gena mama ithaa math sathutu wenawaa!',
    'විශිෂ්ටයි! ඔබ සහ ඔබේ රැකවරණ නිලධාරීන් අතර ඇති සුහද සන්නිවේදනය ඉතා අගනේය. ඒ ගැන මම සතුටු වෙනවා.':
        'Vishishtayi! Oba saha obe rekawarana niladhaareen athara ethi suhada sannivedanaya ithaa aganeya. Ee gena mama sathutu wenawaa.',
    'ඔබේ දවසෙන් වැඩි කාලයක් කාමරය තුළ තනිවම ගත කිරීම වෙහෙසකර විය හැකිය. අපි සුහදව කතාබහ කර ඔබේ සිත සතුටු වන ක්‍රියාකාරකම් සොයා ගනිමු.':
        'Obe dawasen wedie kaalayak kaamaraya thula thaniwama gatha kireema wehesakara viya hekiya. Api suhadawa kathabaha kara obe sitha sathutu wana kriyaakaarakam soyaa ganimu.',
    'කරුණාකර එසේ සිතන්න එපා. ඔබ අප සැමට ඉතාමත් වටිනා සහ ආදරණීය කෙනෙක්. අපි සුහදව කතාබහ කරමු.':
        'Karunaakaraven esee sithanna epaa. Oba apa semata ithaa math watinaa saha aadaraNeeya kenek. Api suhadawa katha karamu.',
    'සිත දුකට පත් කරගන්න එපා. සෑම අලුත් දවසක්ම ජයග්‍රාහී බලාපොරොත්තුවක් සහ සැනසීමක් ගෙනෙනවා. අපි සුහදව කතා කරමු.':
        'Sitha dukata path kara ganna epaa. Seme aluth dawasakma jayagraahee balaporoththuwak saha seneeseemak genenawaa. Api suhadawa katha karamu.',
    'කරුණාකර තනිකමක් දැනෙන්න දෙන්න එපා. ඔබ කිසිවිටෙකත් තනි වී නැහැ, මම ඔබ ළඟින්ම සිටිනවා. ඔබේ සිත සන්සුන් කරන ගීතයකට අපි සවන් දෙමු.':
        'Karunaakaraven thanikamak denenna denna epaa. Oba kisiwitekath thani vee nehe, mama oba langinma sitinawaa. Obe sitha sansun karana geethayakata api sawan demu.',
    'කරුණාකර තනිකමක් දැනෙන්න දෙන්න එපා. ඔබ කිසිවිටෙකත් තනි වී නැහැ, මම ඔබ ළඟින්ම සිටිනවා. අමරදේවයන්ගේ සහ නන්දා මාලිනියන්ගේ සන්සුන් ගීතයකට අපි සවන් දෙමු.':
        'Karunaakaraven thanikamak denenna denna epaa. Oba kisiwitekath thani vee nehe, mama oba langinma sitinawaa. Amaradevayange saha Nanda Maalineeyange sansun geethayakata api sawan demu.',
    'ඒ ගැන ඇසීම කනගාටුදායකයි. ඔබට මේ ආකාරයට දැනෙන්නට හේතුව මට පැහැදිලි කරන්න පුළුවන්ද?':
        'Ee gena eseema kanagaatudhaayakai. Obata mee aakaarayata denenna hethuwa mata pehedili karanna puluwanda?',
    'ඔබ ඖෂධ ලබා ගත්තාද? ඔබට දැඩි අපහසුතාවයක් තිබේද? ඔබට වෛද්‍යවරයකු හමුවීමට අවශ්‍යද?':
        'Oba aushadha labaa gaththaada? Obata dedi apahasuthaawayak thiyenawaada? Obata waidyawarayaku hamuveemata awashyada?',
    'ඔබේ සිත සන්සුන් කරගැනීමට මිහිරි ගීතයකට සවන් දීමට හෝ පොතක් කියවීමට ඔබ කැමතිද?':
        'Obe sitha sansun kara geneemata mihiri geethayakata sawan deemata ho pothak kiyaveemata oba kemathida?',
    'ඔබේ සත්කාරක නිලධාරියාට සහ වෛද්‍යවරයාට හදිසි දැනුම්දීමක් යවන ලදී. කරුණාකර සන්සුන්ව විවේක ගන්න, ඔවුන් ඉක්මනින්ම පැමිණෙනු ඇත.':
        'Obe sathkaaraka niladhaariyaata saha waidyawarayata hadisi denumdeemak ywana ladhee. Karunaakaraven sansunwa viveka ganna, owun ikmaninma peminenu etha.',
    'පොත් කියවීමේ සැසිය වෙත සාදරයෙන් පිළිගනිමු. ඔබ කැමති පොතක් තෝරාගෙන සන්සුන්ව කියවන්න.':
        'Poth kiyaveeme sesiya wetha saadarayen piliganimu. Oba kemathi pothak thoraagena sansunwa kiyawanna.',
    'සන්සුන් සංගීත චිකිත්සාව වෙත සාදරයෙන් පිළිගනිමු. ඔබ කැමති ගීතයක් තෝරාගෙන මිනිත්තු 10 ක් සන්සුන්ව විවේක ගන්න.':
        'Sansun sangeetha chikithsawa wetha saadarayen piliganimu. Oba kemathi geethayak thoraagena miniththu dahayak sansunwa viveka ganna.',
    // Cognitive Assessment 10 Questions (Q1 - Q10) & Navigation
    'අද මොන දවසද?': 'Ada mona dawasada?',
    'මේ මොන අවුරුද්දද?': 'Mee mona awurudhdhada?',
    'මෙම වචන නැවත කියන්න: ඉර, පොත, ගස.':
        'Mema wachana newatha kiyanna: Ira, Potha, Gasa.',
    'මෙම වචන නැවත කියන්න: Sun (ඉර), Book (පොත), Tree (ගස).':
        'Mema wachana newatha kiyanna: Ira, Potha, Gasa.',
    'ඒ වචන තුන තවත් වරක් කියන්න.': 'Ee wachana thuna thawath warak kiyanna.',
    '2 යි 3 යි එකතු කළාම කීයද?': 'Dekai thunai ekathu kalaama keeyada?',
    '3 සහ 8 අතරින් විශාල අංකය කුමක්ද?':
        'Thuna saha ata atharin vishaala ankaya kumakda?',
    'කලින් කියපු වචන තුන මොනවාද?': 'Kalin kiyapu wachana thuna monawaada?',
    'කලින් ඉර කියන වචනය ඔබට ඇසුණාද?':
        'Kalin Ira kiyana wachanaya obata esunaada?',
    'කලින් Sun (ඉර) කියන වචනය ඔබට ඇසුණාද?':
        'Kalin Ira kiyana wachanaya obata esunaada?',
    'වේලාව බලාගන්න ඔබ භාවිතා කරන්නේ මොනවාද?':
        'Welaawa balaa ganna oba bhaavithaa karanne monawaada?',
    'ඇපල් සහ දොඩම් යන දෙකම පලතුරුද?': 'Epal saha dodam yana dekama palathuruda?',
    'ඊළඟ ප්‍රශ්නය': 'Eelanga prashnaya',

    // --- High-Fidelity Conversational Sinhala Phonetics for Natural Human Speech ---
    // Greetings with elder resident names
    'සුබ උදෑසනක්, කුමාර මහත්මයා! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba udaesanak, Kumara mahathmaya! Oba gena adath hondin salakamu!',
    'සුබ දහවල් කාලයක්, කුමාර මහත්මයා! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba dahawal kaalayak, Kumara mahathmaya! Oba gena adath hondin salakamu!',
    'සුබ සන්ධ්‍යාවක්, කුමාර මහත්මයා! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba sandhyaawak, Kumara mahathmaya! Oba gena adath hondin salakamu!',
    'සුබ රාත්‍රියක්, කුමාර මහත්මයා! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba raathriyak, Kumara mahathmaya! Oba gena adath hondin salakamu!',
    'සුබ උදෑසනක්, කුමාර! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba udaesanak, Kumara! Oba gena adath hondin salakamu!',
    'සුබ දහවල් කාලයක්, කුමාර! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba dahawal kaalayak, Kumara! Oba gena adath hondin salakamu!',
    'සුබ සන්ධ්‍යාවක්, කුමාර! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba sandhyaawak, Kumara! Oba gena adath hondin salakamu!',
    'සුබ රාත්‍රියක්, කුමාර! ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Suba raathriyak, Kumara! Oba gena adath hondin salakamu!',
    'සුබ උදෑසනක්, කුමාර! ඔබ උදෑසන තේ පානය කළාද?':
        'Suba udaesanak, Kumara! Oba udaasana tay paanaya kalaada?',
    'සුබ උදෑසනක්, කුමාර මහත්මයා! ඔබ උදෑසන තේ පානය කළාද?':
        'Suba udaesanak, Kumara mahathmaya! Oba udaasana tay paanaya kalaada?',
    'සුබ දහවල් කාලයක්, කුමාර! ඔබ දිවා ආහාරය ගත්තාද?':
        'Suba dahawal kaalayak, Kumara! Oba diwa aahaaraya gaththaada?',
    'සුබ දහවල් කාලයක්, කුමාර මහත්මයා! ඔබ දිවා ආහාරය ගත්තාද?':
        'Suba dahawal kaalayak, Kumara mahathmaya! Oba diwa aahaaraya gaththaada?',
    'සුබ සන්ධ්‍යාවක්, කුමාර! ඔබ සවස තේ පැන් පානය කළාද?':
        'Suba sandhyaawak, Kumara! Oba sawasa tay pan paanaya kalaada?',
    'සුබ සන්ධ්‍යාවක්, කුමාර මහත්මයා! ඔබ සවස තේ පැන් පානය කළාද?':
        'Suba sandhyaawak, Kumara mahathmaya! Oba sawasa tay pan paanaya kalaada?',
    'සුබ රාත්‍රියක්, කුමාර! ඔබ රාත්‍රී ආහාරය හා ඖෂධ ලබා ගත්තාද?':
        'Suba raathriyak, Kumara! Oba raathree aahaaraya haa aushadha labaa gaththaada?',
    'සුබ රාත්‍රියක්, කුමාර මහත්මයා! ඔබ රාත්‍රී ආහාරය හා ඖෂධ ලබා ගත්තාද?':
        'Suba raathriyak, Kumara mahathmaya! Oba raathree aahaaraya haa aushadha labaa gaththaada?',

    // Routine Cards - Card 1 Prompts
    'උදේ තේ බිව්වද? සුවබර උදෑසනකට උණුසුම් තේ පැන් බිව්වා නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Uday tay biwwada? Suwabara udaesanakata unusum tay pan biwwa nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'උදේ තේ බිව්වද? සුවබර උදෑසනකට උණුසුම් තේ පැන් පානය කළා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Uday tay biwwada? Suwabara udaesanakata unusum tay pan paanaya kalaa nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',
    'දිවා ආහාරය ගත්තාද? පෝෂ්‍යදායී දිවා ආහාරය ගත්තා නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Diwa aahaaraya gaththaada? Poashyadaayee diwa aahaaraya gaththaa nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'දිවා ආහාරය ගත්තාද? පෝෂ්‍යදායී දිවා ආහාරය ගත්තා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Diwa aahaaraya gaththaada? Poashyadaayee diwa aahaaraya gaththaa nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',
    'සවස තේ පැන් පානය කළාද? උණුසුම් තේ පැන් බිව්වා නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Sawasa tay pan paanaya kalaada? Unusum tay pan biwwa nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'සවස තේ පැන් පානය කළාද? උණුසුම් තේ පැන් බිව්වා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Sawasa tay pan paanaya kalaada? Unusum tay pan biwwa nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',
    'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද? සුව නින්දකට පෙර ආහාර හා නියමිත ඖෂධ ලබා ගත්තා නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Raathree aahaara haa aushadha gaththaada? Suwa nindakata pera aahaara haa niyamitha aushadha labaa gaththaa nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද? නියමිත ආහාර හා ඖෂධ ලබා ගත්තා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Raathree aahaara haa aushadha gaththaada? Niyamitha aahaara haa aushadha labaa gaththaa nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',

    // Routine Cards - Card 2 Prompts
    'මුහුණ හෝදාගත්තාද? ප්‍රබෝධමත්ව මුහුණ සෝදා පිරිසිදු වුණා නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Muhuna hoodaagaththaada? Praboadhamathwa muhuna soadaa pirisidu wunaa nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'මුහුණ හෝදාගත්තාද? ප්‍රබෝධමත් දවසකට මුහුණ සෝදා පිරිසිදු වුණා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Muhuna hoodaagaththaada? Praboadhamath dawasakata muhuna soadaa pirisidu wunaa nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',
    'කෙටි විවේකයක් ගත්තාද? සුවදායක කෙටි විවේකයක් ලබා ගත්තා නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Keti wivekayak gaththaada? Suwadaayaka keti wivekayak labaa gaththaa nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'කෙටි විවේකයක් ගත්තාද? සුවදායක කෙටි විවේකයක් ලබා ගත්තා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Keti wivekayak gaththaada? Suwadaayaka keti wivekayak labaa gaththaa nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',
    'නැවුම් සුළං සුවය වින්දාද? සවස නැවුම් සුළඟ වින්දා නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Newum sulan suwaya vindaada? Sawasa newum sulanga vindaa nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'නැවුම් සුළං සුවය වින්දාද? සවස නැවුම් සුළඟ වින්දා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Newum sulan suwaya vindaada? Sawasa newum sulanga vindaa nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',
    'සුව නින්දකට සූදානම්ද? සැනසිලිදායක, සුවබර නින්දකට සූදානම් නම් කොළ පාට ඔව් ඔබන්න. තවම නැත්නම් තවම නැහැ ඔබන්න.':
        'Suwa nindakata soodaanamda? Senasilidaayaka, suwabara nindakata soodaanam nam kola paata ov obanna. Thawama nethnam thawama naehe obanna.',
    'සුව නින්දකට සූදානම්ද? සැනසිලිදායක නින්දකට සූදානම් නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Suwa nindakata soodaanamda? Senasilidaayaka nindakata soodaanam nam kola paata boththama obanna. Thawama nethnam thawama naehe boththama obanna.',

    // Center Robot Speech Bubble
    'නෆියා ඔබෙන් අසනවා: අද උදයේ මූලික පුරුදු කරගත්තාද?':
        'Nafiya oben asanawa: Ada udaye moolika purudu karagaththaada?',
    'නෆියා ඔබෙන් අසනවා: අද දහවල් සුවපහසු විවේකය ලබාගත්තාද?':
        'Nafiya oben asanawa: Ada dahawal suwapahasu wivekaya labaagaththaada?',
    'නෆියා ඔබෙන් අසනවා: අද සවස නැවුම් සුවය වින්දාද?':
        'Nafiya oben asanawa: Ada sawasa newum suwaya vindaada?',
    'නෆියා ඔබෙන් අසනවා: අද රාත්‍රී සුව නින්දකට සූදානම්ද?':
        'Nafiya oben asanawa: Ada raathree suwa nindakata soodaanamda?',
    'අද උදයේ මූලික පුරුදු කටයුතු කරගත්තාද?':
        'Ada udaye moolika purudu katayuthu karagaththaada?',
    'අද උදයේ\nමූලික පුරුදු\nකරගත්තාද? 💜':
        'Ada udaye moolika purudu katayuthu karagaththaada?',
    'අද දහවල් සුවපහසු විවේකය ලබාගත්තාද?':
        'Ada dahawal suwapahasu wivekaya labaagaththaada?',
    'අද දහවල්\nසුවපහසු විවේකය\nලබාගත්තාද? 💜':
        'Ada dahawal suwapahasu wivekaya labaagaththaada?',
    'අද සවස නැවුම් සුවය වින්දාද?':
        'Ada sawasa newum suwaya vindaada?',
    'අද සවස\nනැවුම් සුවය\nවින්දාද? 💜':
        'Ada sawasa newum suwaya vindaada?',
    'අද රාත්‍රී සුව නින්දකට සූදානම්ද?':
        'Ada raathree suwa nindakata soodaanamda?',
    'අද රාත්‍රී\nසුව නින්දකට\nසූදානම්ද? 💜':
        'Ada raathree suwa nindakata soodaanamda?',

    // Care Notice Pill
    'රැකබලා ගන්නා දැනුවත් කරන ලදී: ඔබට අවශ්‍ය සහාය ලබා දීමට සහායක කණ්ඩායම පැමිණෙනු ඇත.':
        'Rekabalaagannaa denuwath karana ladee: Obata awashya sahaaya labaa deemata sahaayaka kandaayama peminenu etha.',
    'තවම කරගෙන නැත්නම්, අපේ සත්කාර කණ්ඩායම ඔබට මිතුරු වෙමින් උදව් කිරීමට දැනුම් දෙනවා.':
        'Thawama karagena nethnam, apay sathkaara kandaayama obata mithuru wemin udaw kireemata danum denawa.',
    'තවම කරගෙන නැත්නම්, අපේ සත්කාර කණ්ඩායම ඔබට මිතුරු වෙමින් දැනුම් දෙනවා.':
        'Thawama karagena nethnam, apay sathkaara kandaayama obata mithuru wemin danum denawa.',

    // Left Greeting Audio Pill
    'ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Oba gena adath hondin salakamu!',
    'ඔබ ගැන අදත් හොඳින් සලකමු':
        'Oba gena adath hondin salakamu',
    'අදත් සුවපහසු, සතුටුදායක දිනයක් එක්ව ආරම්භ කරමු!':
        'Adath suwapahasu, sathutudaayaka dinayak ekwa aarambha karamu!',
    'අදත් සුවපහසු, සතුටුදායක දිනයක් එක්ව ආරම්භ කරමු':
        'Adath suwapahasu, sathutudaayaka dinayak ekwa aarambha karamu',
    'ප්‍රීතිමත්, සුවබර උදෑසනක්!':
        'Preethimath, suwabara udaesanak!',
    'ප්‍රීතිමත්, සුවබර උදෑසනක්':
        'Preethimath, suwabara udaesanak',

    // Routine Response Feedback
    'ඔබ තේ පානය කර තිබීම සතුටක්! දැන් ඔබ මුහුණ සෝදා පිරිසිදු වුණාද?':
        'Oba tay paanaya kara thibeema sathutak! Den oba muhuna soadaa pirisidu wunaada?',
    'ඔබ තවම තේ බීලා නැත්නම්, මම රැකබලා ගන්නාට දැන්වුවා ඔබට උණුසුම් තේ එකක් ගෙන එන්න.':
        'Oba thawama tay beelaa nethnam, mama rekabalaagannaata danwuwaa obata unusum tay ekak gena enna.',
    'ඉතා විශිෂ්ටයි! ඔබ ප්‍රබෝධමත්ව අද දවස සතුටින් ගත කිරීමට සූදානම්.':
        'Ithaa vishishtayi! Oba praboadhamathwa ada dawasa sathutin gatha kireemata soodaanam.',
    'අපි මුහුණ සෝදා ප්‍රබෝධමත් වෙමු. ඔබට උදව් අවශ්‍ය නම් රැකබලා ගන්නා දැනුවත් කර ඇත.':
        'Api muhuna soadaa praboadhamath wemu. Obata udaw awashya nam rekabalaagannaa denuwath kara etha.',
    'ඔබ දිවා ආහාරය ගෙන තිබීම සතුටක්! ඔබේ නීරෝගී සුවය අපගේ ප්‍රමුඛතාවයි.':
        'Oba diwa aahaaraya gena thibeema sathutak! Obe neeroagee suwaya apage pramukhathaawayi.',
    'ඔබ තවම දිවා ආහාරය ගෙන නැත්නම්, ඔබට උදව් කිරීමට රැකබලා ගන්නා දැනුවත් කර ඇත.':
        'Oba thawama diwa aahaaraya gena nethnam, obata udaw kireemata rekabalaagannaa denuwath kara etha.',
    'ඉතා විශිෂ්ටයි! කෙටි විවේකයක් ගැනීමෙන් ඔබේ මනසට සහ සිරුරට නව ප්‍රබෝධයක් ලැබේ.':
        'Ithaa vishishtayi! Keti wivekayak geneemen obe manasata saha sirurata nawa praboadhayak lebe.',
    'සුවදායක කෙටි විවේකයක් ලබා ගැනීමට සහායක කණ්ඩායම දැනුවත් කර ඇත.':
        'Suwadaayaka keti wivekayak labaa geneemata sahaayaka kandaayama denuwath kara etha.',
    'සවස උණුසුම් තේ පැන් පානය කර තිබීම සතුටක්!':
        'Sawasa unusum tay pan paanaya kara thibeema sathutak!',
    'ඔබ තවම සවස තේ බීලා නැත්නම්, රැකබලා ගන්නා ඔබ වෙත පැමිණෙනු ඇත.':
        'Oba thawama sawasa tay beelaa nethnam, rekabalaagannaa oba wetha peminenu etha.',
    'නැවුම් සවස සුළං සුවය විඳීම ඔබේ මනස සන්සුන් කරයි!':
        'Newum sawasa sulan suwaya vindeema obe manasa sansun karayi!',
    'සවස නැවුම් සුළං සුවය විඳීමට ඔබට උපකාර කිරීමට රැකබලා ගන්නා පැමිණෙනු ඇත.':
        'Sawasa newum sulan suwaya vindeemata obata upakaara kireemata rekabalaagannaa peminenu etha.',
    'ඉතා විශිෂ්ටයි! රාත්‍රී ආහාර සහ ඖෂධ නියමිත වේලාවට ලබා ගැනීම නීරෝගී බවට ඉතා වැදගත්.':
        'Ithaa vishishtayi! Raathree aahaara saha aushadha niyamitha welaawata labaa geneema neeroagee bawata ithaa wedagath.',
    'ඔබ තවම රාත්‍රී ආහාර හෝ ඖෂධ ගෙන නැත්නම්, ඔබට උදව් කිරීමට රැකබලා ගන්නා දැනුවත් කළා.':
        'Oba thawama raathree aahaara ho aushadha gena nethnam, obata udaw kireemata rekabalaagannaa denuwath kalaa.',
    'සුවබර, සැනසිලිදායක නින්දක් සහ මිහිරි සිහින ඔබට ප්‍රාර්ථනා කරනවා!':
        'Suwabara, senasilidaayaka nindak saha mihiri sihina obata praarthanaa karanawaa!',
    'සුව නින්දකට සූදානම් වීමට ඔබට උපකාර කිරීමට රැකබලා ගන්නා දැනුවත් කර ඇත.':
        'Suwa nindakata soodaanam veemata obata upakaara kireemata rekabalaagannaa denuwath kara etha.',

    // Common Phrases & Sub-Phrases
    'උදේ තේ බිව්වද?': 'Uday tay biwwada?',
    'උදේ තේ බිව්වද': 'Uday tay biwwada',
    'මුහුණ හෝදාගත්තාද?': 'Muhuna hoodaagaththaada?',
    'මුහුණ හෝදාගත්තාද': 'Muhuna hoodaagaththaada',
    'දිවා ආහාරය ගත්තාද?': 'Diwa aahaaraya gaththaada?',
    'දිවා ආහාරය ගත්තාද': 'Diwa aahaaraya gaththaada',
    'කෙටි විවේකයක් ගත්තාද?': 'Keti wivekayak gaththaada?',
    'කෙටි විවේකයක් ගත්තාද': 'Keti wivekayak gaththaada',
    'සවස තේ පැන් පානය කළාද?': 'Sawasa tay pan paanaya kalaada?',
    'සවස තේ පැන් පානය කළාද': 'Sawasa tay pan paanaya kalaada',
    'නැවුම් සුළං සුවය වින්දාද?': 'Newum sulan suwaya vindaada?',
    'නැවුම් සුළං සුවය වින්දාද': 'Newum sulan suwaya vindaada',
    'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද?': 'Raathree aahaara haa aushadha gaththaada?',
    'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද': 'Raathree aahaara haa aushadha gaththaada',
    'සුව නින්දකට සූදානම්ද?': 'Suwa nindakata soodaanamda?',
    'සුව නින්දකට සූදානම්ද': 'Suwa nindakata soodaanamda',

    'කොළ පාට ඔව් ඔබන්න': 'kola paata ov obanna',
    'කොළ පාට බොත්තම ඔබන්න': 'kola paata boththama obanna',
    'කොළ පාට බොත්තම': 'kola paata boththama',
    'බොත්තම ඔබන්න': 'boththama obanna',
    'තවම නැත්නම් තවම නැහැ ඔබන්න': 'thawama nethnam thawama naehe obanna',
    'තවම නැත්නම්': 'thawama nethnam',
    'තවම නැහැ': 'thawama naehe',
    'ඔව්, බිව්වා': 'Ov, biwwa',
    'ඔව්, ගත්තා': 'Ov, gaththa',
    'ඔව්': 'Ov',
    'නැහැ': 'naehe',
    'තේ පැන්': 'tay pan',
    'තේ': 'tay',

    'සුබ උදෑසනක්': 'Suba udaesanak',
    'සුබ දහවල් කාලයක්': 'Suba dahawal kaalayak',
    'සුබ සන්ධ්‍යාවක්': 'Suba sandhyaawak',
    'සුබ රාත්‍රියක්': 'Suba raathriyak',

    'කුමාර මහත්මයා': 'Kumara mahathmaya',
    'කුමාර': 'Kumara',
    'මාලිනී බණ්ඩාර': 'Maalinee Bandara',
    'ආතර් පෙන්ඩ්ල්ටන්': 'Arthur Pendleton',
    'නේවාසික සාමාජිකයා': 'Newaasika Saamaajikaya',
    'නෆියා': 'Nafiya',
  };

  static String _toSinglish(String text) {
    final clean = text.trim();
    if (_knownSinhalaMap.containsKey(clean)) {
      return _knownSinhalaMap[clean]!;
    }

    String result = clean;

    // Sort entries by key length descending so longer sentences/phrases replace before shorter parts
    final sortedEntries = _knownSinhalaMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedEntries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }

    // Check if any Sinhala Unicode characters remain (\u0D80-\u0DFF)
    if (!RegExp(r'[\u0D80-\u0DFF]').hasMatch(result)) {
      return result;
    }

    // Algorithmic phonetic transliteration fallback for any remaining Sinhala letters
    const vowels = {
      'අ': 'a', 'ආ': 'aa', 'ඇ': 'ae', 'ඈ': 'aae', 'ඉ': 'i', 'ඊ': 'ee',
      'උ': 'u', 'ඌ': 'oo', 'ඍ': 'ru', 'ඎ': 'roo', 'එ': 'e', 'ඒ': 'ay',
      'ඓ': 'ai', 'ඔ': 'o', 'ඕ': 'oa', 'ඖ': 'au'
    };
    const consonants = {
      'ක': 'k', 'ඛ': 'kh', 'ග': 'g', 'ඝ': 'gh', 'ඞ': 'ng', 'ඟ': 'ng',
      'ච': 'ch', 'ඡ': 'chh', 'ජ': 'j', 'ඣ': 'jh', 'ඤ': 'ny', 'ඥ': 'gn',
      'ඦ': 'nj', 'ට': 't', 'ඨ': 'th', 'ඩ': 'd', 'ඪ': 'dh', 'ණ': 'n',
      'ඬ': 'nd', 'ත': 'th', 'ථ': 'th', 'ද': 'd', 'ධ': 'dh', 'න': 'n',
      'ඳ': 'nd', 'ප': 'p', 'ඵ': 'ph', 'බ': 'b', 'භ': 'bh', 'ම': 'm',
      'ඹ': 'mb', 'ය': 'y', 'ර': 'r', 'ල': 'l', 'ව': 'w', 'ශ': 'sh',
      'ෂ': 'sh', 'ස': 's', 'හ': 'h', 'ළ': 'l', 'ෆ': 'f'
    };
    const modifiers = {
      '්': '',
      'ා': 'aa', 'ැ': 'ae', 'ෑ': 'aae', 'ි': 'i', 'ී': 'ee',
      'ු': 'u', 'ූ': 'oo', 'ෘ': 'ru', 'ෲ': 'roo', 'ෟ': 'lu',
      'ෙ': 'e', 'ේ': 'ay', 'ෛ': 'ai', 'ො': 'o', 'ෝ': 'oa',
      'ෞ': 'au', 'ං': 'ng', 'ඃ': 'h'
    };

    final buffer = StringBuffer();
    int i = 0;
    final chars = result.split('');
    while (i < chars.length) {
      final ch = chars[i];
      if (vowels.containsKey(ch)) {
        buffer.write(vowels[ch]);
        i++;
      } else if (consonants.containsKey(ch)) {
        final base = consonants[ch]!;
        if (i + 1 < chars.length && modifiers.containsKey(chars[i + 1])) {
          final mod = modifiers[chars[i + 1]]!;
          buffer.write('$base$mod');
          i += 2;
        } else {
          buffer.write('${base}a');
          i++;
        }
      } else {
        buffer.write(ch);
        i++;
      }
    }
    return buffer.toString();
  }

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  void stop() {
    try {
      if (_audio != null) {
        _audio!.pause();
        _audio!.currentTime = 0;
        _audio = null;
      }
      if (html.window.speechSynthesis != null) {
        html.window.speechSynthesis!.cancel();
      }
      _isSpeaking = false;
      onComplete?.call();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  @override
  Future<void> speak(String text, {required bool isSinhala, double rate = 0.45}) async {
    stop();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _isSpeaking = true;

    if (isSinhala) {
      _speakSinhala(trimmed);
    } else {
      _speakEnglish(trimmed, rate: 0.95);
    }
  }

  void _speakSinhala(String text) {
    // 1. Direct match with native studio-recorded Sinhala audio files
    final audioFileName = _matchSinhalaAudioFile(text);
    if (audioFileName != null) {
      _playSinhalaAudio(audioFileName, text);
      return;
    }

    // 2. Browser native Sinhala voice pack check
    if (html.window.speechSynthesis != null) {
      final voices = html.window.speechSynthesis!.getVoices();
      final siVoices = voices.where((v) {
        final lang = v.lang?.toLowerCase() ?? '';
        final name = v.name?.toLowerCase() ?? '';
        return lang.startsWith('si') || lang.contains('si-lk') || name.contains('sinhala') || name.contains('sinhalese');
      }).toList();
      if (siVoices.isNotEmpty) {
        try {
          final utterance = html.SpeechSynthesisUtterance(text);
          utterance.voice = siVoices.first;
          utterance.lang = 'si-LK';
          utterance.rate = 0.88;
          utterance.pitch = 1.02;
          utterance.onEnd.listen((_) {
            _isSpeaking = false;
            onComplete?.call();
          });
          utterance.onError.listen((_) {
            _isSpeaking = false;
            onComplete?.call();
          });
          html.window.speechSynthesis!.speak(utterance);
          return;
        } catch (_) {}
      }
    }

    // 3. Fallback to phonetic transliteration for any custom dynamic elder text
    _speakPhoneticSinhala(text);
  }

  void _playSinhalaAudio(String fileName, String originalText) {
    stop();
    _isSpeaking = true;

    // Flutter web may serve audio from embedded data URI, root 'audio/...' or 'assets/...'
    final embeddedDataUri = cognitiveSinhalaAudioDataUris[fileName];
    final candidatePaths = [
      if (embeddedDataUri != null) embeddedDataUri,
      'audio/sinhala/$fileName',
      'assets/audio/sinhala/$fileName',
      'assets/assets/audio/sinhala/$fileName',
    ];

    int candidateIndex = 0;

    void tryNextCandidate() {
      if (candidateIndex >= candidatePaths.length) {
        debugPrint('All static audio paths exhausted for $fileName. Using phonetic speech.');
        _speakPhoneticSinhala(originalText);
        return;
      }

      final path = candidatePaths[candidateIndex];
      candidateIndex++;

      try {
        final audio = html.AudioElement(path);
        _audio = audio;

        audio.onEnded.listen((_) {
          _isSpeaking = false;
          if (_audio == audio) _audio = null;
          onComplete?.call();
        });

        audio.onError.listen((e) {
          debugPrint('Audio candidate $path failed to load.');
          if (_audio == audio) {
            _audio = null;
            tryNextCandidate();
          }
        });

        audio.play().catchError((e) {
          debugPrint('Playback error on $path: $e');
          if (_audio == audio) {
            _audio = null;
            tryNextCandidate();
          }
        });
      } catch (e) {
        debugPrint('AudioElement exception: $e');
        tryNextCandidate();
      }
    }

    tryNextCandidate();
  }

  void _speakPhoneticSinhala(String text) {
    try {
      if (html.window.speechSynthesis == null) {
        _isSpeaking = false;
        onComplete?.call();
        return;
      }

      final singlish = _toSinglish(text);
      final utterance = html.SpeechSynthesisUtterance(singlish);
      utterance.lang = 'en-US';
      utterance.rate = 0.92; // Natural, clear fluent pace matching memory assessment
      utterance.pitch = 1.0; // Clean natural human pitch without distortion

      final voices = html.window.speechSynthesis!.getVoices();

      // 1. Check for native Sinhala voice
      final siVoices = voices.where((v) {
        final lang = v.lang?.toLowerCase() ?? '';
        final name = v.name?.toLowerCase() ?? '';
        return lang.startsWith('si') || lang.contains('si-lk') || name.contains('sinhala') || name.contains('sinhalese');
      }).toList();

      if (siVoices.isNotEmpty) {
        utterance.voice = siVoices.first;
        utterance.lang = 'si-LK';
      } else {
        // 2. High-quality natural voice matching the memory test (Google US English / Zira / Natural)
        final enVoices = voices.where((v) => (v.lang?.toLowerCase().startsWith('en') ?? false)).toList();
        if (enVoices.isNotEmpty) {
          final googleEn = enVoices.where((v) => (v.name?.toLowerCase().contains('google') ?? false)).toList();
          final naturalEn = enVoices.where((v) {
            final n = v.name?.toLowerCase() ?? '';
            return n.contains('natural') || n.contains('neural') || n.contains('zira');
          }).toList();
          utterance.voice = googleEn.isNotEmpty
              ? googleEn.first
              : (naturalEn.isNotEmpty ? naturalEn.first : enVoices.first);
        }
      }

      utterance.onEnd.listen((_) {
        _isSpeaking = false;
        onComplete?.call();
      });
      utterance.onError.listen((e) {
        _isSpeaking = false;
        onComplete?.call();
        debugPrint('Web Speech synthesis error: $e');
      });

      html.window.speechSynthesis!.speak(utterance);
    } catch (e) {
      _isSpeaking = false;
      onComplete?.call();
      debugPrint('Speech synthesis exception: $e');
    }
  }

  void _speakEnglish(String text, {double rate = 0.95}) {
    try {
      if (html.window.speechSynthesis == null) {
        _isSpeaking = false;
        onComplete?.call();
        return;
      }
      final utterance = html.SpeechSynthesisUtterance(text);
      utterance.lang = 'en-US';
      utterance.rate = rate;

      final voices = html.window.speechSynthesis!.getVoices();
      final enVoices = voices.where((v) => (v.lang?.toLowerCase().startsWith('en') ?? false)).toList();
      if (enVoices.isNotEmpty) {
        final googleEn = enVoices.where((v) => (v.name?.toLowerCase().contains('google') ?? false)).toList();
        utterance.voice = googleEn.isNotEmpty ? googleEn.first : enVoices.first;
      }

      utterance.onEnd.listen((_) {
        _isSpeaking = false;
        onComplete?.call();
      });
      utterance.onError.listen((_) {
        _isSpeaking = false;
        onComplete?.call();
      });
      html.window.speechSynthesis!.speak(utterance);
    } catch (e) {
      _isSpeaking = false;
      onComplete?.call();
    }
  }
}
