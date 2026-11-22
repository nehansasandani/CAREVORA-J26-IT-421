class SinhalaNameTransliterator {
  SinhalaNameTransliterator._();

  static final RegExp _sinhalaCharRegex = RegExp(r'[\u0D80-\u0DFF]');
  static final RegExp _initialsGroupRegex = RegExp(r'^([A-Za-z]\.)+$');
  static final RegExp _singleInitialRegex = RegExp(r'^[A-Za-z]\.?$');

  static const Map<String, String> _initialMap = {
    'a': 'ඒ.',
    'b': 'බී.',
    'c': 'සී.',
    'd': 'ඩී.',
    'e': 'ඊ.',
    'f': 'එෆ්.',
    'g': 'ජී.',
    'h': 'එච්.',
    'i': 'අයි.',
    'j': 'ජේ.',
    'k': 'කේ.',
    'l': 'එල්.',
    'm': 'එම්.',
    'n': 'එන්.',
    'o': 'ඕ.',
    'p': 'පී.',
    'q': 'කිව්.',
    'r': 'ආර්.',
    's': 'එස්.',
    't': 'ටී.',
    'u': 'යූ.',
    'v': 'වී.',
    'w': 'ඩබ්ලිව්.',
    'x': 'එක්ස්.',
    'y': 'වයි.',
    'z': 'සෙඩ්.',
  };

  static const Map<String, String> _knownWords = {
    // Titles
    'mr.': '',
    'mr': '',
    'mrs.': '',
    'mrs': '',
    'ms.': '',
    'ms': '',
    'miss': '',
    'dr.': 'වෛද්‍ය',
    'dr': 'වෛද්‍ය',
    'prof.': 'මහාචාර්ය',
    'prof': 'මහාචාර්ය',

    // Common Sri Lankan female names
    'padmini': 'පද්මිනී',
    'padma': 'පද්මා',
    'padmawathi': 'පද්මාවතී',
    'malini': 'මාලිනී',
    'seetha': 'සීතා',
    'sita': 'සීතා',
    'nanda': 'නන්දා',
    'kusuma': 'කුසුමා',
    'kusum': 'කුසුම්',
    'kusumawathi': 'කුසුමාවතී',
    'soma': 'සෝමා',
    'somawathi': 'සෝමාවතී',
    'amara': 'අමරා',
    'amarawathi': 'අමරාවතී',
    'kamala': 'කමලා',
    'kamalawathi': 'කමලාවතී',
    'chandra': 'චන්ද්‍රා',
    'chandani': 'චන්දනී',
    'chandrani': 'චන්ද්‍රානි',
    'chandrika': 'චන්ද්‍රිකා',
    'ranjani': 'රංජනී',
    'shirani': 'ශිරාණි',
    'shanthi': 'ශාන්ති',
    'shanthini': 'ශාන්තිනී',
    'swarna': 'ස්වර්ණා',
    'swarnalatha': 'ස්වර්ණලතා',
    'indrani': 'ඉන්ද්‍රානි',
    'kanthi': 'කාන්ති',
    'leela': 'ලීලා',
    'leelawathi': 'ලීලාවතී',
    'lilawathi': 'ලීලාවතී',
    'daya': 'දයා',
    'dayawathi': 'දයාවතී',
    'karunawathi': 'කරුණාවතී',
    'gunawathi': 'ගුණවතී',
    'prema': 'ප්‍රේමා',
    'premawathi': 'ප්‍රේමාවතී',
    'ratnawathi': 'රත්නාවතී',
    'rathnawathi': 'රත්නාවතී',
    'podimenike': 'පොඩිමැණිකේ',
    'menike': 'මැණිකේ',
    'kumari': 'කුමාරි',
    'kumarihamy': 'කුමාරිහාමි',
    'sujatha': 'සුජාතා',
    'nirmala': 'නිර්මලා',
    'pushpa': 'පුෂ්පා',
    'priyanka': 'ප්‍රියංකා',
    'priyani': 'ප්‍රියානි',
    'priyanthi': 'ප්‍රියන්ති',
    'priya': 'ප්‍රියා',
    'deepa': 'දීපා',
    'deepani': 'දීපානි',
    'deepika': 'දීපිකා',
    'nilmini': 'නිල්මිණී',
    'sandya': 'සන්ධ්‍යා',
    'sandhya': 'සන්ධ්‍යා',
    'dilani': 'දිලානි',
    'dilhani': 'දිල්හානි',
    'nadeesha': 'නදීෂා',
    'nadeeka': 'නදීකා',
    'madhavi': 'මාධවී',
    'madhushani': 'මධුෂානි',
    'madushani': 'මධුෂානි',
    'anoma': 'අනෝමා',
    'anula': 'අනුලා',
    'renuka': 'රේණුකා',
    'chamila': 'චමිලා',
    'chamari': 'චමරි',
    'thilini': 'තිළිණි',
    'sanduni': 'සඳුනි',
    'oshadi': 'ඔෂදී',
    'hansani': 'හංසනී',
    'ishara': 'ඉෂාරා',
    'kavindi': 'කවින්දි',
    'hashini': 'හෂිනි',
    'hiruni': 'හිරුණි',
    'sachini': 'සචිනි',
    'gayani': 'ගයානි',
    'gayathri': 'ගයාත්‍රි',
    'manel': 'මානෙල්',
    'malkanthi': 'මල්කාන්ති',
    'mallika': 'මල්ලිකා',
    'wimala': 'විමලා',
    'wimalawathi': 'විමලාවතී',
    'sriyani': 'ශ්‍රියානි',
    'sriyakanthi': 'ශ්‍රියාකාන්ති',
    'vineetha': 'විනීතා',
    'sumana': 'සුමනා',
    'sumanawathi': 'සුමනාවතී',
    'ramya': 'රම්‍යා',
    'ramani': 'රමණී',
    'roshani': 'රොෂානි',
    'roshini': 'රොෂිනි',
    'lakshmi': 'ලක්ෂ්මී',
    'lakmali': 'ලක්මාලි',
    'wasana': 'වාසනා',
    'yasawathi': 'යසවතී',
    'hemawathi': 'හේමාවතී',
    'hema': 'හේමා',
    'damayanthi': 'දමයන්ති',
    'disna': 'දිස්නා',
    'fathima': 'ෆාතිමා',
    'ayesha': 'ආයිෂා',
    'zainab': 'සයිනබ්',
    'devi': 'දේවී',
    'kavitha': 'කවිතා',
    'meena': 'මීනා',
    'kalyani': 'කල්‍යාණි',
    'samanthi': 'සමන්ති',
    'samanmali': 'සමන්මලී',
    'nuwani': 'නුවනි',
    'chathurika': 'චතුරිකා',
    'pasidi': 'පසිඳි',
    'sarangi': 'සාරංගි',
    'nirosha': 'නිරෝෂා',
    'dinusha': 'දිනුෂා',
    'amaya': 'අමායා',
    'imasha': 'ඉමාෂා',
    'kaveesha': 'කවීෂා',
    'malsha': 'මල්ෂා',
    'hasini': 'හසිනි',
    'nethmi': 'නෙත්මි',
    'piyumi': 'පියුමි',
    'upeksha': 'උපේක්ෂා',
    'geetha': 'ගීතා',
    'gita': 'ගීතා',
    'sangeetha': 'සංගීතා',
    'irangani': 'ඉරංගනී',
    'lalani': 'ලාළනී',
    'nalini': 'නලිනී',
    'rohini': 'රෝහිණී',
    'rupawathi': 'රූපාවතී',
    'siriyawathi': 'සිරියාවතී',
    'subashini': 'සුභාෂිනී',
    'subhashini': 'සුභාෂිනී',
    'tharushi': 'තරුෂි',
    'chamodi': 'චමෝදි',

    // Common Sri Lankan male names
    'bandara': 'බණ්ඩාර',
    'indika': 'ඉන්දික',
    'kumara': 'කුමාර',
    'kamal': 'කමල්',
    'nimal': 'නිමල්',
    'sunil': 'සුනිල්',
    'siripala': 'සිරිපාල',
    'sirisena': 'සිරිසේන',
    'senarath': 'සෙනරත්',
    'saman': 'සමන්',
    'ranjith': 'රංජිත්',
    'ranjit': 'රංජිත්',
    'ananda': 'ආනන්ද',
    'upali': 'උපාලි',
    'lalith': 'ලලිත්',
    'lalit': 'ලලිත්',
    'lal': 'ලාල්',
    'nihal': 'නිහාල්',
    'mahinda': 'මහින්ද',
    'sarath': 'සරත්',
    'sarat': 'සරත්',
    'gamini': 'ගාමිණී',
    'rohan': 'රොහාන්',
    'rohana': 'රෝහණ',
    'ajith': 'අජිත්',
    'ajit': 'අජිත්',
    'asoka': 'අශෝක',
    'ashoka': 'අශෝක',
    'priyantha': 'ප්‍රියන්ත',
    'pradeep': 'ප්‍රදීප්',
    'prasanna': 'ප්‍රසන්න',
    'prasad': 'ප්‍රසාද්',
    'chaminda': 'චමින්ද',
    'chinthaka': 'චින්තක',
    'chathura': 'චතුර',
    'chandana': 'චන්දන',
    'charith': 'චරිත්',
    'kasun': 'කසුන්',
    'ruwan': 'රුවන්',
    'gayan': 'ගයාන්',
    'nuwan': 'නුවන්',
    'dilshan': 'දිල්ෂාන්',
    'tharindu': 'තරිඳු',
    'kavindu': 'කවිඳු',
    'ravindu': 'රවිඳු',
    'dinesh': 'දිනේෂ්',
    'mahesh': 'මහේෂ්',
    'suresh': 'සුරේෂ්',
    'ramesh': 'රමේෂ්',
    'rajesh': 'රාජේෂ්',
    'janaka': 'ජනක',
    'jayantha': 'ජයන්ත',
    'jagath': 'ජගත්',
    'sanjeewa': 'සංජීව',
    'sanjaya': 'සංජය',
    'sampath': 'සම්පත්',
    'sujeewa': 'සුජීව',
    'sudeera': 'සුදීර',
    'supun': 'සුපුන්',
    'isuru': 'ඉසුරු',
    'lahiru': 'ළහිරු',
    'shehan': 'ශෙහාන්',
    'nilantha': 'නිලන්ත',
    'nishantha': 'නිශාන්ත',
    'wijitha': 'විජිත',
    'wimal': 'විමල්',
    'wimalasena': 'විමලසේන',
    'gunasena': 'ගුණසේන',
    'gunapala': 'ගුණපාල',
    'somapala': 'සෝමපාල',
    'somasiri': 'සෝමසිරි',
    'ariyapala': 'ආරියපාල',
    'ariyasena': 'ආරියසේන',
    'ariyadasa': 'ආරියදාස',
    'dayaratne': 'දයාරත්න',
    'ratnasiri': 'රත්නසිරි',
    'piyadasa': 'පියදාස',
    'piyasena': 'පියසේන',
    'premadasa': 'ප්‍රේමදාස',
    'premasiri': 'ප්‍රේමසිරි',
    'karunadasa': 'කරුණාදාස',
    'karunasena': 'කරුණාසේන',
    'darmadasa': 'ධර්මදාස',
    'dharmadasa': 'ධර්මදාස',
    'dharmasena': 'ධර්මසේන',
    'dharmasiri': 'ධර්මසිරි',
    'dhammika': 'ධම්මික',
    'tilak': 'තිලක්',
    'thilak': 'තිලක්',
    'tissa': 'තිස්ස',
    'bandula': 'බන්දුල',
    'hemantha': 'හේමන්ත',
    'kapila': 'කපිල',
    'keerti': 'කීර්ති',
    'keerthi': 'කීර්ති',
    'kithsiri': 'කිත්සිරි',
    'manjula': 'මංජුල',
    'palitha': 'පාලිත',
    'parakrama': 'පරාක්‍රම',
    'ravindra': 'රවීන්ද්‍ර',
    'ravi': 'රවී',
    'sena': 'සේන',
    'sisira': 'සිසිර',
    'sudath': 'සුදත්',
    'sumanasiri': 'සුමනසිරි',
    'sumanadasa': 'සුමනදාස',
    'udaya': 'උදය',
    'vasantha': 'වසන්ත',
    'wasantha': 'වසන්ත',
    'weerasena': 'වීරසේන',
    'yasapala': 'යසපාල',
    'buddhika': 'බුද්ධික',
    'eranga': 'එරංග',
    'tharanga': 'තරංග',
    'niroshan': 'නිරෝෂන්',
    'prabath': 'ප්‍රභාත්',
    'gihan': 'ගිහාන්',
    'heshan': 'හෙෂාන්',
    'mohamed': 'මොහොමඩ්',
    'mohammed': 'මොහොමඩ්',
    'ahamed': 'අහමඩ්',
    'farook': 'ෆාරූක්',
    'kumar': 'කුමාර්',
    'rajan': 'රාජන්',
    'selvam': 'සෙල්වම්',

    // Common Sri Lankan surnames
    'perera': 'පෙරේරා',
    'silva': 'සිල්වා',
    'desilva': 'ද සිල්වා',
    'fernando': 'ප්‍රනාන්දු',
    'de': 'ද',
    'jayasinghe': 'ජයසිංහ',
    'jayawardena': 'ජයවර්ධන',
    'jayawardana': 'ජයවර්ධන',
    'jayasekara': 'ජයසේකර',
    'jayasuriya': 'ජයසූරිය',
    'jayasooriya': 'ජයසූරිය',
    'jayathilake': 'ජයතිලක',
    'jayathilaka': 'ජයතිලක',
    'jayakody': 'ජයකොඩි',
    'jayalath': 'ජයලත්',
    'jayaweera': 'ජයවීර',
    'dissanayake': 'දිසානායක',
    'dissanayaka': 'දිසානායක',
    'gunasekara': 'ගුණසේකර',
    'goonasekara': 'ගුණසේකර',
    'gunawardena': 'ගුණවර්ධන',
    'gunawardana': 'ගුණවර්ධන',
    'goonewardena': 'ගුණවර්ධන',
    'gunathilake': 'ගුණතිලක',
    'gunathilaka': 'ගුණතිලක',
    'rathnayake': 'රත්නායක',
    'ratnayake': 'රත්නායක',
    'rathnayaka': 'රත්නායක',
    'ratnayaka': 'රත්නායක',
    'wickramasinghe': 'වික්‍රමසිංහ',
    'wickremasinghe': 'වික්‍රමසිංහ',
    'wickramasekara': 'වික්‍රමසේකර',
    'wickramaratne': 'වික්‍රමරත්න',
    'herath': 'හේරත්',
    'eka': 'ඒක',
    'ekanayake': 'ඒකනායක',
    'ekanayaka': 'ඒකනායක',
    'rajapaksa': 'රාජපක්ෂ',
    'rajapaksha': 'රාජපක්ෂ',
    'rajapakse': 'රාජපක්ෂ',
    'gamage': 'ගමගේ',
    'liyana': 'ලියන',
    'liyanage': 'ලියනගේ',
    'peiris': 'පීරිස්',
    'pieris': 'පීරිස්',
    'fonseka': 'ෆොන්සේකා',
    'wijesinghe': 'විජේසිංහ',
    'wijayasinghe': 'විජයසිංහ',
    'wijesekara': 'විජේසේකර',
    'wijewardena': 'විජේවර්ධන',
    'wijeratne': 'විජේරත්න',
    'wijerathne': 'විජේරත්න',
    'wijesuriya': 'විජේසූරිය',
    'wijekoon': 'විජේකෝන්',
    'wijesundara': 'විජේසුන්දර',
    'wijetunga': 'විජේතුංග',
    'karunaratne': 'කරුණාරත්න',
    'karunarathne': 'කරුණාරත්න',
    'karunaratna': 'කරුණාරත්න',
    'karunanayake': 'කරුණානායක',
    'karunasekara': 'කරුණාසේකර',
    'samaraweera': 'සමරවීර',
    'samarasinghe': 'සමරසිංහ',
    'samarasekara': 'සමරසේකර',
    'samarakoon': 'සමරකෝන්',
    'samaranayake': 'සමරනායක',
    'weerasekara': 'වීරසේකර',
    'weerasinghe': 'වීරසිංහ',
    'weeraratne': 'වීරරත්න',
    'weerarathne': 'වීරරත්න',
    'weerakoon': 'වීරකෝන්',
    'weerasuriya': 'වීරසූරිය',
    'weerawardena': 'වීරවර්ධන',
    'pathirana': 'පතිරණ',
    'ranasinghe': 'රණසිංහ',
    'ranatunga': 'රණතුංග',
    'ranathunga': 'රණතුංග',
    'ranaweera': 'රණවීර',
    'amarasinghe': 'අමරසිංහ',
    'amarasekara': 'අමරසේකර',
    'amaraweera': 'අමරවීර',
    'abeysekara': 'අබේසේකර',
    'abeysinghe': 'අබේසිංහ',
    'abeywardena': 'අබේවර්ධන',
    'abeywickrama': 'අබේවික්‍රම',
    'alwis': 'අල්විස්',
    'athukorala': 'අතුකෝරළ',
    'balasuriya': 'බාලසූරිය',
    'chandrasekara': 'චන්ද්‍රසේකර',
    'cooray': 'කුරේ',
    'costa': 'කොස්තා',
    'dahanayake': 'දහනායක',
    'dias': 'ඩයස්',
    'edirisinghe': 'එදිරිසිංහ',
    'hettiarachchi': 'හෙට්ටිආරච්චි',
    'kannangara': 'කන්නන්ගර',
    'kariyawasam': 'කාරියවසම්',
    'kodikara': 'කොඩිකාර',
    'kodituwakku': 'කොඩිතුවක්කු',
    'kulasekara': 'කුලසේකර',
    'kulasinghe': 'කුලසිංහ',
    'kulathunga': 'කුලතුංග',
    'kularatne': 'කුලරත්න',
    'kuruppu': 'කුරුප්පු',
    'lokuge': 'ලොකුගේ',
    'marasinghe': 'මාරසිංහ',
    'mendis': 'මෙන්ඩිස්',
    'munasinghe': 'මුණසිංහ',
    'nanayakkara': 'නානායක්කාර',
    'navaratne': 'නවරත්න',
    'nawarathna': 'නවරත්න',
    'nissanka': 'නිශ්ශංක',
    'pinto': 'පින්තෝ',
    'premaratne': 'ප්‍රේමරත්න',
    'rodrigo': 'රොද්‍රිගු',
    'senanayake': 'සේනානායක',
    'senarathne': 'සෙනරත්න',
    'seneviratne': 'සෙනෙවිරත්න',
    'senevirathne': 'සෙනෙවිරත්න',
    'siriwardena': 'සිරිවර්ධන',
    'siriwardana': 'සිරිවර්ධන',
    'soysa': 'සොයිසා',
    'subasinghe': 'සුබසිංහ',
    'thilakaratne': 'තිලකරත්න',
    'vithanage': 'විතානගේ',
    'withanage': 'විතානගේ',
    'withana': 'විතාන',
    'wanigasekara': 'වනිගසේකර',
    'wanigasinghe': 'වනිගසිංහ',
    'warnakulasuriya': 'වර්ණකුලසූරිය',
    'wimalaratne': 'විමලරත්න',
    'yapa': 'යාපා',

    // Common English / Western names
    'sarah': 'සාරා',
    'jenkins': 'ජෙන්කින්ස්',
    'arthur': 'ආතර්',
    'pendelton': 'පෙන්ඩල්ටන්',
    'margaret': 'මාගරට්',
    'chen': 'චෙන්',
    'robert': 'රොබට්',
    'hastings': 'හේස්ටින්ග්ස්',
    'david': 'ඩේවිඩ්',
    'eleanor': 'එලිනෝර්',
    'vance': 'වෑන්ස්',
    'samantha': 'සමන්තා',
    'reed': 'රීඩ්',
    'james': 'ජේම්ස්',
    'peter': 'පීටර්',
    'martin': 'මාටින්',
    'victor': 'වික්ටර්',
    'anton': 'ඇන්ටන්',
    'anthony': 'ඇන්තනි',
    'milton': 'මිල්ටන්',
    'stanley': 'ස්ටැන්ලි',
    'patrick': 'පැට්‍රික්',
    'richard': 'රිචඩ්',
    'edward': 'එඩ්වඩ්',
    'daniel': 'ඩැනියෙල්',
    'john': 'ජෝන්',
    'michael': 'මයිකල්',
    'george': 'ජෝර්ජ්',
    'william': 'විලියම්',
    'charles': 'චාල්ස්',
    'henry': 'හෙන්රි',
    'mary': 'මේරි',
    'anne': 'ඈන්',
    'ann': 'ඈන්',
    'helen': 'හෙලන්',
    'grace': 'ග්‍රේස්',
    'shane': 'ශේන්',
    'kevin': 'කෙවින්',
  };

  /// Common Sri Lankan surname/name suffixes for accurate compound transliteration.
  static const Map<String, String> _compoundSuffixes = {
    'singhe': 'සිංහ',
    'singha': 'සිංහ',
    'wardena': 'වර්ධන',
    'wardana': 'වර්ධන',
    'sekara': 'සේකර',
    'sekera': 'සේකර',
    'nayake': 'නායක',
    'nayaka': 'නායක',
    'rathne': 'රත්න',
    'ratne': 'රත්න',
    'rathna': 'රත්න',
    'ratna': 'රත්න',
    'thilake': 'තිලක',
    'thilaka': 'තිලක',
    'tilake': 'තිලක',
    'tilaka': 'තිලක',
    'sooriya': 'සූරිය',
    'suriya': 'සූරිය',
    'arachchi': 'ආරච්චි',
    'menike': 'මැණිකේ',
    'wathi': 'වතී',
    'kumari': 'කුමාරි',
    'kumara': 'කුමාර',
  };

  static String toSinhala(String name, {String fallback = 'කුමාර'}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return fallback;

    final parts = trimmed.split(RegExp(r'\s+'));
    final converted = <String>[];
    for (final part in parts) {
      final result = _convertToken(part);
      if (result.isNotEmpty) {
        converted.add(result);
      }
    }
    return converted.isEmpty ? trimmed : converted.join(' ');
  }

  static String _convertToken(String token) {
    if (token.isEmpty) return '';
    if (_sinhalaCharRegex.hasMatch(token)) return token;

    // Handle hyphenated names (e.g. Alwis-Perera)
    if (token.contains('-')) {
      return token
          .split('-')
          .map(_convertToken)
          .where((e) => e.isNotEmpty)
          .join('-');
    }

    final lower = token.toLowerCase();

    // Exact match including titles (e.g. "dr.", "mr.")
    if (_knownWords.containsKey(lower)) {
      return _knownWords[lower]!;
    }

    // Grouped initials like "W.A." or "R.M."
    if (_initialsGroupRegex.hasMatch(token)) {
      final letters = lower.split('.').where((s) => s.isNotEmpty);
      return letters.map((ch) => _initialMap[ch] ?? '$ch.').join(' ');
    }

    // Single initial like "K" or "K."
    if (_singleInitialRegex.hasMatch(token)) {
      final ch = lower.replaceAll('.', '');
      return _initialMap[ch] ?? token;
    }

    // Separate leading/trailing punctuation
    final match = RegExp(r'^([^A-Za-z]*)([A-Za-z]+)([^A-Za-z]*)$').firstMatch(token);
    if (match == null) return token;

    final prefix = match.group(1) ?? '';
    final word = match.group(2)!.toLowerCase();
    final suffix = match.group(3) ?? '';

    if (_knownWords.containsKey(word)) {
      final mapped = _knownWords[word]!;
      return mapped.isEmpty ? '' : '$prefix$mapped$suffix';
    }

    final transliterated = _transliterateWord(word);
    return '$prefix$transliterated$suffix';
  }

  static String _transliterateWord(String word) {
    if (word.isEmpty) return '';

    // Check known Sri Lankan compound suffixes when there is a meaningful stem
    for (final entry in _compoundSuffixes.entries) {
      if (word.length > entry.key.length + 1 && word.endsWith(entry.key)) {
        final stem = word.substring(0, word.length - entry.key.length);
        final stemSi = _knownWords[stem] ?? _phoneticTransliterate(stem);
        return '$stemSi${entry.value}';
      }
    }

    return _phoneticTransliterate(word);
  }

  static bool _isVowelChar(String ch) =>
      ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u';

  static String _phoneticTransliterate(String word) {
    final buf = StringBuffer();
    int i = 0;
    final n = word.length;

    while (i < n) {
      // Independent vowel
      if (_isVowelChar(word[i])) {
        final v = _matchIndependentVowel(word, i);
        buf.write(v.sinhala);
        i += v.consumed;
        // Skip silent trailing 'h' after a vowel (e.g. Sarah, Hannah)
        if (i == n - 1 && word[i] == 'h') {
          i++;
        }
        continue;
      }

      // Special nasal clusters: ng / nk / nj
      if (word[i] == 'n' && i + 1 < n) {
        final next = word[i + 1];
        if (next == 'g') {
          if (i + 2 < n && word[i + 2] == 'h') {
            buf.write('ං');
            i += 2; // consume 'ng', let 'h' be processed next
            continue;
          }
          if (i + 2 == n) {
            buf.write('ං');
            i += 2;
            continue;
          }
          if (i + 2 < n && _isVowelChar(word[i + 2])) {
            buf.write('ංග');
            i += 2;
            final dep = _matchDependentVowel(word, i);
            buf.write(dep.sinhala);
            i += dep.consumed;
            continue;
          }
        } else if ((next == 'k' || next == 'j') && i + 2 < n) {
          buf.write('ං');
          i += 1; // consume 'n' as anusvara, process 'k'/'j' next
          continue;
        }
      }

      // Match consonant (longest first)
      final c = _matchConsonant(word, i);
      if (c.consumed == 0) {
        buf.write(word[i]);
        i++;
        continue;
      }

      String consonantStr = c.sinhala;
      i += c.consumed;

      // Rakaranshaya: consonant + 'r' + vowel (excluding 'r' itself)
      if (i + 1 < n &&
          word[i] == 'r' &&
          c.raw != 'r' &&
          _isVowelChar(word[i + 1])) {
        consonantStr = '$consonantStr\u0DCA\u200D\u0DBB';
        i += 1;
      }
      // Yansaya: consonant + 'y' + vowel (excluding 'y' and 'r')
      else if (i + 1 < n &&
          word[i] == 'y' &&
          c.raw != 'y' &&
          c.raw != 'r' &&
          _isVowelChar(word[i + 1])) {
        consonantStr = '$consonantStr\u0DCA\u200D\u0DBA';
        i += 1;
      }

      // Check following vowel
      if (i < n && _isVowelChar(word[i])) {
        final dep = _matchDependentVowel(word, i);
        buf.write(consonantStr);
        buf.write(dep.sinhala);
        i += dep.consumed;
        // Skip silent trailing 'h' after a vowel
        if (i == n - 1 && word[i] == 'h') {
          i++;
        }
      } else if (i == n - 1 && word[i] == 'y' && c.raw != 'y') {
        // Word-final 'y' after consonant acts as 'i' (e.g. Mary, Lucy, Kody)
        buf.write(consonantStr);
        buf.write('ි');
        i += 1;
      } else {
        // No following vowel -> add hal kirima
        buf.write(consonantStr);
        buf.write('\u0DCA');
      }
    }

    return buf.toString();
  }

  static _Match _matchConsonant(String s, int i) {
    final rem = s.length - i;
    if (rem >= 3) {
      final tri = s.substring(i, i + 3);
      if (tri == 'ksh') return const _Match('ක්ෂ', 3, 'ksh');
    }
    if (rem >= 2) {
      final di = s.substring(i, i + 2);
      switch (di) {
        case 'ch':
          return const _Match('ච', 2, 'ch');
        case 'sh':
          return const _Match('ශ', 2, 'sh');
        case 'th':
          return const _Match('ත', 2, 'th');
        case 'dh':
          return const _Match('ධ', 2, 'dh');
        case 'bh':
          return const _Match('භ', 2, 'bh');
        case 'ph':
          return const _Match('ෆ', 2, 'ph');
        case 'kh':
          return const _Match('ඛ', 2, 'kh');
        case 'gh':
          return const _Match('ඝ', 2, 'gh');
        case 'jh':
          return const _Match('ඣ', 2, 'jh');
        case 'gn':
          return const _Match('ඥ', 2, 'gn');
        case 'ck':
          return const _Match('ක', 2, 'ck');
        case 'wh':
          return const _Match('ව', 2, 'wh');
      }
    }

    final ch = s[i];
    switch (ch) {
      case 'k':
      case 'q':
        return _Match('ක', 1, ch);
      case 'g':
        return const _Match('ග', 1, 'g');
      case 'c':
        final next = i + 1 < s.length ? s[i + 1] : '';
        if (next == 'e' || next == 'i' || next == 'y') {
          return const _Match('ස', 1, 'c');
        }
        return const _Match('ක', 1, 'c');
      case 'j':
        return const _Match('ජ', 1, 'j');
      case 't':
        return const _Match('ට', 1, 't');
      case 'd':
        return const _Match('ද', 1, 'd');
      case 'n':
        return const _Match('න', 1, 'n');
      case 'p':
        return const _Match('ප', 1, 'p');
      case 'f':
        return const _Match('ෆ', 1, 'f');
      case 'b':
        return const _Match('බ', 1, 'b');
      case 'm':
        return const _Match('ම', 1, 'm');
      case 'y':
        return const _Match('ය', 1, 'y');
      case 'r':
        return const _Match('ර', 1, 'r');
      case 'l':
        return const _Match('ල', 1, 'l');
      case 'v':
      case 'w':
        return _Match('ව', 1, ch);
      case 's':
      case 'z':
        return _Match('ස', 1, ch);
      case 'h':
        return const _Match('හ', 1, 'h');
      case 'x':
        return const _Match('ක්ස', 1, 'x');
      default:
        return const _Match('', 0, '');
    }
  }

  static _Match _matchIndependentVowel(String s, int i) {
    if (i + 1 < s.length) {
      final di = s.substring(i, i + 2);
      switch (di) {
        case 'aa':
          return const _Match('ආ', 2, 'aa');
        case 'ae':
          return const _Match('ඇ', 2, 'ae');
        case 'ai':
          return const _Match('අයි', 2, 'ai');
        case 'au':
          return const _Match('අවු', 2, 'au');
        case 'ee':
        case 'ii':
        case 'ea':
          return _Match('ඊ', 2, di);
        case 'oo':
        case 'uu':
          return _Match('ඌ', 2, di);
      }
    }
    switch (s[i]) {
      case 'a':
        return const _Match('අ', 1, 'a');
      case 'e':
        return const _Match('එ', 1, 'e');
      case 'i':
        return const _Match('ඉ', 1, 'i');
      case 'o':
        return const _Match('ඔ', 1, 'o');
      case 'u':
        return const _Match('උ', 1, 'u');
      default:
        return const _Match('', 0, '');
    }
  }

  static _Match _matchDependentVowel(String s, int i) {
    if (i + 1 < s.length) {
      final di = s.substring(i, i + 2);
      switch (di) {
        case 'aa':
          return const _Match('ා', 2, 'aa');
        case 'ae':
          return const _Match('ැ', 2, 'ae');
        case 'ai':
          return const _Match('යි', 2, 'ai');
        case 'au':
          return const _Match('වු', 2, 'au');
        case 'ee':
        case 'ii':
        case 'ea':
          return _Match('ී', 2, di);
        case 'oo':
        case 'uu':
          return _Match('ූ', 2, di);
      }
    }
    switch (s[i]) {
      case 'a':
        return const _Match('', 1, 'a'); // inherent vowel
      case 'e':
        return const _Match('ෙ', 1, 'e');
      case 'i':
        return const _Match('ි', 1, 'i');
      case 'o':
        return const _Match('ො', 1, 'o');
      case 'u':
        return const _Match('ු', 1, 'u');
      default:
        return const _Match('', 0, '');
    }
  }
}

class _Match {
  final String sinhala;
  final int consumed;
  final String raw;

  const _Match(this.sinhala, this.consumed, this.raw);
}
