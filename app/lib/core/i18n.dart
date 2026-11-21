import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

/// App language for the citizen surfaces, the sign-in screen and the map home.
/// Officer and corporator panels stay in English (PRD).
const Map<String, String> appLanguages = {'en': 'English', 'hi': 'हिंदी', 'mr': 'मराठी'};

class LangNotifier extends Notifier<String> {
  @override
  String build() => ref.read(prefsProvider).getString('lang') ?? 'en';
  void set(String lang) {
    state = lang;
    ref.read(prefsProvider).setString('lang', lang);
  }
}

final langProvider = NotifierProvider<LangNotifier, String>(LangNotifier.new);

/// Put above the navigator (MaterialApp.builder) so every route, sheet and dialog sees it.
class LangScope extends InheritedWidget {
  const LangScope({super.key, required this.lang, required super.child});
  final String lang;
  @override
  bool updateShouldNotify(LangScope old) => old.lang != lang;
}

extension Tr on BuildContext {
  /// Current language; widgets that call this rebuild when it changes.
  String get lang => dependOnInheritedWidgetOfExactType<LangScope>()?.lang ?? 'en';

  /// [en] translated, with `{name}` filled from [args]. The English text is the key, so a
  /// missing translation shows English, never a key.
  String tr(String en, [Map<String, Object?> args = const {}]) {
    var s = _strings[en]?[lang] ?? en;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }
}

// English -> {hi, mr}. Plain words; rupee figures stay in lakh / crore numerals.
const Map<String, Map<String, String>> _strings = {
  // Map home
  'Wards': {'hi': 'वार्ड', 'mr': 'वॉर्ड'},
  'Roads': {'hi': 'सड़कें', 'mr': 'रस्ते'},
  'Next rupee': {'hi': 'अगला रुपया', 'mr': 'पुढचा रुपया'},
  'Complaints': {'hi': 'शिकायतें', 'mr': 'तक्रारी'},
  '{amount} billed on roads under warranty — to be claimed and verified': {
    'hi': 'वारंटी वाली सड़कों पर {amount} का भुगतान हुआ — वसूली और जांच बाकी है',
    'mr': 'वॉरंटीतील रस्त्यांवर {amount} दिले गेले — वसुली आणि पडताळणी बाकी आहे',
  },
  '{n} jobs across Mumbai · tap to see wards': {
    'hi': 'पूरी मुंबई में {n} काम · वार्ड देखने के लिए टैप करें',
    'mr': 'संपूर्ण मुंबईत {n} कामे · वॉर्ड पाहण्यासाठी टॅप करा',
  },
  'Report or track a problem': {'hi': 'समस्या बताएं या स्थिति देखें', 'mr': 'समस्या नोंदवा किंवा स्थिती पाहा'},
  'Play the 2025 monsoon': {'hi': '2025 का मानसून चलाएं', 'mr': '2025 चा पावसाळा पाहा'},
  'Synthetic data. Not BMC data. Contractors are fictional.': {
    'hi': 'कृत्रिम डेटा। यह BMC का डेटा नहीं है। ठेकेदार काल्पनिक हैं।',
    'mr': 'कृत्रिम डेटा. हा BMC चा डेटा नाही. कंत्राटदार काल्पनिक आहेत.',
  },
  'Language': {'hi': 'भाषा', 'mr': 'भाषा'},
  'About this data': {'hi': 'इस डेटा के बारे में', 'mr': 'या डेटाबद्दल'},

  // Sign-in and roles
  'Sign in': {'hi': 'साइन इन करें', 'mr': 'साइन इन करा'},
  'Sign in with your mobile number': {'hi': 'अपने मोबाइल नंबर से साइन इन करें', 'mr': 'तुमच्या मोबाइल नंबरने साइन इन करा'},
  'The map stays open to everyone. Sign in to file a complaint or draft a notice. This demo uses a fixed code instead of an SMS.': {
    'hi': 'नक्शा सभी के लिए खुला है। शिकायत दर्ज करने या नोटिस बनाने के लिए साइन इन करें। इस डेमो में SMS की जगह एक तय कोड है।',
    'mr': 'नकाशा सर्वांसाठी खुला आहे. तक्रार नोंदवण्यासाठी किंवा नोटीस तयार करण्यासाठी साइन इन करा. या डेमोमध्ये SMS ऐवजी एक ठरलेला कोड आहे.',
  },
  'Mobile number': {'hi': 'मोबाइल नंबर', 'mr': 'मोबाइल नंबर'},
  '10 digits': {'hi': '10 अंक', 'mr': '10 अंक'},
  'Code': {'hi': 'कोड', 'mr': 'कोड'},
  'Signing in…': {'hi': 'साइन इन हो रहा है…', 'mr': 'साइन इन होत आहे…'},
  'Demo shortcuts (fill the fields)': {'hi': 'डेमो शॉर्टकट (फ़ील्ड भर देते हैं)', 'mr': 'डेमो शॉर्टकट (माहिती भरली जाते)'},
  'Citizen': {'hi': 'नागरिक', 'mr': 'नागरिक'},
  'Corporator': {'hi': 'पार्षद', 'mr': 'नगरसेवक'},
  'Ward officer': {'hi': 'वार्ड अधिकारी', 'mr': 'वॉर्ड अधिकारी'},
  'Switch account…': {'hi': 'खाता बदलें…', 'mr': 'खाते बदला…'},
  'Sign in with a number…': {'hi': 'नंबर से साइन इन करें…', 'mr': 'नंबरने साइन इन करा…'},
  'Sign out': {'hi': 'साइन आउट', 'mr': 'साइन आउट'},
  'That code is not right. Check it and try again.': {
    'hi': 'कोड सही नहीं है। जांचकर फिर से कोशिश करें।',
    'mr': 'कोड बरोबर नाही. तपासून पुन्हा प्रयत्न करा.',
  },
  'Enter a 10-digit mobile number': {'hi': '10 अंकों का मोबाइल नंबर डालें', 'mr': '10 अंकी मोबाइल नंबर टाका'},
  'Enter the code': {'hi': 'कोड डालें', 'mr': 'कोड टाका'},
  'Please sign in': {'hi': 'कृपया साइन इन करें', 'mr': 'कृपया साइन इन करा'},
  'Not available for your role': {'hi': 'आपकी भूमिका के लिए उपलब्ध नहीं', 'mr': 'तुमच्या भूमिकेसाठी उपलब्ध नाही'},
  'Not now': {'hi': 'अभी नहीं', 'mr': 'आत्ता नाही'},
  'Switch account': {'hi': 'खाता बदलें', 'mr': 'खाते बदला'},
  'Sign in with your mobile number to file a complaint, so you can track it later.': {
    'hi': 'शिकायत दर्ज करने के लिए अपने मोबाइल नंबर से साइन इन करें, ताकि आप बाद में उसकी स्थिति देख सकें।',
    'mr': 'तक्रार नोंदवण्यासाठी तुमच्या मोबाइल नंबरने साइन इन करा, म्हणजे नंतर तिची स्थिती पाहता येईल.',
  },
  'Sign in to file a complaint.': {'hi': 'शिकायत दर्ज करने के लिए साइन इन करें।', 'mr': 'तक्रार नोंदवण्यासाठी साइन इन करा.'},

  // Citizen hub
  'For citizens': {'hi': 'नागरिकों के लिए', 'mr': 'नागरिकांसाठी'},
  'Report a problem': {'hi': 'समस्या बताएं', 'mr': 'समस्या नोंदवा'},
  'In your own words. See if neighbours already raised it.': {
    'hi': 'अपने शब्दों में लिखें। देखें कि पड़ोसियों ने पहले ही शिकायत की है या नहीं।',
    'mr': 'तुमच्या शब्दांत लिहा. शेजाऱ्यांनी आधीच तक्रार केली आहे का ते पाहा.',
  },
  'Track a complaint': {'hi': 'शिकायत की स्थिति देखें', 'mr': 'तक्रारीची स्थिती पाहा'},
  'By complaint id or by locality.': {'hi': 'शिकायत नंबर या इलाके से।', 'mr': 'तक्रार क्रमांक किंवा परिसरानुसार.'},
  "My ward's report card": {'hi': 'मेरे वार्ड का रिपोर्ट कार्ड', 'mr': 'माझ्या वॉर्डचे रिपोर्ट कार्ड'},
  'A shareable card of your ward’s road repairs.': {
    'hi': 'आपके वार्ड की सड़क मरम्मत का कार्ड, जिसे आप शेयर कर सकते हैं।',
    'mr': 'तुमच्या वॉर्डमधील रस्ते दुरुस्तीचे कार्ड, जे तुम्ही शेअर करू शकता.',
  },
  'Ask my ward': {'hi': 'मेरे वार्ड से पूछें', 'mr': 'माझ्या वॉर्डला विचारा'},
  'A polite question to the ward office, with the figures.': {
    'hi': 'आंकड़ों के साथ वार्ड ऑफिस से एक विनम्र सवाल।',
    'mr': 'आकडेवारीसह वॉर्ड कार्यालयाला एक नम्र प्रश्न.',
  },

  // Report a problem
  'Your complaint': {'hi': 'आपकी शिकायत', 'mr': 'तुमची तक्रार'},
  'Describe the problem in your own words — English, हिंदी, मराठी': {
    'hi': 'अपने शब्दों में समस्या बताएं — English, हिंदी, मराठी',
    'mr': 'तुमच्या शब्दांत समस्या सांगा — English, हिंदी, मराठी',
  },
  'Try an example': {'hi': 'एक उदाहरण आज़माएं', 'mr': 'एखादे उदाहरण वापरून पाहा'},
  'Understand': {'hi': 'समझें', 'mr': 'समजून घ्या'},
  'Understanding…': {'hi': 'समझ रहे हैं…', 'mr': 'समजून घेत आहे…'},
  'Retry': {'hi': 'फिर से कोशिश करें', 'mr': 'पुन्हा प्रयत्न करा'},
  'Dismiss': {'hi': 'हटाएं', 'mr': 'बंद करा'},
  'What we understood': {'hi': 'हमने क्या समझा', 'mr': 'आम्हाला काय समजले'},
  'Understood by Claude': {'hi': 'Claude ने समझा', 'mr': 'Claude ने समजून घेतले'},
  'Understood on device rules (keyword match, no AI)': {
    'hi': 'तय नियमों से समझा (शब्द मिलान, AI नहीं)',
    'mr': 'ठरलेल्या नियमांनी समजले (शब्द जुळवणी, AI नाही)',
  },
  'Category': {'hi': 'श्रेणी', 'mr': 'प्रकार'},
  'Locality (type to search)': {'hi': 'इलाका (खोजने के लिए लिखें)', 'mr': 'परिसर (शोधण्यासाठी टाइप करा)'},
  'We could not find the place in your text. Please pick your locality.': {
    'hi': 'आपके संदेश में जगह नहीं मिली। कृपया अपना इलाका चुनें।',
    'mr': 'तुमच्या मजकुरात ठिकाण सापडले नाही. कृपया तुमचा परिसर निवडा.',
  },
  'Not reported here yet': {'hi': 'यहां अभी तक किसी ने शिकायत नहीं की', 'mr': 'इथे अजून कोणी तक्रार केलेली नाही'},
  'Already reported: 1 neighbour raised this': {
    'hi': 'पहले से दर्ज: 1 पड़ोसी ने यह शिकायत की है',
    'mr': 'आधीच नोंदवले: 1 शेजाऱ्याने ही तक्रार केली आहे',
  },
  'Already reported: {n} neighbours raised this': {
    'hi': 'पहले से दर्ज: {n} पड़ोसियों ने यह शिकायत की है',
    'mr': 'आधीच नोंदवले: {n} शेजाऱ्यांनी ही तक्रार केली आहे',
  },
  'No one has reported this in {loc} in the last 14 days of the data.': {
    'hi': 'डेटा के आखिरी 14 दिनों में {loc} में किसी ने यह शिकायत नहीं की।',
    'mr': 'डेटाच्या शेवटच्या 14 दिवसांत {loc} मध्ये कोणीही ही तक्रार केलेली नाही.',
  },
  'Showing the latest {shown} of {n}.': {'hi': 'कुल {n} में से नई {shown} दिखाई गई हैं।', 'mr': 'एकूण {n} पैकी नवीन {shown} दाखवल्या आहेत.'},
  'Complaints filed in this app could not be checked right now.': {
    'hi': 'इस ऐप में दर्ज शिकायतें अभी जांची नहीं जा सकीं।',
    'mr': 'या ॲपमध्ये नोंदवलेल्या तक्रारी आत्ता तपासता आल्या नाहीत.',
  },
  'Filed as {id}': {'hi': '{id} नंबर से दर्ज हुई', 'mr': '{id} क्रमांकाने नोंदवली'},
  'A new complaint in {loc}.': {'hi': '{loc} में नई शिकायत।', 'mr': '{loc} मध्ये नवीन तक्रार.'},
  'Your voice is added to {id}.': {'hi': 'आपकी आवाज़ {id} में जोड़ दी गई है।', 'mr': 'तुमचा आवाज {id} मध्ये जोडला आहे.'},
  'Track': {'hi': 'स्थिति देखें', 'mr': 'स्थिती पाहा'},
  'Add my voice': {'hi': 'मेरी आवाज़ जोड़ें', 'mr': 'माझा आवाज जोडा'},
  'File as new': {'hi': 'नई शिकायत दर्ज करें', 'mr': 'नवीन तक्रार नोंदवा'},
  'Filed in this app': {'hi': 'इस ऐप में दर्ज', 'mr': 'या ॲपमध्ये नोंदवली'},
  'Not yet fixed — no work order linked': {
    'hi': 'अभी तक ठीक नहीं हुआ — कोई वर्क ऑर्डर नहीं जुड़ा',
    'mr': 'अजून दुरुस्ती नाही — कोणतीही वर्क ऑर्डर जोडलेली नाही',
  },
  'Forwarded to another agency (MMRDA/PWD)': {'hi': 'दूसरी एजेंसी (MMRDA/PWD) को भेजी गई', 'mr': 'दुसऱ्या यंत्रणेकडे (MMRDA/PWD) पाठवली'},
  'Forwarded to another department (solid waste)': {'hi': 'दूसरे विभाग (ठोस कचरा) को भेजी गई', 'mr': 'दुसऱ्या विभागाकडे (घनकचरा) पाठवली'},
  'Closed: not a BMC road': {'hi': 'बंद: यह BMC की सड़क नहीं है', 'mr': 'बंद: हा BMC चा रस्ता नाही'},
  'Closed: not a road issue': {'hi': 'बंद: यह सड़क की समस्या नहीं है', 'mr': 'बंद: ही रस्त्याची समस्या नाही'},
  'Closed as duplicate': {'hi': 'दोहराई गई शिकायत के रूप में बंद', 'mr': 'दुबार तक्रार म्हणून बंद'},
  'Resolved, no work order linked': {'hi': 'हल हुई, कोई वर्क ऑर्डर नहीं जुड़ा', 'mr': 'निकाली, वर्क ऑर्डर जोडलेली नाही'},
  'At least 10 characters, please.': {'hi': 'कृपया कम से कम 10 अक्षर लिखें।', 'mr': 'कृपया किमान 10 अक्षरे लिहा.'},
  'Is it {a} or {b}? {a} is selected; change it below if needed.': {
    'hi': '{a} या {b}? अभी {a} चुना है; ज़रूरत हो तो नीचे बदलें।',
    'mr': '{a} की {b}? सध्या {a} निवडले आहे; गरज असल्यास खाली बदला.',
  },
  'Please describe the problem in a little more detail (10 to 1000 characters)': {
    'hi': 'कृपया समस्या थोड़ा और विस्तार से लिखें (10 से 1000 अक्षर)',
    'mr': 'कृपया समस्या थोडी अधिक सविस्तर लिहा (10 ते 1000 अक्षरे)',
  },
  'on time': {'hi': 'समय पर', 'mr': 'वेळेवर'},
  'late': {'hi': 'देर से', 'mr': 'उशिरा'},
  'held': {'hi': 'मरम्मत टिकी', 'mr': 'दुरुस्ती टिकली'},
  'repair failed within 30 days': {'hi': '30 दिनों में मरम्मत टूट गई', 'mr': '30 दिवसांत दुरुस्ती निकामी झाली'},
  'Received {d}': {'hi': 'प्राप्त {d}', 'mr': 'प्राप्त {d}'},

  // Complaint categories (the stored value stays English)
  'Pothole': {'hi': 'गड्ढा', 'mr': 'खड्डा'},
  'Waterlogging': {'hi': 'जलभराव', 'mr': 'पाणी साचणे'},
  'Open or broken manhole': {'hi': 'खुला या टूटा मैनहोल', 'mr': 'उघडे किंवा तुटलेले मॅनहोल'},
  'Choked drain / nullah overflow': {'hi': 'बंद नाली / नाला उफान पर', 'mr': 'तुंबलेले गटार / नाला भरून वाहतो'},
  'Road cave-in': {'hi': 'सड़क धंस गई', 'mr': 'रस्ता खचला'},
  'Broken paver blocks': {'hi': 'टूटे पेवर ब्लॉक', 'mr': 'तुटलेले पेव्हर ब्लॉक'},
  'Road related': {'hi': 'सड़क से जुड़ी', 'mr': 'रस्त्याशी संबंधित'},
  'Other': {'hi': 'अन्य', 'mr': 'इतर'},

  // Track
  'By complaint id': {'hi': 'शिकायत नंबर से', 'mr': 'तक्रार क्रमांकाने'},
  'Complaint id': {'hi': 'शिकायत नंबर', 'mr': 'तक्रार क्रमांक'},
  'By locality': {'hi': 'इलाके से', 'mr': 'परिसरानुसार'},
  'No complaints recorded in {loc}.': {'hi': '{loc} में कोई शिकायत दर्ज नहीं है।', 'mr': '{loc} मध्ये एकही तक्रार नोंदलेली नाही.'},
  '{n} complaints in {loc}, newest first': {'hi': '{loc} में {n} शिकायतें, नई पहले', 'mr': '{loc} मध्ये {n} तक्रारी, नवीन आधी'},
  ' (latest 50 shown)': {'hi': ' (नई 50 दिखाई गई हैं)', 'mr': ' (नवीन 50 दाखवल्या आहेत)'},
  'Status: {s}': {'hi': 'स्थिति: {s}', 'mr': 'स्थिती: {s}'},
  'What happened': {'hi': 'क्या हुआ', 'mr': 'काय झाले'},
  'Received': {'hi': 'शिकायत मिली', 'mr': 'तक्रार मिळाली'},
  'Added to complaint {id}': {'hi': 'शिकायत {id} में जोड़ी गई', 'mr': 'तक्रार {id} मध्ये जोडली'},
  'Follow that complaint for the repair.': {'hi': 'मरम्मत के लिए उस शिकायत को देखें।', 'mr': 'दुरुस्तीसाठी ती तक्रार पाहा.'},
  'Track it': {'hi': 'उसे देखें', 'mr': 'ती पाहा'},
  'No work order linked': {'hi': 'कोई वर्क ऑर्डर नहीं जुड़ा', 'mr': 'वर्क ऑर्डर जोडलेली नाही'},
  'No repair has been ordered for this complaint yet.': {
    'hi': 'इस शिकायत के लिए अभी तक मरम्मत का आदेश नहीं दिया गया।',
    'mr': 'या तक्रारीसाठी अजून दुरुस्तीचा आदेश दिलेला नाही.',
  },
  'Closed as: {s}': {'hi': 'बंद: {s}', 'mr': 'बंद: {s}'},
  'Linked to work order {id}': {'hi': 'वर्क ऑर्डर {id} से जुड़ी', 'mr': 'वर्क ऑर्डर {id} शी जोडलेली'},
  'Assigned {d}': {'hi': 'काम सौंपा {d}', 'mr': 'काम सोपवले {d}'},
  'Completed {d}': {'hi': 'काम पूरा {d}', 'mr': 'काम पूर्ण {d}'},
  'On time against the SLA': {'hi': 'तय समय (SLA) के भीतर', 'mr': 'ठरलेल्या वेळेत (SLA)'},
  'Late against the SLA': {'hi': 'तय समय (SLA) से देर से', 'mr': 'ठरलेल्या वेळेपेक्षा (SLA) उशिरा'},
  'Repair failed within 30 days': {'hi': '30 दिनों में मरम्मत टूट गई', 'mr': '30 दिवसांत दुरुस्ती निकामी झाली'},
  'Held: not re-opened within 30 days': {'hi': 'मरम्मत टिकी: 30 दिनों में दोबारा शिकायत नहीं', 'mr': 'दुरुस्ती टिकली: 30 दिवसांत पुन्हा तक्रार नाही'},
  'Needs review: the same spot was reported again.': {
    'hi': 'जांच ज़रूरी: उसी जगह की फिर से शिकायत आई।',
    'mr': 'तपासणी आवश्यक: त्याच ठिकाणाची पुन्हा तक्रार आली.',
  },
  'No repeat complaint within 30 days.': {'hi': '30 दिनों में दोबारा शिकायत नहीं आई।', 'mr': '30 दिवसांत पुन्हा तक्रार आली नाही.'},
  'Open road: {r}': {'hi': 'सड़क देखें: {r}', 'mr': 'रस्ता पाहा: {r}'},
  'Complaint {id}': {'hi': 'शिकायत {id}', 'mr': 'तक्रार {id}'},

  // Ask my ward
  'Ward (type to search)': {'hi': 'वार्ड (खोजने के लिए लिखें)', 'mr': 'वॉर्ड (शोधण्यासाठी टाइप करा)'},
  'What would you like to ask about?': {'hi': 'आप किस बारे में पूछना चाहते हैं?', 'mr': 'तुम्हाला कशाबद्दल विचारायचे आहे?'},
  'Pick your ward first.': {'hi': 'पहले अपना वार्ड चुनें।', 'mr': 'आधी तुमचा वॉर्ड निवडा.'},
  'Repairs that failed within 30 days': {'hi': '30 दिनों में टूटी मरम्मतें', 'mr': '30 दिवसांत निकामी झालेल्या दुरुस्त्या'},
  'Money billed under warranty': {'hi': 'वारंटी के दौरान दिया गया पैसा', 'mr': 'वॉरंटीच्या काळात दिलेले पैसे'},
  'Complaints never fixed': {'hi': 'जो शिकायतें कभी ठीक नहीं हुईं', 'mr': 'ज्या तक्रारी कधीच सुटल्या नाहीत'},
  'Budget and spending': {'hi': 'बजट और खर्च', 'mr': 'बजेट आणि खर्च'},
  'Question to Ward {w}': {'hi': 'वार्ड {w} से सवाल', 'mr': 'वॉर्ड {w} ला प्रश्न'},
  'Your question (editable)': {'hi': 'आपका सवाल (बदल सकते हैं)', 'mr': 'तुमचा प्रश्न (बदलता येईल)'},

  // Report card
  'Pick a ward to see its report card.': {'hi': 'रिपोर्ट कार्ड देखने के लिए वार्ड चुनें।', 'mr': 'रिपोर्ट कार्ड पाहण्यासाठी वॉर्ड निवडा.'},
  'Download image': {'hi': 'इमेज डाउनलोड करें', 'mr': 'इमेज डाउनलोड करा'},
  'Share image': {'hi': 'इमेज शेयर करें', 'mr': 'इमेज शेअर करा'},
  'WARD REPORT CARD · ROAD REPAIRS 2025': {'hi': 'वार्ड रिपोर्ट कार्ड · सड़क मरम्मत 2025', 'mr': 'वॉर्ड रिपोर्ट कार्ड · रस्ते दुरुस्ती 2025'},
  'Ward {w}': {'hi': 'वार्ड {w}', 'mr': 'वॉर्ड {w}'},
  'Spent {spend} of {budget} budget': {'hi': '{budget} के बजट में से {spend} खर्च', 'mr': '{budget} बजेटपैकी {spend} खर्च'},
  '{amount} over budget': {'hi': 'बजट से {amount} ज़्यादा', 'mr': 'बजेटपेक्षा {amount} जास्त'},
  'to be reviewed': {'hi': 'की जांच होनी है', 'mr': 'ची तपासणी बाकी'},
  'of repairs failed\nwithin 30 days': {'hi': 'मरम्मतें 30 दिनों\nमें टूट गईं', 'mr': 'दुरुस्त्या 30 दिवसांत\nनिकामी झाल्या'},
  'open issues\nnever fixed': {'hi': 'शिकायतें जो\nकभी ठीक नहीं हुईं', 'mr': 'तक्रारी ज्या\nकधीच सुटल्या नाहीत'},
  'Next rupee should go to': {'hi': 'अगला रुपया यहां लगना चाहिए', 'mr': 'पुढचा रुपया इथे लागावा'},
  'No items listed': {'hi': 'कोई काम सूची में नहीं', 'mr': 'यादीत कोणतेही काम नाही'},
  // App shell, Home, Map tab, ward picker, account (restructure)
  'Home': {'hi': 'होम', 'mr': 'होम'},
  'Map': {'hi': 'नक्शा', 'mr': 'नकाशा'},
  'Report': {'hi': 'शिकायत', 'mr': 'तक्रार'},
  'Audit': {'hi': 'ऑडिट', 'mr': 'ऑडिट'},
  'Contractors': {'hi': 'ठेकेदार', 'mr': 'कंत्राटदार'},
  'My Ward': {'hi': 'मेरा वार्ड', 'mr': 'माझा वॉर्ड'},
  'Namaste': {'hi': 'नमस्ते', 'mr': 'नमस्कार'},
  'Change ward': {'hi': 'वार्ड बदलें', 'mr': 'वॉर्ड बदला'},
  'Change': {'hi': 'बदलें', 'mr': 'बदला'},
  'Pothole, waterlogging, a repair that failed': {
    'hi': 'गड्ढा, जलभराव, टूटी मरम्मत',
    'mr': 'खड्डा, पाणी साचणे, निकामी झालेली दुरुस्ती',
  },
  'Mumbai this monsoon': {'hi': 'इस मानसून में मुंबई', 'mr': 'या पावसाळ्यात मुंबई'},
  'billed on roads under warranty — to be claimed and verified': {
    'hi': 'वारंटी वाली सड़कों पर भुगतान हुआ — वसूली और जांच बाकी है',
    'mr': 'वॉरंटीतील रस्त्यांवर दिले गेले — वसुली आणि पडताळणी बाकी आहे',
  },
  'Ward {w} this monsoon': {'hi': 'इस मानसून में वार्ड {w}', 'mr': 'या पावसाळ्यात वॉर्ड {w}'},
  'of the budget spent': {'hi': 'बजट खर्च हुआ', 'mr': 'बजेट खर्च झाले'},
  'to review': {'hi': 'जांच बाकी', 'mr': 'तपासणी बाकी'},
  'repairs failed within 30 days': {'hi': 'मरम्मतें 30 दिनों में टूटीं', 'mr': 'दुरुस्त्या 30 दिवसांत निकामी'},
  'Watch the 2025 monsoon': {'hi': '2025 का मानसून देखें', 'mr': '2025 चा पावसाळा पाहा'},
  'June to October on the map: complaints, repairs and repairs that failed.': {
    'hi': 'जून से अक्टूबर नक्शे पर: शिकायतें, मरम्मतें और टूटी मरम्मतें।',
    'mr': 'जून ते ऑक्टोबर नकाशावर: तक्रारी, दुरुस्त्या आणि निकामी झालेल्या दुरुस्त्या.',
  },
  'Not a BMC app.': {'hi': 'यह BMC का ऐप नहीं है।', 'mr': 'हे BMC चे ॲप नाही.'},
  'What is the problem?': {'hi': 'समस्या क्या है?', 'mr': 'समस्या काय आहे?'},
  'Layers': {'hi': 'परतें', 'mr': 'स्तर'},
  'Legend': {'hi': 'संकेत', 'mr': 'संकेत'},
  'Turn a layer on to see its legend.': {'hi': 'संकेत देखने के लिए कोई परत चालू करें।', 'mr': 'संकेत पाहण्यासाठी एखादा स्तर सुरू करा.'},
  'Shaded by the share of spend needing review': {'hi': 'जांच वाले खर्च के हिस्से के हिसाब से रंग', 'mr': 'तपासणीच्या खर्चाच्या वाट्यानुसार रंग'},
  'Coloured by flag; shown when zoomed in or a ward is selected': {
    'hi': 'फ़्लैग के हिसाब से रंग; ज़ूम करने या वार्ड चुनने पर दिखती हैं',
    'mr': 'फ्लॅगनुसार रंग; झूम केल्यावर किंवा वॉर्ड निवडल्यावर दिसतात',
  },
  'Ranked repairs for the selected ward': {'hi': 'चुने गए वार्ड की प्राथमिकता वाली मरम्मतें', 'mr': 'निवडलेल्या वॉर्डच्या प्राधान्य क्रमाने दुरुस्त्या'},
  'Open and repeat complaints, clustered': {'hi': 'खुली और दोबारा आई शिकायतें, समूह में', 'mr': 'उघड्या आणि पुन्हा आलेल्या तक्रारी, गटांत'},
  'Play the monsoon': {'hi': 'मानसून चलाएं', 'mr': 'पावसाळा पाहा'},
  'Open ward': {'hi': 'वार्ड देखें', 'mr': 'वॉर्ड पाहा'},
  'Open road': {'hi': 'सड़क देखें', 'mr': 'रस्ता पाहा'},
  'of spend': {'hi': 'खर्च का', 'mr': 'खर्चाचा'},
  'Spent': {'hi': 'खर्च', 'mr': 'खर्च'},
  'spent': {'hi': 'खर्च', 'mr': 'खर्च'},
  'tap a road for its work orders': {'hi': 'वर्क ऑर्डर देखने के लिए सड़क पर टैप करें', 'mr': 'वर्क ऑर्डर पाहण्यासाठी रस्त्यावर टॅप करा'},
  'Choose your ward': {'hi': 'अपना वार्ड चुनें', 'mr': 'तुमचा वॉर्ड निवडा'},
  'Ward or area name': {'hi': 'वार्ड या इलाके का नाम', 'mr': 'वॉर्ड किंवा परिसराचे नाव'},
  'Not signed in': {'hi': 'साइन इन नहीं है', 'mr': 'साइन इन केलेले नाही'},
  'Demo: switch role in one tap': {'hi': 'डेमो: एक टैप में भूमिका बदलें', 'mr': 'डेमो: एका टॅपमध्ये भूमिका बदला'},
  'The map and ward figures are open to everyone. Sign in to file a complaint or draft a notice.': {
    'hi': 'नक्शा और वार्ड के आंकड़े सभी के लिए खुले हैं। शिकायत दर्ज करने या नोटिस बनाने के लिए साइन इन करें।',
    'mr': 'नकाशा आणि वॉर्डची आकडेवारी सर्वांसाठी खुली आहे. तक्रार नोंदवण्यासाठी किंवा नोटीस तयार करण्यासाठी साइन इन करा.',
  },
  'Synthetic data, how flags work, credits': {'hi': 'कृत्रिम डेटा, फ़्लैग कैसे बनते हैं, श्रेय', 'mr': 'कृत्रिम डेटा, फ्लॅग कसे ठरतात, श्रेय'},

  // Complaint trail on the complaint page
  'Reported as {a} → corrected to {b}': {'hi': '{a} के रूप में दर्ज → सुधार कर {b}', 'mr': '{a} म्हणून नोंद → दुरुस्त करून {b}'},
  'Part of issue {id}': {'hi': 'मुद्दा {id} का हिस्सा', 'mr': 'मुद्दा {id} चा भाग'},
  'Grouped with other reports of the same problem.': {
    'hi': 'इसी समस्या की दूसरी शिकायतों के साथ जोड़ा गया।',
    'mr': 'याच समस्येच्या इतर तक्रारींसोबत जोडले.',
  },
  'Grouped with reports of the same problem. Its work order is our best match (inferred link), not BMC’s record.': {
    'hi': 'इसी समस्या की शिकायतों के साथ जोड़ा गया। इसका वर्क ऑर्डर हमारा सबसे करीबी मिलान है (अनुमानित लिंक), BMC का रिकॉर्ड नहीं।',
    'mr': 'याच समस्येच्या तक्रारींसोबत जोडले. याचा वर्क ऑर्डर आमचा सर्वात जवळचा जुळणारा आहे (अनुमानित लिंक), BMC ची नोंद नाही.',
  },
  'See the full trail': {'hi': 'पूरा रास्ता देखें', 'mr': 'संपूर्ण मार्ग पाहा'},

  // Ask about a complaint (citizen bot)
  'Ask about a complaint': {'hi': 'शिकायत के बारे में पूछें', 'mr': 'तक्रारीबद्दल विचारा'},
  'What happened to my complaint? Type its id or a question.': {
    'hi': 'मेरी शिकायत का क्या हुआ? उसका नंबर या सवाल लिखें।',
    'mr': 'माझ्या तक्रारीचे काय झाले? तिचा क्रमांक किंवा प्रश्न लिहा.',
  },
  'Namaste! Send your complaint id (like BMC25-001234 or NS-000012) or ask a question, and I will tell you what happened to it.': {
    'hi': 'नमस्ते! अपनी शिकायत का नंबर (जैसे BMC25-001234 या NS-000012) भेजें या सवाल पूछें, मैं बताऊँगा कि उसका क्या हुआ।',
    'mr': 'नमस्कार! तुमचा तक्रार क्रमांक (जसे BMC25-001234 किंवा NS-000012) पाठवा किंवा प्रश्न विचारा, मी तिचे काय झाले ते सांगेन.',
  },
  'Why is my road still broken?': {'hi': 'मेरी सड़क अभी भी टूटी क्यों है?', 'mr': 'माझा रस्ता अजूनही खराब का आहे?'},
  'How much was spent on my road?': {'hi': 'मेरी सड़क पर कितना खर्च हुआ?', 'mr': 'माझ्या रस्त्यावर किती खर्च झाला?'},
  'Type a complaint id or a question': {'hi': 'शिकायत नंबर या सवाल लिखें', 'mr': 'तक्रार क्रमांक किंवा प्रश्न लिहा'},
  'Send': {'hi': 'भेजें', 'mr': 'पाठवा'},
  'Looking it up…': {'hi': 'देख रहे हैं…', 'mr': 'शोधत आहे…'},
  'Answered live by Claude': {'hi': 'Claude ने अभी जवाब लिखा', 'mr': 'Claude ने आत्ता उत्तर लिहिले'},
  'Saved answer': {'hi': 'सहेजा हुआ जवाब', 'mr': 'जतन केलेले उत्तर'},
  'Could not get an answer. {e}': {'hi': 'जवाब नहीं मिल सका। {e}', 'mr': 'उत्तर मिळाले नाही. {e}'},
  'Work order {id}': {'hi': 'वर्क ऑर्डर {id}', 'mr': 'वर्क ऑर्डर {id}'},
  'Issue {id}': {'hi': 'मुद्दा {id}', 'mr': 'मुद्दा {id}'},
  'Complaint trail · Ward {w}': {'hi': 'शिकायत का रास्ता · वार्ड {w}', 'mr': 'तक्रारीचा मार्ग · वॉर्ड {w}'},
  'Inferred link': {'hi': 'अनुमानित लिंक', 'mr': 'अनुमानित लिंक'},
  'Under warranty': {'hi': 'वारंटी में', 'mr': 'वॉरंटीत'},
  'Fixed and held': {'hi': 'ठीक हुआ और टिका', 'mr': 'दुरुस्त झाले आणि टिकले'},
  'Fixed, then failed': {'hi': 'ठीक हुआ, फिर खराब हुआ', 'mr': 'दुरुस्त झाले, पुन्हा बिघडले'},
  'In progress': {'hi': 'काम चल रहा है', 'mr': 'काम सुरू आहे'},
  'Never fixed': {'hi': 'ठीक नहीं हुआ', 'mr': 'दुरुस्त झाले नाही'},

  // Report flow, track, complaint detail (design overhaul)
  'Continue': {'hi': 'आगे बढ़ें', 'mr': 'पुढे चला'},
  'Or pick one': {'hi': 'या एक चुनें', 'mr': 'किंवा एक निवडा'},
  'Step {n} of 3': {'hi': 'चरण {n} / 3', 'mr': 'पायरी {n} / 3'},
  'Keyword rules, no AI': {'hi': 'शब्द-नियम, AI नहीं', 'mr': 'शब्द-नियम, AI नाही'},
  'Problem': {'hi': 'समस्या', 'mr': 'समस्या'},
  'Place': {'hi': 'जगह', 'mr': 'ठिकाण'},
  'Ward': {'hi': 'वार्ड', 'mr': 'वॉर्ड'},
  'Pick one': {'hi': 'एक चुनें', 'mr': 'एक निवडा'},
  'Pick your locality': {'hi': 'अपना इलाका चुनें', 'mr': 'तुमचा परिसर निवडा'},
  'Is it {a} or {b}?': {'hi': 'क्या यह {a} है या {b}?', 'mr': 'हे {a} आहे की {b}?'},
  'Looks right': {'hi': 'सही है', 'mr': 'बरोबर आहे'},
  'Others reported this': {'hi': 'दूसरों ने भी यह बताया है', 'mr': 'इतरांनीही हे नोंदवले आहे'},
  'Reported': {'hi': 'दर्ज हो गई', 'mr': 'नोंदवली गेली'},
  'Copy': {'hi': 'कॉपी करें', 'mr': 'कॉपी करा'},
  'Copied': {'hi': 'कॉपी हो गया', 'mr': 'कॉपी झाले'},
  'Done': {'hi': 'हो गया', 'mr': 'झाले'},
  'We’ll show what happens to it here.': {'hi': 'इसका क्या हुआ, हम यहां दिखाएंगे।', 'mr': 'तिचे काय झाले ते आम्ही इथे दाखवू.'},
  'Complaint id or locality': {'hi': 'शिकायत नंबर या इलाका', 'mr': 'तक्रार क्रमांक किंवा परिसर'},
  'Dataset ids look like BMC25-000123; app ids like NS-000001.': {
    'hi': 'डेटासेट के नंबर BMC25-000123 जैसे होते हैं; ऐप के नंबर NS-000001 जैसे।',
    'mr': 'डेटासेटचे क्रमांक BMC25-000123 सारखे असतात; ॲपचे क्रमांक NS-000001 सारखे.',
  },
  'No complaint with id {id}. Dataset ids look like BMC25-000123; app ids like NS-000001.': {
    'hi': '{id} नंबर की कोई शिकायत नहीं मिली। डेटासेट के नंबर BMC25-000123 जैसे होते हैं; ऐप के नंबर NS-000001 जैसे।',
    'mr': '{id} क्रमांकाची तक्रार सापडली नाही. डेटासेटचे क्रमांक BMC25-000123 सारखे असतात; ॲपचे क्रमांक NS-000001 सारखे.',
  },
  'No locality or complaint id matches “{q}”.': {
    'hi': '“{q}” से कोई इलाका या शिकायत नंबर नहीं मिलता।',
    'mr': '“{q}” शी जुळणारा परिसर किंवा तक्रार क्रमांक नाही.',
  },
  'Track {id}': {'hi': '{id} की स्थिति देखें', 'mr': '{id} ची स्थिती पाहा'},
  'Clear': {'hi': 'हटाएं', 'mr': 'काढा'},
  'Could not load localities.': {'hi': 'इलाके लोड नहीं हो सके।', 'mr': 'परिसर लोड होऊ शकले नाहीत.'},
  'Could not load complaints.': {'hi': 'शिकायतें लोड नहीं हो सकीं।', 'mr': 'तक्रारी लोड होऊ शकल्या नाहीत.'},
  'Could not load this.': {'hi': 'यह लोड नहीं हो सका।', 'mr': 'हे लोड होऊ शकले नाही.'},
  'Road': {'hi': 'सड़क', 'mr': 'रस्ता'},
  'Contractor': {'hi': 'ठेकेदार', 'mr': 'कंत्राटदार'},
  'Cost': {'hi': 'लागत', 'mr': 'खर्च'},

  // Home, ward comparison, ward picker, report card (phase 2, screen A)
  'Do something': {'hi': 'कुछ करें', 'mr': 'काही करा'},
  'Complaint trail': {'hi': 'शिकायत का रास्ता', 'mr': 'तक्रारीचा मार्ग'},
  '{n} jobs across Mumbai · see wards': {'hi': 'पूरी मुंबई में {n} काम · वार्ड देखें', 'mr': 'संपूर्ण मुंबईत {n} कामे · वॉर्ड पाहा'},
  'Could not load the city figures.': {'hi': 'शहर के आंकड़े लोड नहीं हो सके।', 'mr': 'शहराचे आकडे लोड होऊ शकले नाहीत.'},
  'Could not load ward {w}.': {'hi': 'वार्ड {w} लोड नहीं हो सका।', 'mr': 'वॉर्ड {w} लोड होऊ शकला नाही.'},
  'Wards this monsoon': {'hi': 'इस मानसून में वार्ड', 'mr': 'या पावसाळ्यातील वॉर्ड'},
  'Tap a ward to open its page.': {'hi': 'वार्ड का पेज खोलने के लिए उस पर टैप करें।', 'mr': 'वॉर्डचे पान उघडण्यासाठी त्यावर टॅप करा.'},
  'To review': {'hi': 'जांच बाकी', 'mr': 'तपासणी बाकी'},
  'Over budget': {'hi': 'बजट से ज़्यादा', 'mr': 'बजेटपेक्षा जास्त'},
  '{n} jobs': {'hi': '{n} काम', 'mr': '{n} कामे'},
  '{p} of spend': {'hi': 'खर्च का {p}', 'mr': 'खर्चाच्या {p}'},
  'No ward has work billed under warranty.': {'hi': 'किसी वार्ड में वारंटी वाला भुगतान नहीं है।', 'mr': 'कोणत्याही वॉर्डमध्ये वॉरंटीतील बिल नाही.'},
  'Could not load wards.': {'hi': 'वार्ड लोड नहीं हो सके।', 'mr': 'वॉर्ड लोड होऊ शकले नाहीत.'},
  'No ward matches.': {'hi': 'कोई वार्ड नहीं मिला।', 'mr': 'एकही वॉर्ड जुळला नाही.'},
  'Chosen': {'hi': 'चुना हुआ', 'mr': 'निवडलेला'},
  'Could not load the report card.': {'hi': 'रिपोर्ट कार्ड लोड नहीं हो सका।', 'mr': 'रिपोर्ट कार्ड लोड होऊ शकले नाही.'},
};
