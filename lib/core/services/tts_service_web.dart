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
      if (text.contains(entry.key) || entry.key.contains(text)) {
        return entry.value;
      }
    }

    // Keyword heuristics for robust matching even with emojis, minor punctuation differences
    if (text.contains('අද දවසේ') && text.contains('සතුටක්')) return 'q1.mp3';
    if (text.contains('ඉදිරි දින') && text.contains('බලාපොරොත්තු')) {
      if (text.contains('සුබවාදී') || text.contains('ප්‍රීතිමත්')) return 'praise_q2.mp3';
      return 'q2.mp3';
    }
    if (text.contains('සමීපව කතාබහ කිරීමට කෙනෙකු') || text.contains('අදහස් බෙදා ගැනීමට කෙනෙකු')) {
      if (text.contains('භාග්‍යයක්')) return 'praise_q3.mp3';
      return 'q3.mp3';
    }
    if (text.contains('අන් අය එකතු වී සිටින විට')) {
      if (text.contains('ආදරයෙන්')) return 'praise_q4.mp3';
      return 'q4.mp3';
    }
    if (text.contains('කාමරය තුළ තනිවම')) {
      if (text.contains('වෙහෙසකර')) return 'comfort_q5.mp3';
      return 'q5.mp3';
    }
    if (text.contains('කාමරයට පමණක් සීමා නොවී')) return 'praise_q5.mp3';
    if (text.contains('බැලීමට පැමිණෙන') || text.contains('දුරකථනයෙන් කතා කරන')) return 'q6.mp3';
    if (text.contains('උදෑසන තේ පැන්') || text.contains('ව්‍යායාම') || text.contains('උත්සව සඳහා')) return 'q7.mp3';
    if (text.contains('තවත් කෙනෙකු සිටී නම්')) return 'q8.mp3';
    if (text.contains('කරදර හෝ ගැටලු') && text.contains('රැකවරණ')) return 'q9.mp3';
    if (text.contains('සුහද සන්නිවේදනය ඉතා අගනේය')) return 'praise_q9.mp3';
    if (text.contains('සන්සුන් සංගීතයකට') || text.contains('පිරිත්') || text.contains('ගාථා')) return 'q10.mp3';

    if (text.contains('ගොඩක් ඒ ගැන ස්තූතියි') || text.contains('සහනයෙන් පසුවීම')) return 'praise_q1.mp3';
    if (text.contains('එසේ සිතන්න එපා')) return 'comfort_q4.mp3';
    if (text.contains('සිත දුකට පත් කරගන්න එපා')) return 'comfort_q2.mp3';
    if (text.contains('අමරදේවයන්ගේ') || text.contains('නන්දා මාලිනියන්ගේ')) return 'comfort_q6.mp3';
    if (text.contains('තනි වී නැහැ') || text.contains('ළඟින්ම සිටිනවා')) return 'comfort_q3.mp3';
    if (text.contains('ඇසීම කනගාටුදායකයි') || text.contains('මේ ආකාරයට දැනෙන්නට හේතුව')) return 'comfort_general.mp3';
    if (text.contains('ඖෂධ ලබා ගත්තාද')) return 'unwell.mp3';
    if (text.contains('නිදහසේ ඉන්න') || text.contains('සිත සන්සුන් කරගැනීමට මිහිරි')) return 'quiet.mp3';
    if (text.contains('රැකබලා ගන්නා දැනුවත් කරන ලදී') || text.contains('සත්කාරක නිලධාරියාට') || text.contains('හදිසි දැනුම්දීමක්')) return 'caregiver_alert.mp3';
    if (text.contains('පොත් කියවීමේ')) return 'book_intro.mp3';
    if (text.contains('සංගීත චිකිත්සාව වෙත')) return 'music_intro.mp3';

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
    'සුබ උදෑසනක්, කුමාර! ඔබ උදෑසන තේ පානය කළාද?':
        'Sooba oodaasanak, Koomara! Oba oodaasana they paanaya kalaadha?',
    'සුබ උදෑසනක්, කුමාර මහත්මයා! ඔබ උදෑසන තේ පානය කළාද?':
        'Sooba oodaasanak, Koomara mahathmaya! Oba oodaasana they paanaya kalaadha?',
    'සුබ දහවල් කාලයක්, කුමාර! ඔබ දිවා ආහාරය ගත්තාද?':
        'Sooba dahawal kaalayak, Koomara! Oba diwa aahaaraya gaththaadha?',
    'සුබ දහවල් කාලයක්, කුමාර මහත්මයා! ඔබ දිවා ආහාරය ගත්තාද?':
        'Sooba dahawal kaalayak, Koomara mahathmaya! Oba diwa aahaaraya gaththaadha?',
    'සුබ සන්ධ්‍යාවක්, කුමාර! ඔබ සවස තේ පැන් පානය කළාද?':
        'Sooba sandhyaawak, Koomara! Oba sawasa they pean paanaya kalaadha?',
    'සුබ සන්ධ්‍යාවක්, කුමාර මහත්මයා! ඔබ සවස තේ පැන් පානය කළාද?':
        'Sooba sandhyaawak, Koomara mahathmaya! Oba sawasa they pean paanaya kalaadha?',
    'සුබ රාත්‍රියක්, කුමාර! ඔබ රාත්‍රී ආහාරය හා ඖෂධ ලබා ගත්තාද?':
        'Sooba raathriyak, Koomara! Oba raathree aahaaraya haa owshadha labaa gaththaadha?',
    'සුබ රාත්‍රියක්, කුමාර මහත්මයා! ඔබ රාත්‍රී ආහාරය හා ඖෂධ ලබා ගත්තාද?':
        'Sooba raathriyak, Koomara mahathmaya! Oba raathree aahaaraya haa owshadha labaa gaththaadha?',

    // Routine Cards - Card 1 Prompts
    'උදේ තේ බිව්වද? සුවබර උදෑසනකට උණුසුම් තේ පැන් පානය කළා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Ooday they beewwada? Soowabara oodaasanakata oonusum they pean paanaya kalaa nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',
    'දිවා ආහාරය ගත්තාද? පෝෂ්‍යදායී දිවා ආහාරය ගත්තා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Diwa aahaaraya gaththaadha? Poashyadhaayee diwa aahaaraya gaththaa nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',
    'සවස තේ පැන් පානය කළාද? උණුසුම් තේ පැන් බිව්වා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Sawasa they pean paanaya kalaadha? Oonusum they pean beewwa nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',
    'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද? නියමිත ආහාර හා ඖෂධ ලබා ගත්තා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Raathree aahaara haa owshadha gaththaadha? Niyamitha aahaara haa owshadha labaa gaththaa nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',

    // Routine Cards - Card 2 Prompts
    'මුහුණ හෝදාගත්තාද? ප්‍රබෝධමත් දවසකට මුහුණ සෝදා පිරිසිදු වුණා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Moohuna hoodaagaththaadha? Praboadhamath dawasakata moohuna soadaa pirisidhu woonaa nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',
    'කෙටි විවේකයක් ගත්තාද? සුවදායක කෙටි විවේකයක් ලබා ගත්තා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Keti wivekayak gaththaadha? Soowadhaayaka keti wivekayak labaa gaththaa nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',
    'නැවුම් සුළං සුවය වින්දාද? සවස නැවුම් සුළඟ වින්දා නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Newum sulan suwaya vindhaadha? Sawasa newum sulanga vindhaa nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',
    'සුව නින්දකට සූදානම්ද? සැනසිලිදායක නින්දකට සූදානම් නම් කොළ පාට බොත්තම ඔබන්න. තවම නැත්නම් තවම නැහැ බොත්තම ඔබන්න.':
        'Soowa nindhakata soodhaanandha? Senasilidhaayaka nindhakata soodhaanam nam kola paata boththama obanna. Thawama nethnam thawama nehe boththama obanna.',

    // Center Robot Speech Bubble
    'අද උදයේ මූලික පුරුදු කටයුතු කරගත්තාද?':
        'Ada oodaye moolika purudhu katayuthu karagaththaadha?',
    'අද උදයේ\nමූලික පුරුදු\nකරගත්තාද? 💜':
        'Ada oodaye moolika purudhu katayuthu karagaththaadha?',
    'අද දහවල් සුවපහසු විවේකය ලබාගත්තාද?':
        'Ada dahawal soowapahasu wivekaya labaagaththaadha?',
    'අද දහවල්\nසුවපහසු විවේකය\nලබාගත්තාද? 💜':
        'Ada dahawal soowapahasu wivekaya labaagaththaadha?',
    'අද සවස නැවුම් සුවය වින්දාද?':
        'Ada sawasa newum suwaya vindhaadha?',
    'අද සවස\nනැවුම් සුවය\nවින්දාද? 💜':
        'Ada sawasa newum suwaya vindhaadha?',
    'අද රාත්‍රී සුව නින්දකට සූදානම්ද?':
        'Ada raathree soowa nindhakata soodhaanandha?',
    'අද රාත්‍රී\nසුව නින්දකට\nසූදානම්ද? 💜':
        'Ada raathree soowa nindhakata soodhaanandha?',

    // Care Notice Pill
    'රැකබලා ගන්නා දැනුවත් කරන ලදී: ඔබට අවශ්‍ය සහාය ලබා දීමට සහායක කණ්ඩායම පැමිණෙනු ඇත.':
        'Rekabala gannaa denuwath karana ladee: obata awashya sahaaya labaa deemata sahaayaka kandayama peminenawa.',
    'තවම කරගෙන නැත්නම්, අපේ සත්කාර කණ්ඩායම ඔබට මිතුරු වෙමින් උදව් කිරීමට දැනුම් දෙනවා.':
        'Thawama karagena nethnam, aape sathkaara kandayama obata mithuru wemin udaw kireemata denum denawa.',
    'තවම කරගෙන නැත්නම්, අපේ සත්කාර කණ්ඩායම ඔබට මිතුරු වෙමින් දැනුම් දෙනවා.':
        'Thawama karagena nethnam, aape sathkaara kandayama obata mithuru wemin denum denawa.',

    // Left Greeting Audio Pill
    'ඔබ ගැන අදත් හොඳින් සලකමු!':
        'Oba gena adath hondhin salakamu!',
    'ඔබ ගැන අදත් හොඳින් සලකමු':
        'Oba gena adath hondhin salakamu',
    'අදත් සුවපහසු, සතුටුදායක දිනයක් එක්ව ආරම්භ කරමු!':
        'Adath soowapahasu, sathutudaayaka dinayak ekwa aarambha karamu!',
    'අදත් සුවපහසු, සතුටුදායක දිනයක් එක්ව ආරම්භ කරමු':
        'Adath soowapahasu, sathutudaayaka dinayak ekwa aarambha karamu',
    'ප්‍රීතිමත්, සුවබර උදෑසනක්!':
        'Preethimath, soowabara oodaasanak!',
    'ප්‍රීතිමත්, සුවබර උදෑසනක්':
        'Preethimath, soowabara oodaasanak',

    // Routine Response Feedback
    'ඔබ තේ පානය කර තිබීම සතුටක්! දැන් ඔබ මුහුණ සෝදා පිරිසිදු වුණාද?':
        'Oba they paanaya kara thibeema sathutak! Den oba moohuna soadaa pirisidhu woonaadha?',
    'ඔබ තවම තේ බීලා නැත්නම්, මම රැකබලා ගන්නාට දැන්වුවා ඔබට උණුසුම් තේ එකක් ගෙන එන්න.':
        'Oba thawama they beelaa nethnam, mama rekabala gannaata denwoowa obata oonusum they ekak gena enna.',
    'ඉතා විශිෂ්ටයි! ඔබ ප්‍රබෝධමත්ව අද දවස සතුටින් ගත කිරීමට සූදානම්.':
        'Itha vishishtayi! Oba praboadhamathwa ada dawasa sathutin gatha kireemata soodhanam.',
    'අපි මුහුණ සෝදා ප්‍රබෝධමත් වෙමු. ඔබට උදව් අවශ්‍ය නම් රැකබලා ගන්නා දැනුවත් කර ඇත.':
        'Api moohuna soadaa praboadhamath wemu. Obata udaw awashya nam rekabala gannaa denuwath kara etha.',
    'ඔබ දිවා ආහාරය ගෙන තිබීම සතුටක්! ඔබේ නීරෝගී සුවය අපගේ ප්‍රමුඛතාවයි.':
        'Oba diwa aahaaraya gena thibeema sathutak! Obe neerogee suwaya aepage pramukhathaawayi.',
    'ඔබ තවම දිවා ආහාරය ගෙන නැත්නම්, ඔබට උදව් කිරීමට රැකබලා ගන්නා දැනුවත් කර ඇත.':
        'Oba thawama diwa aahaaraya gena nethnam, obata udaw kireemata rekabala gannaa denuwath kara etha.',
    'ඉතා විශිෂ්ටයි! කෙටි විවේකයක් ගැනීමෙන් ඔබේ මනසට සහ සිරුරට නව ප්‍රබෝධයක් ලැබේ.':
        'Itha vishishtayi! Keti wivekayak geneemen obe manasata saha sirurata nawa praboadhayak lebe.',
    'සුවදායක කෙටි විවේකයක් ලබා ගැනීමට සහායක කණ්ඩායම දැනුවත් කර ඇත.':
        'Soowadhaayaka keti wivekayak labaa geneemata sahaayaka kandayama denuwath kara etha.',
    'සවස උණුසුම් තේ පැන් පානය කර තිබීම සතුටක්!':
        'Sawasa oonusum they pean paanaya kara thibeema sathutak!',
    'ඔබ තවම සවස තේ බීලා නැත්නම්, රැකබලා ගන්නා ඔබ වෙත පැමිණෙනු ඇත.':
        'Oba thawama sawasa they beelaa nethnam, rekabala gannaa oba wetha peminenu etha.',
    'නැවුම් සවස සුළං සුවය විඳීම ඔබේ මනස සන්සුන් කරයි!':
        'Newum sawasa sulan suwaya windeema obe manasa sansun karayi!',
    'සවස නැවුම් සුළං සුවය විඳීමට ඔබට උපකාර කිරීමට රැකබලා ගන්නා පැමිණෙනු ඇත.':
        'Sawasa newum sulan suwaya windeemata obata oopakaara kireemata rekabala gannaa peminenu etha.',
    'ඉතා විශිෂ්ටයි! රාත්‍රී ආහාර සහ ඖෂධ නියමිත වේලාවට ලබා ගැනීම නීරෝගී බවට ඉතා වැදගත්.':
        'Itha vishishtayi! Raathree aahaara saha owshadha niyamitha welaawata labaa geneema neerogee bawata itha wedagath.',
    'ඔබ තවම රාත්‍රී ආහාර හෝ ඖෂධ ගෙන නැත්නම්, ඔබට උදව් කිරීමට රැකබලා ගන්නා දැනුවත් කළා.':
        'Oba thawama raathree aahaara ho owshadha gena nethnam, obata udaw kireemata rekabala gannaa denuwath kalaa.',
    'සුවබර, සැනසිලිදායක නින්දක් සහ මිහිරි සිහින ඔබට ප්‍රාර්ථනා කරනවා!':
        'Soowabara, senasilidhaayaka nindak saha mihiri sihina obata praarthanaa karanawa!',
    'සුව නින්දකට සූදානම් වීමට ඔබට උපකාර කිරීමට රැකබලා ගන්නා දැනුවත් කර ඇත.':
        'Soowa nindhakata soodhanam weemata obata oopakaara kireemata rekabala gannaa denuwath kara etha.',

    // Common Phrases & Sub-Phrases
    'උදේ තේ බිව්වද?': 'Ooday they beewwada?',
    'උදේ තේ බිව්වද': 'Ooday they beewwada',
    'මුහුණ හෝදාගත්තාද?': 'Moohuna hoodaagaththaadha?',
    'මුහුණ හෝදාගත්තාද': 'Moohuna hoodaagaththaadha',
    'දිවා ආහාරය ගත්තාද?': 'Diwa aahaaraya gaththaadha?',
    'දිවා ආහාරය ගත්තාද': 'Diwa aahaaraya gaththaadha',
    'කෙටි විවේකයක් ගත්තාද?': 'Keti wivekayak gaththaadha?',
    'කෙටි විවේකයක් ගත්තාද': 'Keti wivekayak gaththaadha',
    'සවස තේ පැන් පානය කළාද?': 'Sawasa they pean paanaya kalaadha?',
    'සවස තේ පැන් පානය කළාද': 'Sawasa they pean paanaya kalaadha',
    'නැවුම් සුළං සුවය වින්දාද?': 'Newum sulan suwaya vindhaadha?',
    'නැවුම් සුළං සුවය වින්දාද': 'Newum sulan suwaya vindhaadha',
    'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද?': 'Raathree aahaara haa owshadha gaththaadha?',
    'රාත්‍රී ආහාර හා ඖෂධ ගත්තාද': 'Raathree aahaara haa owshadha gaththaadha',
    'සුව නින්දකට සූදානම්ද?': 'Soowa nindhakata soodhaanandha?',
    'සුව නින්දකට සූදානම්ද': 'Soowa nindhakata soodhaanandha',

    'කොළ පාට බොත්තම ඔබන්න': 'kola paata boththama obanna',
    'කොළ පාට බොත්තම': 'kola paata boththama',
    'බොත්තම ඔබන්න': 'boththama obanna',
    'තවම නැත්නම්': 'thawama nethnam',
    'තවම නැහැ': 'thawama nehe',
    'ඔව්, බිව්වා': 'Ow, beewwa',
    'ඔව්, ගත්තා': 'Ow, gaththa',
    'ඔව්': 'Ow',

    'සුබ උදෑසනක්': 'Sooba oodaasanak',
    'සුබ දහවල් කාලයක්': 'Sooba dahawal kaalayak',
    'සුබ සන්ධ්‍යාවක්': 'Sooba sandhyaawak',
    'සුබ රාත්‍රියක්': 'Sooba raathriyak',

    'කුමාර මහත්මයා': 'Koomara mahathmaya',
    'කුමාර': 'Koomara',
    'මාලිනී බණ්ඩාර': 'Maalinee Bandara',
    'ආතර් පෙන්ඩ්ල්ටන්': 'Arthur Pendleton',
    'නේවාසික සාමාජිකයා': 'Newaasika Saamaajikaya',
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
      'උ': 'oo', 'ඌ': 'oo', 'ඍ': 'ru', 'ඎ': 'roo', 'එ': 'e', 'ඒ': 'ay',
      'ඓ': 'ai', 'ඔ': 'o', 'ඕ': 'oa', 'ඖ': 'ow'
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
      'ු': 'oo', 'ූ': 'oo', 'ෘ': 'ru', 'ෲ': 'roo', 'ෟ': 'lu',
      'ෙ': 'e', 'ේ': 'ay', 'ෛ': 'ai', 'ො': 'o', 'ෝ': 'oa',
      'ෞ': 'ow', 'ං': 'ng', 'ඃ': 'h'
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
        final name = v.name.toLowerCase();
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
      utterance.rate = 0.88; // Natural, clear conversational pacing for elder
      utterance.pitch = 1.02; // Warm, polite, human pitch

      final voices = html.window.speechSynthesis!.getVoices();

      // 1. Check for native Sinhala voice
      final siVoices = voices.where((v) {
        final lang = v.lang?.toLowerCase() ?? '';
        final name = v.name.toLowerCase();
        return lang.startsWith('si') || lang.contains('si-lk') || name.contains('sinhala') || name.contains('sinhalese');
      }).toList();

      if (siVoices.isNotEmpty) {
        utterance.voice = siVoices.first;
        utterance.lang = 'si-LK';
      } else {
        // 2. High-quality South Asian / Indian English voices
        final inVoices = voices.where((v) {
          final lang = v.lang?.toLowerCase() ?? '';
          final name = v.name.toLowerCase();
          return lang.contains('en-in') || lang.contains('hi') || name.contains('india') ||
                 name.contains('neerja') || name.contains('prabhat') || name.contains('heera') ||
                 name.contains('ravi') || name.contains('kalpana') || name.contains('veena') ||
                 name.contains('swara') || name.contains('madhur');
        }).toList();

        if (inVoices.isNotEmpty) {
          utterance.voice = inVoices.first;
          utterance.lang = inVoices.first.lang ?? 'en-IN';
        } else {
          utterance.lang = 'en-US';
          final enVoices = voices.where((v) => (v.lang?.toLowerCase().startsWith('en') ?? false)).toList();
          if (enVoices.isNotEmpty) {
            // Prioritize natural / neural / google / zira (friendly warm voice) over robotic david
            final preferredEn = enVoices.where((v) {
              final n = v.name.toLowerCase();
              return n.contains('natural') || n.contains('neural') || n.contains('google') || n.contains('zira');
            }).toList();
            utterance.voice = preferredEn.isNotEmpty ? preferredEn.first : enVoices.first;
          }
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
