import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';
import 'api_service.dart';
import '../screens/pose_detail_screen.dart';
import '../screens/breathing_detail_screen.dart';
import '../screens/breathing_guide_screen.dart';
import '../screens/yoga_gpt_screen.dart';

/// Global navigator key so the voice assistant can navigate from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// A recognized intent the app can act on.
enum VoiceIntent {
  home,
  explore,
  diet,
  profile,
  assistant,
  history,
  start,
  generate,
  setReminder,
  logout,
  login,
  signup,
  read,
  help,
  stop,
  greet,
  back,
  unknown,
}

/// Central voice-accessibility service: text-to-speech + speech recognition +
/// hands-free command routing. A single shared instance drives the whole app.
class VoiceService extends ChangeNotifier {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final FlutterTts _tts = FlutterTts();

  // ── Vosk offline speech recognition (continuous, no beeps) ────────────────
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  bool _voskReady = false;
  StreamSubscription? _resultSub;
  StreamSubscription? _partialSub;
  bool _voskStarted = false;

  static const String _modelAsset =
      'assets/models/vosk-model-small-en-in-0.4.zip';

  bool accessibilityMode = false; // persisted; drives auto-announcements
  bool _ttsReady = false;

  bool speaking = false;
  bool listening = false;
  String lastHeard = '';
  String status = '';

  /// The shell registers this so voice commands can switch bottom-nav tabs.
  void Function(int tabIndex)? tabSwitcher;

  /// Current screen registers a text provider so "read"/"repeat" can speak it.
  String Function()? screenReader;

  /// Registered actions (e.g. start practice / generate) for the active screen.
  final Map<String, VoidCallback> _actions = {};

  bool _initialized = false;
  bool _welcomed = false;
  bool get welcomed => _welcomed;
  void markWelcomed() => _welcomed = true;

  /// Speak the welcome + command help ONCE per app launch. After that the
  /// assistant stays quiet unless the user gives a command or asks for help.
  Future<void> welcomeOnLaunch() async {
    if (_welcomed) return;
    _welcomed = true;
    if (!accessibilityMode) return;
    await speak(t(
      "Welcome to Yoga Mitra. Control the app with your voice. Say home, explore, diet, profile, assistant, start, history, or read. Say a task like generate my diet plan and I will do it. To change language say Hindi, Marathi, or English. Say help anytime.",
      "योगा मित्रमध्ये स्वागत आहे. आवाजाने अ‍ॅप वापरा. होम, एक्सप्लोर, डाएट, प्रोफाइल, असिस्टंट, स्टार्ट, हिस्ट्री किंवा रीड म्हणा. 'माझा डाएट प्लॅन तयार कर' असे काम सांगा, मी करेन. भाषा बदलण्यासाठी हिंदी, मराठी किंवा इंग्लिश म्हणा. मदतीसाठी हेल्प म्हणा.",
      "योगा मित्र में स्वागत है. आवाज़ से ऐप चलाएं. होम, एक्सप्लोर, डाइट, प्रोफ़ाइल, असिस्टेंट, स्टार्ट, हिस्ट्री या रीड कहें. 'मेरा डाइट प्लान बनाओ' जैसा काम कहें, मैं करूँगा. भाषा बदलने के लिए हिंदी, मराठी या इंग्लिश कहें. मदद के लिए हेल्प कहें.",
    ));
  }

  String get langCode {
    switch (LanguageHelper.currentLanguage) {
      case "मराठी":
        return "mr";
      case "हिंदी":
        return "hn";
      default:
        return "en";
    }
  }

  String _ttsLocale() {
    switch (LanguageHelper.currentLanguage) {
      case "मराठी":
        return "mr-IN";
      case "हिंदी":
        return "hi-IN";
      default:
        return "en-IN";
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    // Voice assistant is ON by default (fully automatic, hands-free). A user
    // can turn it off in Profile → Accessibility.
    accessibilityMode = prefs.getBool('voice_accessibility') ?? true;

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsReady = true;
    } catch (_) {}

    // Load the Vosk offline model in the background (first launch extracts the
    // ~36MB model; TTS/greeting works immediately, listening starts when ready).
    _initVosk();
  }

  Future<void> _initVosk() async {
    try {
      final modelPath = await ModelLoader().loadFromAssets(_modelAsset);
      _model = await _vosk.createModel(modelPath);
      _recognizer =
          await _vosk.createRecognizer(model: _model!, sampleRate: 16000);
      _speechService = await _vosk.initSpeechService(_recognizer!);
      _resultSub = _speechService!.onResult().listen(_onVoskResult);
      _partialSub = _speechService!.onPartial().listen(_onVoskPartial);
      _voskReady = true;
      status = 'ready';
      notifyListeners();
      if (accessibilityMode) startListening();
    } catch (e) {
      _voskReady = false;
      status = 'stt-init-failed';
      notifyListeners();
    }
  }

  /// Switch the whole assistant (recognition + speech + UI text) to a language
  /// and keep it there until changed again. appLang is "English" | "हिंदी" | "मराठी".
  Future<void> setLanguage(String appLang) async {
    if (LanguageHelper.currentLanguage == appLang) return;
    LanguageHelper.currentLanguage = appLang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', appLang);
    notifyListeners();
    // Confirm in the NEW language (t() now resolves to it)
    await speak(t(
      "Okay, I will speak in English now.",
      "ठीक आहे, आता मी मराठीत बोलेन.",
      "ठीक है, अब मैं हिंदी में बोलूँगा.",
    ));
  }

  /// Detect an explicit "switch language" request in either script.
  String? _languageRequest(String s) {
    if (s.contains('english') ||
        s.contains('इंग्लिश') ||
        s.contains('इंग्रजी') ||
        s.contains('अंग्रेजी') ||
        s.contains('अंग्रेज़ी')) {
      return 'English';
    }
    if (s.contains('marathi') || s.contains('मराठी')) return 'मराठी';
    if (s.contains('hindi') || s.contains('हिंदी') || s.contains('हिन्दी')) {
      return 'हिंदी';
    }
    return null;
  }

  Future<void> setAccessibilityMode(bool on) async {
    accessibilityMode = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_accessibility', on);
    notifyListeners();
    if (on) {
      await speak(t(
        "Voice mode on. Say a command like home, explore, diet, profile, or help.",
        "व्हॉईस मोड चालू. होम, एक्सप्लोर, डाएट, प्रोफाइल किंवा हेल्प म्हणा.",
        "वॉइस मोड चालू. होम, एक्सप्लोर, डाइट, प्रोफ़ाइल या हेल्प कहें.",
      ));
      startListening();
    } else {
      await stopListening();
      await speak(t("Voice mode off.", "व्हॉईस मोड बंद.", "वॉइस मोड बंद."));
    }
  }

  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);

  // ── TTS ────────────────────────────────────────────────────────────────
  // Words we most recently spoke — used to reject echo of our own voice.
  Set<String> _lastSpokenWords = {};

  Future<void> speak(String text, {bool resumeListening = true}) async {
    if (text.trim().isEmpty) return;
    // Remember what we're about to say so an echo of it can be ignored.
    _lastSpokenWords = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9ऀ-ॿ]+'))
        .where((w) => w.length > 1)
        .toSet();
    final snapshot = _lastSpokenWords;
    Future.delayed(const Duration(seconds: 4), () {
      if (identical(_lastSpokenWords, snapshot)) _lastSpokenWords = {};
    });
    try {
      // HARD-MUTE the mic while we talk, so it never hears its own voice.
      await _hardStopListening();
      await _tts.setLanguage(_ttsLocale());
      speaking = true;
      notifyListeners();
      await _tts.speak(text); // awaits completion; tap-screen to interrupt
    } catch (_) {}
    speaking = false;
    notifyListeners();
    // Resume listening quickly so we don't miss the start of your next command.
    if (resumeListening && accessibilityMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!speaking) startListening();
    }
  }

  /// Announce a screen — only when accessibility mode is on.
  Future<void> announce(String text) async {
    if (!accessibilityMode) return;
    await speak(text);
  }

  /// Stop talking immediately and silently (used by the "stop" command).
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking = false;
    notifyListeners();
  }

  /// Pause the recognizer (Vosk) — silent, no beep.
  Future<void> _hardStopListening() async {
    try {
      if (_voskStarted) {
        await _speechService?.stop();
        _voskStarted = false;
      }
    } catch (_) {}
    listening = false;
  }

  // ── Registration ──────────────────────────────────────────────────────────
  /// Persistent global actions (set once by the shell): assistant, history,
  /// generate, logout, etc.
  void setActions(Map<String, VoidCallback> actions) {
    _actions
      ..clear()
      ..addAll(actions);
  }

  void addAction(String key, VoidCallback action) => _actions[key] = action;
  void removeAction(String key) => _actions.remove(key);

  /// Per-screen "read this screen aloud" provider. Screens set it on open and
  /// clear it on close — this never wipes the global actions.
  void setReader(String Function()? reader) => screenReader = reader;
  void clearReader() => screenReader = null;

  /// When a screen (e.g. YogaGPT chat) can accept free-form spoken text, it
  /// registers a handler here. Any speech that isn't a global command is then
  /// sent to that screen instead of being treated as "not understood".
  void Function(String text)? freeTextHandler;
  void setFreeTextHandler(void Function(String text)? h) => freeTextHandler = h;

  // ── Speech recognition (Vosk — offline, continuous, NO beeps) ───────────
  bool _processing = false;

  Future<void> startListening() async {
    if (!_voskReady || _speechService == null || speaking) return;
    if (_voskStarted) return;
    try {
      await _speechService!.start();
      _voskStarted = true;
      listening = true;
      status = 'listening';
      notifyListeners();
    } catch (_) {
      _voskStarted = false;
      listening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      if (_voskStarted) {
        await _speechService?.stop();
        _voskStarted = false;
      }
    } catch (_) {}
    listening = false;
    notifyListeners();
  }

  /// Live partial text as the user speaks (visual feedback only).
  void _onVoskPartial(String jsonStr) {
    if (speaking) return;
    try {
      final p = (jsonDecode(jsonStr)['partial'] ?? '').toString().trim();
      if (p.isNotEmpty) {
        lastHeard = p;
        listening = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// A completed phrase — act on it. Vosk keeps listening continuously after.
  void _onVoskResult(String jsonStr) async {
    if (speaking || _processing) return;
    String text = '';
    try {
      text = (jsonDecode(jsonStr)['text'] ?? '').toString().trim();
    } catch (_) {}
    if (text.isEmpty) return;

    // Echo guard: if every word we heard was in what we just spoke, it's the
    // speaker leaking into the mic — ignore it (prevents self-triggered loops).
    final words = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
    if (_lastSpokenWords.isNotEmpty &&
        words.isNotEmpty &&
        words.every((w) => _lastSpokenWords.contains(w))) {
      return;
    }

    lastHeard = text;
    _processing = true;
    notifyListeners();
    await handleCommand(text);
    _processing = false;
  }

  /// Toggle listening (kept for compatibility; assistant is normally always-on).
  Future<void> toggleListen() async {
    if (_voskStarted) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  // ── Command parsing + routing ────────────────────────────────────────────
  VoiceIntent parseIntent(String raw) {
    final s = raw.toLowerCase();
    bool has(List<String> keys) => keys.any((k) => s.contains(k));

    if (has(['hello', 'namaste', 'नमस्ते', 'हॅलो', 'नमस्कार'])) {
      return VoiceIntent.greet;
    }
    if (has(['help', 'command', 'what can', 'मदत', 'मदद', 'सहायता'])) {
      return VoiceIntent.help;
    }
    if (has(['stop', 'quiet', 'silence', 'शांत', 'थांब', 'रुक', 'बंद'])) {
      return VoiceIntent.stop;
    }
    if (has(['read', 'repeat', 'again', "what's on", 'whats on', 'वाच', 'पढ', 'पुन्हा', 'फिर'])) {
      return VoiceIntent.read;
    }
    if (has(['login', 'log in', 'sign in', 'लॉगिन', 'लॉग इन'])) {
      return VoiceIntent.login;
    }
    if (has(['sign up', 'signup', 'register', 'create account', 'नवीन खाते',
        'रजिस्टर', 'खाता बनाओ'])) {
      return VoiceIntent.signup;
    }
    if (has(['home', 'होम', 'मुख्य'])) return VoiceIntent.home;
    if (has(['explore', 'recommend', 'suggestion', 'शिफारस', 'सिफारिश', 'एक्सप्लोर'])) {
      return VoiceIntent.explore;
    }
    if (has(['diet', 'food', 'meal', 'nutrition', 'आहार', 'डाएट', 'डाइट', 'खाना'])) {
      return VoiceIntent.diet;
    }
    if (has(['profile', 'setting', 'account', 'प्रोफाइल', 'सेटिंग', 'खाते', 'खाता'])) {
      return VoiceIntent.profile;
    }
    if (has([
      'assistant', 'assist', 'yoga gpt', 'yogagpt', 'yoga g', 'chat', 'gpt',
      'g p t', 'chatbot', 'bot', 'coach', 'guru', 'ask', 'question', 'doubt',
      'talk to', 'help me with', 'सहाय्यक', 'सहायक', 'चॅट', 'चैट', 'प्रश्न',
      'विचारा', 'पूछना', 'जीपीटी',
    ])) {
      return VoiceIntent.assistant;
    }
    if (has(['history', 'progress', 'session', 'इतिहास', 'प्रगती', 'प्रगति'])) {
      return VoiceIntent.history;
    }
    if (has(['generate', 'create routine', 'make routine', 'तयार', 'बनाओ', 'बनाएं'])) {
      return VoiceIntent.generate;
    }
    if (has(['start', 'practice', 'begin', 'सुरू', 'शुरू', 'अभ्यास', 'सराव'])) {
      return VoiceIntent.start;
    }
    if (has(['remind', 'alarm', 'रिमाइंडर', 'अलार्म'])) return VoiceIntent.setReminder;
    if (has(['logout', 'log out', 'sign out', 'लॉगआउट', 'लॉग आउट'])) {
      return VoiceIntent.logout;
    }
    if (has(['back', 'previous', 'return', 'मागे', 'पीछे', 'वापस'])) {
      return VoiceIntent.back;
    }
    return VoiceIntent.unknown;
  }

  Future<void> handleCommand(String raw) async {
    final s = raw.toLowerCase();

    // ── Language: explicit request ("speak hindi" / "मराठी" / "english") ──
    final reqLang = _languageRequest(s);
    if (reqLang != null) {
      await setLanguage(reqLang);
      return;
    }

    // Enable/disable voice mode by voice (works even before it's on)
    if (s.contains('voice mode') ||
        s.contains('enable voice') ||
        s.contains('turn on voice') ||
        s.contains('accessib') ||
        s.contains('व्हॉईस') ||
        s.contains('वॉइस')) {
      if (!accessibilityMode) {
        await setAccessibilityMode(true);
      }
      return;
    }
    if (s.contains('disable voice') || s.contains('turn off voice')) {
      await setAccessibilityMode(false);
      return;
    }

    // ── Diet for a specific complaint: short spoken food advice ─────────────
    final foodKw = s.contains('food') || s.contains('eat') || s.contains('खाना') ||
        s.contains('खाऊ') || s.contains('आहार') || s.contains('diet');
    final concernKw = s.contains('pain') || s.contains('ache') ||
        s.contains('problem') || s.contains('issue') || s.contains('having') ||
        s.contains('suggest') || s.contains('should i') || s.contains('for my') ||
        s.contains('because') || s.contains('acid') || s.contains('cold') ||
        s.contains('fever') || s.contains('weak') || s.contains('tired') ||
        s.contains('constip') || s.contains('gas') || s.contains('bloat') ||
        s.contains('दुख') || s.contains('दर्द') || s.contains('समस्या') ||
        s.contains('सुचव') || s.contains('सुझाव') || s.contains('त्रास');
    final isFullPlan = s.contains('generate') || s.contains('plan') ||
        s.contains('full') || s.contains('योजना');
    if (foodKw && concernKw && !isFullPlan) {
      final advice = await ApiService.foodForConcern(raw, langCode);
      await speak(advice ??
          t("Sorry, I couldn't get food advice right now.",
              "क्षमस्व, आत्ता सल्ला मिळाला नाही.",
              "क्षमा करें, अभी सलाह नहीं मिली."));
      return;
    }

    // ── Compound task commands: navigate AND do the task, then speak result ─
    final wantsDiet = s.contains('diet') || s.contains('food') || s.contains('meal') ||
        s.contains('आहार') || s.contains('डाएट') || s.contains('डाइट') || s.contains('खाना');
    final wantsGenerate = s.contains('generate') || s.contains('plan') ||
        s.contains('make') || s.contains('create') || s.contains('regenerate') ||
        s.contains('redo') || s.contains('again') || s.contains('तयार') ||
        s.contains('बनाओ') || s.contains('बनाएं') || s.contains('बनवा') ||
        s.contains('पुन्हा') || s.contains('फिर');
    final wantsRoutine = s.contains('routine') || s.contains('workout') ||
        s.contains('दिनचर्या') || s.contains('रूटीन');

    // "generate/make my diet plan" (with or without the word diet)
    if ((wantsDiet && wantsGenerate) ||
        (wantsGenerate && s.contains('diet plan')) ||
        (s.contains('diet') && s.contains('plan'))) {
      _actions['dietGenerate']?.call();
      return;
    }
    // "generate my routine"
    if (wantsRoutine && wantsGenerate) {
      _actions['generate']?.call();
      return;
    }

    // Contextual "finish" (e.g. during a pose session)
    if (_actions.containsKey('finish') &&
        (s.contains('finish') ||
            s.contains('done') ||
            s.contains('result') ||
            s.contains('feedback') ||
            s.contains('समाप्त') ||
            s.contains('पूर्ण') ||
            s.contains('झाले'))) {
      _actions['finish']!.call();
      return;
    }

    final intent = parseIntent(raw);
    final nav = appNavigatorKey.currentState;

    // ── Free-form text (e.g. a question asked to YogaGPT chat) ──────────────
    // In chat, ONLY an EXACT control phrase leaves; everything else is the
    // user's question. This fixes "I have back pain, what poses..." (which
    // contains the word "back") being mistaken for the "back" command.
    if (freeTextHandler != null) {
      const exitPhrases = {
        'back', 'go back', 'home', 'go home', 'stop', 'exit', 'close',
        'cancel', 'quit', 'leave',
        'मागे', 'मागे जा', 'होम', 'बंद', 'बंद कर', 'थांबा', 'पीछे',
        'वापस', 'रुको', 'रुक',
      };
      if (!exitPhrases.contains(s)) {
        freeTextHandler!(raw);
        return;
      }
      // else: fall through and treat as a real command
    }

    // ── Breathing techniques by voice (list / open / start guided) ──────────
    final breathingKw = s.contains('breathing') ||
        s.contains('breath') ||
        s.contains('pranayam') ||
        s.contains('प्राणायाम') ||
        s.contains('श्वास') ||
        s.contains('श्वसन');
    if (breathingKw) {
      await _ensureCatalog();
      final startKw = s.contains('start') ||
          s.contains('begin') ||
          s.contains('सुरू') ||
          s.contains('शुरू');
      if (startKw) {
        // If viewing a breathing technique, start THAT one; else best match.
        if (_actions.containsKey('startBreathing')) {
          _actions['startBreathing']!.call();
        } else {
          _startBreathing(_bestMatch(raw, _breathing));
        }
        return;
      }
      final listKw = s.contains('list') ||
          s.contains('which') ||
          s.contains('what') ||
          s.contains('available') ||
          s.contains('techniques') ||
          s.contains('all');
      final match = _bestMatch(raw, _breathing);
      if (match != null && !listKw) {
        _openBreathing(match);
        return;
      }
      await _speakBreathingList();
      return;
    }

    // ── Open a yoga pose by name ────────────────────────────────────────────
    final poseKw = s.contains('pose') || s.contains('asana') || s.contains('आसन');
    final openVerb = s.contains('open') ||
        s.contains('show') ||
        s.contains('do ') ||
        s.contains('practise') ||
        s.contains('perform') ||
        s.contains('want to do') ||
        s.contains('demonstrate');
    final notAContentCmd = !s.contains('diet') &&
        !s.contains('routine') &&
        !s.contains('plan') &&
        !s.contains('generate');
    if ((poseKw || openVerb) && notAContentCmd) {
      await _ensureCatalog();
      final match = _bestMatch(raw, _poses);
      if (match != null) {
        _openPose(match);
        return;
      }
      if (poseKw) {
        await speak(t(
            "Sorry, that pose is not available. Say explore to hear recommendations.",
            "क्षमस्व, ते आसन उपलब्ध नाही. शिफारसींसाठी एक्सप्लोर म्हणा.",
            "क्षमा करें, वह आसन उपलब्ध नहीं. सिफारिशों के लिए एक्सप्लोर कहें."));
        return;
      }
    }

    // ── Profile health edits by voice ("change weight to 50", "gender male") ─
    // Numbers may come through as digits OR words ("sixty", "fifty five").
    final hasNumber = RegExp(r'\d').hasMatch(s) ||
        RegExp(r'\b(twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|'
                r'hundred|one|two|three|four|five|six|seven|eight|nine|ten|'
                r'eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|'
                r'eighteen|nineteen)\b')
            .hasMatch(s);
    final genderKw = s.contains('male') ||
        s.contains('female') ||
        s.contains('पुरुष') ||
        s.contains('महिला') ||
        s.contains('स्त्री');
    // "weight" is often misheard as "wait"; "height" as "hight".
    final weightKw = s.contains('weight') ||
        s.contains('वजन') ||
        (s.contains('wait') && hasNumber);
    final heightKw = s.contains('height') ||
        s.contains('hight') ||
        s.contains('उंची') ||
        s.contains('ऊंचाई');
    final genderWordKw = s.contains('gender') || s.contains('लिंग') || genderKw;
    if (weightKw || heightKw || genderWordKw) {
      final actionable = hasNumber ||
          genderKw ||
          s.contains('change') ||
          s.contains('set') ||
          s.contains('update') ||
          s.contains('make it') ||
          s.contains('बदल') ||
          s.contains('कर');
      if (actionable) {
        if (profileEditHandler != null) {
          profileEditHandler!(raw);
        } else {
          tabSwitcher?.call(3);
          await speak(t("Opening profile. Please say the change again.",
              "प्रोफाइल उघडत आहे. पुन्हा सांगा.",
              "प्रोफ़ाइल खोल रहा हूँ. फिर कहें."));
        }
        return;
      }
    }

    switch (intent) {
      case VoiceIntent.greet:
        // Short — do NOT dump the whole command list (that only happens once at
        // launch, or when the user explicitly says "help").
        await speak(t(
          "Namaste! How can I help?",
          "नमस्ते! कशी मदत करू?",
          "नमस्ते! कैसे मदद करूँ?",
        ));
        break;
      case VoiceIntent.help:
        await speak(t(
          "Commands: say home, explore, diet, profile, assistant, start, history, read, or back. To change language, say English, Hindi, or Marathi.",
          "आज्ञा: होम, एक्सप्लोर, डाएट, प्रोफाइल, असिस्टंट, स्टार्ट, हिस्ट्री, रीड किंवा बॅक म्हणा. भाषा बदलण्यासाठी इंग्लिश, हिंदी किंवा मराठी म्हणा.",
          "कमांड: होम, एक्सप्लोर, डाइट, प्रोफ़ाइल, असिस्टेंट, स्टार्ट, हिस्ट्री, रीड या बैक कहें. भाषा बदलने के लिए इंग्लिश, हिंदी या मराठी कहें.",
        ));
        break;
      case VoiceIntent.stop:
        await stopSpeaking();
        break;
      case VoiceIntent.read:
        final text = screenReader?.call();
        if (text != null && text.trim().isNotEmpty) {
          await speak(text);
        } else {
          await speak(t("Nothing to read here.", "इथे वाचण्यासारखे काही नाही.",
              "यहाँ पढ़ने के लिए कुछ नहीं."));
        }
        break;
      case VoiceIntent.home:
        _switchTab(0, t("Home", "होम", "होम"));
        break;
      case VoiceIntent.explore:
        _switchTab(1, t("Explore", "एक्सप्लोर", "एक्सप्लोर"));
        break;
      case VoiceIntent.diet:
        _switchTab(2, t("Diet", "आहार", "डाइट"));
        break;
      case VoiceIntent.profile:
        _switchTab(3, t("Profile", "प्रोफाइल", "प्रोफ़ाइल"));
        break;
      case VoiceIntent.assistant:
        // The chat screen announces itself and starts listening for questions.
        if (_actions.containsKey('assistant')) {
          _actions['assistant']!.call();
        } else {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const YogaGptScreen()),
          );
        }
        break;
      case VoiceIntent.history:
        _actions['history']?.call();
        await speak(t("Opening your practice history.", "तुमचा इतिहास उघडत आहे.",
            "आपका इतिहास खोल रहा हूँ."));
        break;
      case VoiceIntent.start:
        if (_actions.containsKey('start')) {
          _actions['start']!.call();
          await speak(t("Starting practice.", "सराव सुरू करत आहे.",
              "अभ्यास शुरू कर रहा हूँ."));
        } else {
          _switchTab(0, t("Home", "होम", "होम"));
        }
        break;
      case VoiceIntent.generate:
        if (_actions.containsKey('generate')) {
          _actions['generate']!.call();
          await speak(t("Generating your routine.", "दिनचर्या तयार करत आहे.",
              "दिनचर्या बना रहा हूँ."));
        } else {
          _switchTab(1, t("Explore", "एक्सप्लोर", "एक्सप्लोर"));
        }
        break;
      case VoiceIntent.setReminder:
        _actions['reminder']?.call();
        break;
      case VoiceIntent.login:
        _actions['login']?.call();
        break;
      case VoiceIntent.signup:
        (_actions['start'] ?? _actions['signup'])?.call();
        break;
      case VoiceIntent.logout:
        _actions['logout']?.call();
        break;
      case VoiceIntent.back:
        if (nav?.canPop() ?? false) {
          nav!.pop();
          await speak(t("Going back.", "मागे जात आहे.", "वापस जा रहा हूँ."));
        }
        break;
      case VoiceIntent.unknown:
        // Stay quiet on things we don't understand — Vosk keeps listening.
        break;
    }
  }

  void _switchTab(int index, String name) {
    // Pop any pushed routes so the shell tab is visible
    final nav = appNavigatorKey.currentState;
    while (nav?.canPop() ?? false) {
      nav!.pop();
    }
    tabSwitcher?.call(index);
    // Brief confirmation (user asked for it, so this isn't "unprompted")
    speak('$name.');
  }

  // ── Content catalog (poses + breathing) for open-by-name voice commands ───
  List<Map<String, dynamic>> _poses = [];
  List<Map<String, dynamic>> _breathing = [];
  bool _catalogLoading = false;

  /// A screen (Profile) registers this to apply voice health edits.
  void Function(String text)? profileEditHandler;
  void setProfileEditHandler(void Function(String text)? h) =>
      profileEditHandler = h;

  Future<void> _ensureCatalog() async {
    if (_poses.isNotEmpty || _catalogLoading) return;
    _catalogLoading = true;
    try {
      final poses = await ApiService.fetchAllPoses();
      _poses = poses
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final breaths = await ApiService.fetchAllBreathing();
      _breathing = breaths
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {}
    _catalogLoading = false;
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9ऀ-ॿ ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Strip filler words so "open the child pose please" → "child".
  String _stripFiller(String s) {
    const fillers = {
      'open', 'show', 'do', 'the', 'a', 'an', 'please', 'i', 'want', 'to',
      'me', 'let', 'start', 'practice', 'perform', 'demonstrate', 'yoga',
      'pose', 'asana', 'breathing', 'technique', 'pranayama', 'now', 'my',
      'go', 'give', 'tell', 'about', 'info', 'information', 'see', 'view',
    };
    return _norm(s)
        .split(' ')
        .where((w) => w.isNotEmpty && !fillers.contains(w))
        .join(' ')
        .trim();
  }

  Map<String, dynamic>? _bestMatch(
      String spoken, List<Map<String, dynamic>> items) {
    final query = _stripFiller(spoken);
    if (query.isEmpty) return null;
    final qWords = query.split(' ').toSet();
    Map<String, dynamic>? best;
    double bestScore = 0;
    for (final item in items) {
      final nameEn = _norm((item['name']?['en'] ?? '').toString());
      if (nameEn.isEmpty) continue;
      final nameWords = nameEn.split(' ').toSet();
      // word-overlap score
      final overlap = qWords.intersection(nameWords).length;
      double score = overlap.toDouble();
      // strong bonus for full substring match either direction
      if (nameEn.contains(query) || query.contains(nameEn)) score += 3;
      // normalise by name length so short names aren't unfairly favoured
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    // require at least one meaningful word overlap
    return bestScore >= 1 ? best : null;
  }

  // Track what's currently open so an echo of the readout can't re-open it.
  int _openPoseId = -1;
  int _openBreathId = -1;
  void notifyPoseClosed(int id) {
    if (_openPoseId == id) _openPoseId = -1;
  }

  void notifyBreathClosed(int id) {
    if (_openBreathId == id) _openBreathId = -1;
  }

  void _openPose(Map<String, dynamic> pose) {
    final id = pose['id'] is int
        ? pose['id'] as int
        : int.tryParse('${pose['id']}') ?? -1;
    if (id < 0 || id == _openPoseId) return; // ignore repeats / echo
    _openPoseId = id;
    final name = (pose['name']?[langCode] ?? pose['name']?['en'] ?? '').toString();
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => PoseDetailScreen(poseId: id)),
    );
    speak(t("$name opened. Say read for the instructions, or back to return.",
        "$name उघडले. सूचनांसाठी रीड, परत जाण्यासाठी बॅक म्हणा.",
        "$name खुल गया. जानकारी के लिए रीड, वापस के लिए बैक कहें."));
  }

  void _openBreathing(Map<String, dynamic> b) {
    final id = b['id'] is int ? b['id'] as int : int.tryParse('${b['id']}') ?? -1;
    if (id < 0 || id == _openBreathId) return; // ignore repeats / echo
    _openBreathId = id;
    final name = (b['name']?[langCode] ?? b['name']?['en'] ?? '').toString();
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => BreathingDetailScreen(id: id)),
    );
    speak(t(
        "$name opened. Say read to hear how to do it, or start breathing to begin.",
        "$name उघडले. कसे करायचे ऐकण्यासाठी रीड, सुरू करण्यासाठी स्टार्ट ब्रीदिंग म्हणा.",
        "$name खुल गया. कैसे करें सुनने के लिए रीड, शुरू के लिए स्टार्ट ब्रीदिंग कहें."));
  }

  void _startBreathing(Map<String, dynamic>? b) {
    final name = b == null
        ? t('Breathing', 'श्वसन', 'श्वास')
        : (b['name']?[langCode] ?? b['name']?['en'] ?? '').toString();
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => BreathingGuideScreen(techniqueName: name),
      ),
    );
    speak(t("Starting guided breathing. Follow my count. Say stop to end.",
        "मार्गदर्शित श्वसन सुरू. माझ्या मोजणीनुसार करा. थांबवण्यासाठी स्टॉप म्हणा.",
        "गाइडेड श्वास शुरू. मेरी गिनती के साथ करें. रोकने के लिए स्टॉप कहें."));
  }

  Future<void> _speakBreathingList() async {
    await _ensureCatalog();
    if (_breathing.isEmpty) {
      await speak(t("No breathing techniques are available right now.",
          "आत्ता प्राणायाम उपलब्ध नाहीत.", "अभी प्राणायाम उपलब्ध नहीं हैं."));
      return;
    }
    final names = _breathing
        .map((b) => (b['name']?[langCode] ?? b['name']?['en'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .take(8)
        .join(', ');
    await speak(t(
        "Available breathing techniques are: $names. Say open, then the name.",
        "उपलब्ध प्राणायाम: $names. ओपन आणि नाव म्हणा.",
        "उपलब्ध प्राणायाम: $names. ओपन और नाम कहें."));
  }
}
