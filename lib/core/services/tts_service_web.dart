// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'tts_service.dart';

TtsService createTtsService() => WebTtsService();

class WebTtsService implements TtsService {
  html.AudioElement? _audio;
  bool _isSpeaking = false;

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
  };

  static String? _matchSinhalaAudioFile(String rawText) {
    final text = rawText.trim();
    if (_sinhalaAudioFiles.containsKey(text)) {
      return _sinhalaAudioFiles[text];
    }

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
    if (text.contains('සත්කාරක නිලධාරියාට') || text.contains('හදිසි දැනුම්දීමක්')) return 'caregiver_alert.mp3';
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
  };

  static String _toSinglish(String text) {
    final clean = text.trim();
    if (_knownSinhalaMap.containsKey(clean)) {
      return _knownSinhalaMap[clean]!;
    }

    for (final entry in _knownSinhalaMap.entries) {
      if (clean.contains(entry.key)) {
        return clean.replaceAll(entry.key, entry.value);
      }
    }

    // Algorithmic phonetic transliteration fallback
    const vowels = {
      'අ': 'a', 'ආ': 'aa', 'ඇ': 'ae', 'ඈ': 'aae', 'ඉ': 'i', 'ඊ': 'ee',
      'උ': 'u', 'ඌ': 'oo', 'ඍ': 'ru', 'ඎ': 'roo', 'එ': 'e', 'ඒ': 'ee',
      'ඓ': 'ai', 'ඔ': 'o', 'ඕ': 'oo', 'ඖ': 'au'
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
      'ෙ': 'e', 'ේ': 'ee', 'ෛ': 'ai', 'ො': 'o', 'ෝ': 'oo',
      'ෞ': 'au', 'ං': 'ng', 'ඃ': 'h'
    };

    final buffer = StringBuffer();
    int i = 0;
    final chars = text.split('');
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
      final siVoices = voices.where((v) => (v.lang?.toLowerCase().startsWith('si') ?? false)).toList();
      if (siVoices.isNotEmpty) {
        try {
          final utterance = html.SpeechSynthesisUtterance(text);
          utterance.voice = siVoices.first;
          utterance.lang = 'si-LK';
          utterance.rate = 0.82;
          utterance.onEnd.listen((_) => _isSpeaking = false);
          utterance.onError.listen((_) => _isSpeaking = false);
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

    // Flutter web may serve audio from root 'audio/...' or from 'assets/...'
    final candidatePaths = [
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
        return;
      }

      final singlish = _toSinglish(text);
      final utterance = html.SpeechSynthesisUtterance(singlish);
      utterance.rate = 0.84; // Gentle, clear pacing for elder comprehension
      utterance.pitch = 1.0;
      utterance.lang = 'en-US';

      final voices = html.window.speechSynthesis!.getVoices();
      final inVoices = voices.where((v) =>
        (v.lang?.toLowerCase().contains('in') ?? false) ||
        (v.lang?.toLowerCase().contains('hi') ?? false)
      ).toList();

      if (inVoices.isNotEmpty) {
        utterance.voice = inVoices.first;
      } else {
        final enVoices = voices.where((v) => (v.lang?.toLowerCase().startsWith('en') ?? false)).toList();
        if (enVoices.isNotEmpty) {
          final googleVoice = enVoices.where((v) => (v.name?.toLowerCase().contains('google') ?? false)).toList();
          utterance.voice = googleVoice.isNotEmpty ? googleVoice.first : enVoices.first;
        }
      }

      utterance.onEnd.listen((_) {
        _isSpeaking = false;
      });
      utterance.onError.listen((e) {
        _isSpeaking = false;
        debugPrint('Web Speech synthesis error: $e');
      });

      html.window.speechSynthesis!.speak(utterance);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('Speech synthesis exception: $e');
    }
  }

  void _speakEnglish(String text, {double rate = 0.95}) {
    try {
      if (html.window.speechSynthesis == null) {
        _isSpeaking = false;
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
      });
      utterance.onError.listen((_) {
        _isSpeaking = false;
      });
      html.window.speechSynthesis!.speak(utterance);
    } catch (e) {
      _isSpeaking = false;
    }
  }
}
