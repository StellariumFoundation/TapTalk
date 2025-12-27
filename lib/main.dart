import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TapTalkApp());
}

class TapTalkApp extends StatelessWidget {
  const TapTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00BFA6),
          surface: Color(0xFF1E1E2C),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2D2D44),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// GRADIENT BACKGROUND
// ---------------------------------------------------------------------------
class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E), // Dark Navy
            Color(0xFF16213E), // Deep Blue
            Color(0xFF240046), // Deep Purple
          ],
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  
  List<String> phrases = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Helper to fix the crash with Map types
  Map<String, String> _safeVoiceMap(Map<dynamic, dynamic> voice) {
    final Map<String, String> safeMap = {};
    voice.forEach((key, value) {
      safeMap[key.toString()] = value.toString();
    });
    return safeMap;
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // ---------------------------------------------------------
    // 1. LOAD PHRASES FIRST (Priority)
    // ---------------------------------------------------------
    // We load this first so even if TTS fails, your data is safe.
    List<String>? savedPhrases = prefs.getStringList('saved_phrases');
    if (savedPhrases != null) {
      setState(() => phrases = savedPhrases);
    }

    // ---------------------------------------------------------
    // 2. LOAD VOICE SETTINGS
    // ---------------------------------------------------------
    try {
      double pitch = prefs.getDouble('pitch') ?? 1.0;
      double rate = prefs.getDouble('rate') ?? 0.5;
      String? language = prefs.getString('language') ?? "en-US";
      String? voiceJson = prefs.getString('voice');

      await flutterTts.setPitch(pitch);
      await flutterTts.setSpeechRate(rate);
      await flutterTts.setLanguage(language);

      if (voiceJson != null) {
        Map<String, dynamic> voiceMap = jsonDecode(voiceJson);
        await flutterTts.setVoice(_safeVoiceMap(voiceMap));
      }

      // iOS Audio Setup
      await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          ],
      );
    } catch (e) {
      print("Error loading voice settings: $e");
      // App continues running even if voice loading fails
    }
  }

  Future<void> _savePhrases() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_phrases', phrases);
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _addPhrase(String text) async {
    if (text.isNotEmpty) {
      setState(() => phrases.add(text));
      await _savePhrases(); // Wait for save
      _textController.clear();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _deletePhrase(int index) async {
    setState(() => phrases.removeAt(index));
    await _savePhrases(); // Wait for save
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252540),
        title: const Text("New Phrase", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: "What do you want to say?"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () => _addPhrase(_textController.text),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(tts: flutterTts)),
    );
    _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("TapTalk", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.4,
            ),
            itemCount: phrases.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3A86FF), // Blue
                      Color(0xFF8338EC), // Purple
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _speak(phrases[index]),
                    onLongPress: () => _deletePhrase(index),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          phrases[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))
                            ]
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: const Color(0xFF00BFA6),
          label: const Text("Add Phrase", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS SCREEN
// ---------------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  final FlutterTts tts;
  const SettingsScreen({super.key, required this.tts});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _pitch = 1.0;
  double _rate = 0.5;
  String _language = "en-US";
  List<String> _languages = [];
  List<Map<String, dynamic>> _voices = []; 
  List<Map<String, dynamic>> _filteredVoices = []; 
  Map<String, dynamic>? _selectedVoice;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Map<String, String> _safeVoiceMap(Map<dynamic, dynamic> voice) {
    final Map<String, String> safeMap = {};
    voice.forEach((key, value) {
      safeMap[key.toString()] = value.toString();
    });
    return safeMap;
  }

  Future<void> _initSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get languages
    var langs = await widget.tts.getLanguages;
    
    // Get voices
    var rawVoices = await widget.tts.getVoices;
    List<Map<String, dynamic>> parsedVoices = [];
    if (rawVoices != null) {
      for (var v in rawVoices) {
        parsedVoices.add(Map<String, dynamic>.from(v as Map));
      }
    }

    String? savedVoiceJson = prefs.getString('voice');
    Map<String, dynamic>? loadedVoice;
    if (savedVoiceJson != null) {
      try {
        loadedVoice = jsonDecode(savedVoiceJson);
      } catch (e) { /* ignore */ }
    }

    double savedPitch = prefs.getDouble('pitch') ?? 1.0;
    double savedRate = prefs.getDouble('rate') ?? 0.5;
    String savedLang = prefs.getString('language') ?? "en-US";

    if (mounted) {
      setState(() {
        _languages = List<String>.from(langs);
        _voices = parsedVoices;
        _pitch = savedPitch;
        _rate = savedRate;
        _language = savedLang;
        _selectedVoice = loadedVoice;
        _filterVoices();
      });
    }
  }

  void _filterVoices() {
    if (!mounted) return;
    setState(() {
      _filteredVoices = _voices.where((voice) {
        String locale = voice['locale'].toString();
        return locale.contains(_language) || _language.contains(locale);
      }).toList();

      if (_selectedVoice != null) {
        String voiceLocale = _selectedVoice!['locale'].toString();
        if (!voiceLocale.contains(_language) && !_language.contains(voiceLocale)) {
          _selectedVoice = null;
        }
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble('pitch', _pitch);
    await prefs.setDouble('rate', _rate);
    await prefs.setString('language', _language);
    
    if (_selectedVoice != null) {
      await prefs.setString('voice', jsonEncode(_selectedVoice));
      await widget.tts.setVoice(_safeVoiceMap(_selectedVoice!));
    }
    
    await widget.tts.setPitch(_pitch);
    await widget.tts.setSpeechRate(_rate);
    await widget.tts.setLanguage(_language);
  }

  Future<void> _testConfiguration() async {
    await _saveSettings();
    await widget.tts.speak("Hello, this is my new voice.");
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Settings"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Language"),
                _buildContainer(
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2D2D44),
                      style: const TextStyle(color: Colors.white),
                      value: _languages.contains(_language) ? _language : null,
                      hint: const Text("Select Language", style: TextStyle(color: Colors.grey)),
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _language = val;
                            _filterVoices(); 
                          });
                          _saveSettings();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
          
                _buildSectionTitle("Specific Voice"),
                _buildContainer(
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2D2D44),
                      style: const TextStyle(color: Colors.white),
                      value: _filteredVoices.contains(_selectedVoice) ? _selectedVoice : null,
                      hint: _filteredVoices.isEmpty 
                          ? const Text("No voices found", style: TextStyle(color: Colors.grey)) 
                          : const Text("Default Voice", style: TextStyle(color: Colors.grey)),
                      items: _filteredVoices.map((voice) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: voice,
                          child: Text(voice['name'] ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedVoice = val);
                        _saveSettings();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
          
                _buildSectionTitle("Speed: ${_rate.toStringAsFixed(1)}"),
                _buildSlider(_rate, 0.0, 1.0, (val) {
                   setState(() => _rate = val);
                   _saveSettings();
                }),
                
                _buildSectionTitle("Pitch: ${_pitch.toStringAsFixed(1)}"),
                _buildSlider(_pitch, 0.5, 2.0, (val) {
                   setState(() => _pitch = val);
                   _saveSettings();
                }),
          
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _testConfiguration,
                    icon: const Icon(Icons.volume_up),
                    label: const Text("TEST CONFIGURATION", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 5),
      child: Text(
        title.toUpperCase(), 
        style: const TextStyle(
          color: Colors.white70, 
          fontSize: 14, 
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildSlider(double value, double min, double max, Function(double) onChanged) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFF6C63FF),
        thumbColor: const Color(0xFF00BFA6),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: 15,
        onChanged: onChanged,
      ),
    );
  }
}