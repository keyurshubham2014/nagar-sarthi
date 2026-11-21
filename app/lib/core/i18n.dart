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
};
