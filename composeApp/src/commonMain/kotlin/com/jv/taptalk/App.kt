// FILE: shared/src/commonMain/kotlin/App.kt
package com.taptalk.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// 1. LIBRARIES IMPORTS
import nl.marc_apps.tts.compose.rememberTextToSpeechOrNull
import network.chaintech.cmpmediaplayer.ui.AudioPlayer
import okio.FileSystem
import okio.Path.Companion.toPath
import okio.SystemTemporaryDirectory

// ==========================================
// 1. DATA MODEL
// ==========================================
data class Phrase(
    val id: String,
    val text: String,
    val localAudioPath: String? = null,
    val isLoadingAi: Boolean = false
)

// ==========================================
// 2. MAIN APP ENTRY POINT
// ==========================================
@Composable
fun App() {
    // A. Init Libraries
    val tts = rememberTextToSpeechOrNull()
    
    // B. State & ViewModel
    // Note: In a real app, use Koin/Kodein to inject the ViewModel. 
    // Here we create it directly, passing Okio's FileSystem.
    val viewModel = remember { TapTalkViewModel() }
    val phrases = viewModel.phrases
    val audioState by viewModel.audioPlaybackState.collectAsState()
    
    var showDialog by remember { mutableStateOf(false) }

    MaterialTheme {
        Scaffold(
            topBar = { TopAppBar(title = { Text("Tap Talk") }) },
            floatingActionButton = {
                FloatingActionButton(onClick = { showDialog = true }) {
                    Icon(Icons.Default.Add, contentDescription = "Add Phrase")
                }
            }
        ) { padding ->
            Box(modifier = Modifier.padding(padding)) {
                
                // C. THE MEDIA PLAYER (Invisible, logic driven)
                // When ViewModel sets a URL, this component plays it.
                if (audioState != null) {
                   // Using Chaintech's AudioPlayer
                   // We render it with 0 size since we only want audio
                   Box(modifier = Modifier.size(0.dp)) {
                       AudioPlayer(
                           url = audioState!!,
                           isPause = false, // Auto-play when URL is set
                           modifier = Modifier.size(0.dp)
                       )
                   }
                }

                // D. THE GRID
                PhraseGrid(
                    phrases = phrases,
                    onTap = { phrase ->
                        // Delegate logic to ViewModel, passing a callback for System TTS
                        viewModel.onPhraseTapped(
                            phrase = phrase,
                            onSystemTtsRequired = { textToSpeak ->
                                tts?.speak(textToSpeak)
                            }
                        )
                    }
                )

                // E. ADD DIALOG
                if (showDialog) {
                    AddPhraseDialog(
                        onDismiss = { showDialog = false },
                        onConfirm = { text ->
                            viewModel.addPhrase(text)
                            showDialog = false
                        }
                    )
                }
            }
        }
    }
}

// ==========================================
// 3. UI COMPONENTS
// ==========================================
@Composable
fun PhraseGrid(phrases: List<Phrase>, onTap: (Phrase) -> Unit) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        items(phrases) { phrase ->
            Card(
                elevation = 4.dp,
                shape = RoundedCornerShape(16.dp),
                // Green background if we have the High Quality file ready
                backgroundColor = if (phrase.localAudioPath != null) Color(0xFFE8F5E9) else Color.White,
                modifier = Modifier
                    .height(140.dp)
                    .clickable { onTap(phrase) }
            ) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(8.dp)) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = phrase.text,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center
                        )
                        if (phrase.isLoadingAi) {
                            Spacer(Modifier.height(8.dp))
                            CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun AddPhraseDialog(onDismiss: () -> Unit, onConfirm: (String) -> Unit) {
    var text by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("New Phrase") },
        text = {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                label = { Text("Enter text to speak") }
            )
        },
        confirmButton = {
            Button(onClick = { if (text.isNotBlank()) onConfirm(text) }) {
                Text("Add")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

// ==========================================
// 4. VIEW MODEL (Logic with Okio)
// ==========================================
class TapTalkViewModel {
    // Okio File System (Works on Android/iOS/Desktop)
    private val fileSystem = FileSystem.SYSTEM
    private val storageDir = FileSystem.SYSTEM_TEMPORARY_DIRECTORY 
    
    // Services
    private val gemini = GeminiService()

    // State
    var phrases = mutableStateListOf<Phrase>(
        Phrase("1", "Hello!"),
        Phrase("2", "I am hungry"),
        Phrase("3", "Thank you")
    )

    // Holds the URL for the AudioPlayer to play
    private val _audioPlaybackState = kotlinx.coroutines.flow.MutableStateFlow<String?>(null)
    val audioPlaybackState = _audioPlaybackState

    fun addPhrase(text: String) {
        val newPhrase = Phrase(id = "${System.currentTimeMillis()}", text = text)
        phrases.add(newPhrase)
        upgradeToGemini(newPhrase)
    }

    fun onPhraseTapped(phrase: Phrase, onSystemTtsRequired: (String) -> Unit) {
        if (phrase.localAudioPath != null) {
            // 1. Play High Quality File using Chaintech Player
            // We verify the file exists via Okio before playing
            val path = phrase.localAudioPath.toPath()
            if (fileSystem.exists(path)) {
                // Determine absolute path string based on platform if needed, 
                // but usually Okio path string works or needs prefix "file://"
                _audioPlaybackState.value = "file://$path" 
            } else {
                // File missing? Fallback.
                onSystemTtsRequired(phrase.text)
            }
        } else {
            // 2. Play Robotic System TTS (Instant)
            onSystemTtsRequired(phrase.text)

            // 3. Trigger upgrade if not already loading
            if (!phrase.isLoadingAi) {
                upgradeToGemini(phrase)
            }
        }
    }

    private fun upgradeToGemini(phrase: Phrase) {
        updatePhrase(phrase.id) { it.copy(isLoadingAi = true) }

        // Launch background job
        kotlinx.coroutines.CoroutineScope(Dispatchers.IO).launch {
            try {
                // A. Fetch Audio Bytes from Gemini
                val audioBytes = gemini.fetchTts(phrase.text)
                
                // B. Save to Disk using OKIO
                val fileName = "${phrase.id}.mp3"
                val filePath = storageDir / fileName
                
                fileSystem.write(filePath) {
                    write(audioBytes)
                }

                // C. Update UI
                withContext(Dispatchers.Main) {
                    updatePhrase(phrase.id) { 
                        it.copy(localAudioPath = filePath.toString(), isLoadingAi = false) 
                    }
                }
            } catch (e: Exception) {
                println("Gemini Upgrade Failed: ${e.message}")
                withContext(Dispatchers.Main) {
                    updatePhrase(phrase.id) { it.copy(isLoadingAi = false) }
                }
            }
        }
    }
    
    private fun updatePhrase(id: String, update: (Phrase) -> Phrase) {
        val index = phrases.indexOfFirst { it.id == id }
        if (index != -1) {
            phrases[index] = update(phrases[index])
        }
    }
}

// ==========================================
// 5. MOCK NETWORK SERVICE
// ==========================================
class GeminiService {
    suspend fun fetchTts(text: String): ByteArray {
        // Replace with actual Ktor + Gemini 2.5/3.0 API logic
        kotlinx.coroutines.delay(1500) 
        // Returning empty bytes for demo purposes
        return ByteArray(0) 
    }
}