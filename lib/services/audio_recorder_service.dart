import 'dart:io';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart'; // <--- NEW IMPORT

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // Start Recording (Now with Mic Priority Logic)
  Future<void> startRecording() async {
    try {
      // 1. Check basic permission
      if (await _audioRecorder.hasPermission()) {
        // --- NEW CODE: REQUEST PRIORITY FROM ANDROID ---
        final session = await AudioSession.instance;
        await session.configure(
          const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.allowBluetooth,
            avAudioSessionMode: AVAudioSessionMode.voiceChat,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.speech,
              // "voiceCommunication" is higher priority than "Assistant"
              usage: AndroidAudioUsage.voiceCommunication,
            ),
            // "gainTransient" means: "Interrupt others (like Google) for a short time"
            androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          ),
        );

        // 2. Activate the session (This pauses Google Assistant)
        if (await session.setActive(true)) {
          // 3. Prepare File Path
          final directory = await getApplicationDocumentsDirectory();
          String filePath =
              '${directory.path}/evidence_${DateTime.now().millisecondsSinceEpoch}.m4a';

          // 4. Start Recording
          await _audioRecorder.start(const RecordConfig(), path: filePath);
          _isRecording = true;
          debugPrint(
            "🎙️ Audio Recording Started (Priority Secured): $filePath",
          );
        } else {
          debugPrint("⚠️ Failed to get microphone priority from Android.");
        }
      }
    } catch (e) {
      debugPrint("Error starting recorder: $e");
    }
  }

  // Stop Recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      // 1. Stop the actual recording
      final path = await _audioRecorder.stop();
      _isRecording = false;

      // 2. RELEASE PRIORITY (Let Google Assistant work again)
      final session = await AudioSession.instance;
      await session.setActive(false);

      debugPrint("🛑 Audio Recording Stopped. Saved to: $path");
      return path;
    } catch (e) {
      debugPrint("Error stopping recorder: $e");
      return null;
    }
  }

  // Check status
  bool get isRecording => _isRecording;
}
