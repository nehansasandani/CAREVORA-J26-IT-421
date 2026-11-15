import 'app_language.dart';

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isSinhala => lang == AppLanguage.sinhala;

  // ----------------------------------------------------
  // Navigation / Sidebar
  // ----------------------------------------------------
  String get overview => isSinhala ? 'දළ විශ්ලේෂණය' : 'Overview';
  String get myHealthRecord => isSinhala ? 'මගේ සෞඛ්‍ය වාර්තාව' : 'My Health Record';
  String get residentDirectory => isSinhala ? 'නේවාසික නාමාවලිය' : 'Resident Directory';
  String get cognitiveAssessment => isSinhala ? 'ප්‍රජානන ඇගයීම' : 'Cognitive Assessment';
  String get emotionalWellness => isSinhala ? 'චිත්තවේගීය සුවතාවය' : 'Emotional Wellness';
  String get metabolicHealth => isSinhala ? 'පරිවෘත්තීය සෞඛ්‍යය' : 'Metabolic Health';
  String get reportsAndAnalytics => isSinhala ? 'සෞඛ්‍ය වාර්තා සහ විශ්ලේෂණ' : 'Reports & Analytics';
  String get memoryGames => isSinhala ? 'මතක ක්‍රීඩා' : 'Memory Games';
  String get emotionalWellnessGames => isSinhala ? 'සුවතා ක්‍රීඩා' : 'Emotional Wellness Games';
  String get stationHelpAndCalls => isSinhala ? 'උපකාර සහ ඇමතුම්' : 'Station Help & Calls';
  String get settings => isSinhala ? 'සැකසුම්' : 'Settings';
  String get logOut => isSinhala ? 'ඉවත් වන්න' : 'Log Out';
  String get alertsAndNotifications => isSinhala ? 'දැනුම්දීම්' : 'Alerts & Notifications';
  String get carePlans => isSinhala ? 'සුවතා සැලසුම්' : 'Care Plans';

  // ----------------------------------------------------
  // Top Header
  // ----------------------------------------------------
  String get welcomeBack => isSinhala ? 'නැවත සාදරයෙන් පිළිගනිමු!' : 'Welcome back!';
  String get personalWellnessOverview => isSinhala
      ? 'ඔබේ පෞද්ගලික සුවතා දළ සටහන මෙන්න.'
      : "Here's your personal wellness overview.";
  String get residentsWellnessOverview => isSinhala
      ? 'ඔබේ නේවාසිකයින්ගේ සමස්ත සුවතා දළ සටහන මෙන්න.'
      : "Here's the overall wellness overview of your residents.";

  // ----------------------------------------------------
  // Confidential Health Record (Elder View)
  // ----------------------------------------------------
  String get myConfidentialHealthRecord => isSinhala
      ? 'මගේ රහස්‍ය සෞඛ්‍ය වාර්තාව'
      : 'My Confidential Health Record';

  String loggedInAs(String name) => isSinhala
      ? '$name ලෙස ප්‍රවිෂ්ට වී ඇත. HIPAA සහ රහස්‍යතා ප්‍රමිතීන්ට අනුව වෙනත් නේවාසිකයින්ගේ වාර්තා නැරඹිය නොහැක.'
      : 'Logged in as $name . Under HIPAA and resident privacy standards, you cannot view other elders\' records.';

  String get elderPrivacyActive => isSinhala
      ? 'වැඩිහිටි රහස්‍යතා ප්‍රොටෝකෝලය සක්‍රීයයි'
      : 'Elder Confidential Privacy Protocol Active';

  String get elderPrivacyDesc => isSinhala
      ? 'අනෙකුත් නේවාසිකයින්ගේ සෞඛ්‍ය වාර්තා රහස්‍ය වන අතර ඔබට නොපෙනේ. ඔබට ඔබගේ පෞද්ගලික සෞඛ්‍ය ප්‍රගතියට පමණක් සුවිශේෂී ප්‍රවේශය ඇත.'
      : 'Other resident records are confidential and hidden from view. You have exclusive private access to your own personalized health telemetry and cognitive wellness progress.';

  String room(String r) => isSinhala ? 'කාමරය $r' : 'Room $r';
  String age(int a) => isSinhala ? 'වයස අවුරුදු $a' : 'Age $a';
  String education(int y) => isSinhala ? 'අධ්‍යාපනය: වසර $y' : 'Education: $y Years';
  String get seniorResident => isSinhala ? 'ජ්‍යෙෂ්ඨ නේවාසිකයා' : 'Senior Resident';
  String get female => isSinhala ? 'කාන්තා' : 'Female';
  String get male => isSinhala ? 'පිරිමි' : 'Male';
  String assignedCaregiver(String name) => isSinhala ? 'පැවරුණු ප්‍රධාන භාරකරු: $name' : 'Assigned Primary Caregiver: $name';

  // ----------------------------------------------------
  // Wellness Scores
  // ----------------------------------------------------
  String get yourWellnessTrackingScores => isSinhala ? 'ඔබේ සුවතා ප්‍රගති ලකුණු' : 'Your Wellness Tracking Scores';
  String overallRisk(String risk) => isSinhala ? 'සමස්ත අවදානම: $risk' : 'Overall Risk: $risk';
  String get cognitiveClarity => isSinhala ? 'ප්‍රජානන පැහැදිලි බව' : 'Cognitive Clarity';
  String get emotionalWellnessScore => isSinhala ? 'චිත්තවේගීය සුවතාවය' : 'Emotional Wellness';
  String get metabolicStability => isSinhala ? 'පරිවෘත්තීය ස්ථායිතාව' : 'Metabolic Stability';

  String get notAssessedYet => isSinhala ? 'තවම ඇගයීමට ලක්කර නැත' : 'Not Assessed Yet';
  String get lowRisk => isSinhala ? 'අඩු අවදානම' : 'Low Risk';
  String get moderateRisk => isSinhala ? 'මධ්‍යම අවදානම' : 'Moderate Risk';
  String get highRisk => isSinhala ? 'ඉහළ අවදානම' : 'High Risk';

  // ----------------------------------------------------
  // Assessment Sessions (Emotional / Cognitive)
  // ----------------------------------------------------
  String get aiAssistedLonelinessAssessment => isSinhala
      ? 'හුදකලා බව සහ සමාජීය තනිකම ඇගයීමේ සැසිය'
      : 'AI-Assisted Loneliness & Social-Isolation Assessment Session';

  String get selfResponseSession => isSinhala ? 'ස්වයං-ප්‍රතිචාර සැසිය (ප්‍රශ්න 10)' : 'Self-Response Session (10 items)';
  String get backToHealthRecord => isSinhala ? 'ආපසු මගේ සෞඛ්‍ය වාර්තාවට' : 'Back to My Health Record';
  String questionOf(int current, int total) => isSinhala ? 'ප්‍රශ්න $total න් $current' : 'Question $current of $total';
  String get yes => isSinhala ? 'ඔව්' : 'Yes';
  String get no => isSinhala ? 'නැහැ' : 'No';
  String get tapToReplay => isSinhala ? 'හඬ නැවත ඇසීමට ඔබන්න' : 'Tap to replay';
  String get tapToRecord => isSinhala ? 'කථා කිරීමට ඔබන්න' : 'Tap microphone to record';
  String get stopRecording => isSinhala ? 'පටිගත කිරීම නවත්වන්න' : 'Stop Recording';
  String get realtimeAnalysis => isSinhala ? 'තථ්‍ය කාලීන විශ්ලේෂණය' : 'Real-time Analysis';
  String get facialEmotion => isSinhala ? 'මුහුණේ හැඟීම්' : 'Facial Emotion';
  String get voiceEmotion => isSinhala ? 'හඬේ හැඟීම්' : 'Voice Emotion';
  String get cameraOff => isSinhala ? 'කැමරාව ක්‍රියාවිරහිතයි' : 'Camera Off';
  String get micOff => isSinhala ? 'මයික්‍රෆෝනය ක්‍රියාවිරහිතයි' : 'Mic Off';
  String get speechLanguage => isSinhala ? 'කථා කරන භාෂාව:' : 'Speech Language:';

  // Social & Loneliness Indicators
  String get socialBehaviorIndicators => isSinhala ? 'සමාජීය හැසිරීම් දර්ශක' : 'Social Behavior Indicators';
  String get communicationLevel => isSinhala ? 'සන්නිවේදන මට්ටම' : 'Communication Level';
  String get engagementLevel => isSinhala ? 'සම්බන්ධ වීමේ මට්ටම' : 'Engagement Level';
  String get responseTime => isSinhala ? 'ප්‍රතිචාර කාලය' : 'Response Time';

  String get lonelinessIndicators => isSinhala ? 'හුදකලා බවේ දර්ශක' : 'Loneliness Indicators';
  String get questionnaireDerived => isSinhala ? 'ප්‍රශ්නාවලිය ආශ්‍රිතයි' : 'Questionnaire-Derived';
  String get perceivedLonelinessQ4 => isSinhala ? 'හුදකලා බව දැනීම (Q4)' : 'Perceived Loneliness (Q4)';
  String get roomSeclusionQ5 => isSinhala ? 'කාමරයේ තනිව සිටීම (Q5)' : 'Room Seclusion (Q5)';
  String get socialSupportQ3 => isSinhala ? 'සමාජීය සහයෝගය (Q3)' : 'Social Support (Q3)';
  String get pending => isSinhala ? 'අපේක්ෂිතයි' : 'Pending';

  // Language switch labels
  String get englishLabel => 'English';
  String get sinhalaLabel => 'සිංහල';
  String get switchLanguage => isSinhala ? 'භාෂාව මාරු කරන්න' : 'Switch Language';
}
