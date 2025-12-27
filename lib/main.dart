import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. The TTS Engine
  final FlutterTts flutterTts = FlutterTts();

  // 2. The list of phrases (Starts with some examples)
  List<String> phrases = [
    "Hello!",
    "How are you?",
    "I need help",
    "Thank you",
    "Yes",
    "No"
  ];

  // Controller to read text from the dialog box
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  // Setup the voice engine settings
  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0); // 1.0 is natural voice
    await flutterTts.setSpeechRate(0.5); // 0.5 is a comfortable speed
  }

  // Function to speak the text
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  // Function to add a new button
  void _addPhrase(String text) {
    if (text.isNotEmpty) {
      setState(() {
        phrases.add(text);
      });
      _textController.clear();
      Navigator.of(context).pop(); // Close the dialog
    }
  }

  // Function to delete a phrase (Long press to delete)
  void _deletePhrase(int index) {
    setState(() {
      phrases.removeAt(index);
    });
  }

  // The Dialog Box Popup
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Phrase"),
        content: TextField(
          controller: _textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "What do you want to say?"),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => _addPhrase(_textController.text),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TapTalk"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _speak("TapTalk is ready"),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 Buttons per row
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5, // Make them rectangular
          ),
          itemCount: phrases.length,
          itemBuilder: (context, index) {
            return Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _speak(phrases[index]),
                onLongPress: () => _deletePhrase(index), // Long press to delete
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      phrases[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
        label: const Text("Add Phrase"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}