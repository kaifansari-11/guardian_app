import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

// Custom Services
import '../services/audio_recorder_service.dart';
import '../services/storage_service.dart';
import '../services/fullscreen_alert_service.dart';

// Screens
import 'login_screen.dart';
import 'trusted_contacts_screen.dart';
import 'settings_screen.dart';
import 'disguise_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // --- STATE VARIABLES ---
  bool _isMasterEnabled = false; // The switch on the Home Screen
  bool _isSOSActive = false;
  bool _isInitialLoading = true;

  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _playerStateSubscription;
  Timer? _recordingLoopTimer;
  Timer? _sirenWatchdog;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorderService _recorder = AudioRecorderService();
  final StorageService _storageService = StorageService();

  static const double shakeThreshold = 15.0;
  double _requiredDuration = 3.0;
  DateTime? _shakeStartTime;
  DateTime? _lastShakeTime;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _configureAudioSession();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (_isSOSActive && state != PlayerState.playing) {
        _audioPlayer.resume();
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _initializeScreen();
      }
    });
  }

  Future<void> _configureAudioSession() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Audio Config Error: $e");
    }
  }

  Future<void> _initializeScreen() async {
    await _requestStandardPermissions();
    await _checkServiceStatus();
    await _loadSettings();
    _startForegroundShakeDetection();

    if (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      await _checkOverlayPermission();
    }

    FlutterBackgroundService().on('service_status').listen((event) {
      if (mounted && event != null) {
        bool running = event['isRunning'] ?? false;
        if (_isMasterEnabled != running) {
          setState(() => _isMasterEnabled = running);
        }
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    bool sosActive = prefs.getBool('is_sos_active') ?? false;
    bool smsHandledByBg = prefs.getBool('sms_sent_by_background') ?? false;

    if (sosActive && !_isSOSActive) {
      if (smsHandledByBg) {
        _triggerUISOSOnly();
      } else {
        _sendSOS();
      }
    }

    FlutterBackgroundService().on('shake_detected').listen((event) {
      if (!_isSOSActive) {
        _sendSOS();
      }
    });
  }

  Future<void> _triggerUISOSOnly() async {
    if (mounted) setState(() => _isSOSActive = true);
    final prefs = await SharedPreferences.getInstance();
    _startLiveLocationTracking();
    if (prefs.getBool('siren_enabled') ?? true) {
      await _playSiren();
      _startSirenWatchdog();
    }
    if (prefs.getBool('disguise_enabled') ?? false) {
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const DisguiseScreen()));
      }
    }
    _startRecordingLoop();
    if (prefs.getBool('call_112_enabled') ?? true) {
      _callEmergency();
    }
  }

  Future<void> _requestStandardPermissions() async {
    await [
      Permission.location,
      Permission.sms,
      Permission.phone,
      Permission.notification,
      Permission.microphone,
    ].request();
  }

  Future<void> _checkOverlayPermission() async {
    try {
      if (!await Permission.systemAlertWindow.isGranted) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Permission Required"),
              content: const Text(
                "To show alerts from the background, Guardian needs permission to 'Display Over Other Apps'.",
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Permission.systemAlertWindow.request();
                  },
                  child: const Text(
                    "Open Settings",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Overlay Error: $e");
    }
  }

  Future<void> _checkServiceStatus() async {
    try {
      bool isRunning = await FlutterBackgroundService().isRunning();
      if (mounted) {
        setState(() {
          _isMasterEnabled = isRunning;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _toggleService() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
    } else {
      service.startService();
    }
    if (mounted) {
      setState(() => _isMasterEnabled = !isRunning);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await prefs.setString('user_uid', user.uid);
      _syncContactsToDisk(user.uid);
    }
    if (mounted) {
      setState(() {
        _requiredDuration = prefs.getDouble('shake_duration') ?? 3.0;
      });
    }
  }

  Future<void> _syncContactsToDisk(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('contacts')
          .get();
      List<String> phoneNumbers = snapshot.docs
          .map((doc) => doc['phone'].toString())
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('contact_phones', phoneNumbers);
    } catch (e) {
      debugPrint("Error syncing contacts: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _accelerometerSubscription?.cancel();
    _locationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _recordingLoopTimer?.cancel();
    _sirenWatchdog?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startForegroundShakeDetection() {
    _accelerometerSubscription = accelerometerEventStream().listen((
      event,
    ) async {
      if (!_isMasterEnabled) return;

      // NEW LOGIC: Check if shake is actually enabled in Settings
      final prefs = await SharedPreferences.getInstance();
      bool shakeSettingOn = prefs.getBool('shake_feature_enabled') ?? true;
      if (!shakeSettingOn) return;

      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (acceleration > shakeThreshold) {
        DateTime now = DateTime.now();
        if (_shakeStartTime == null ||
            (_lastShakeTime != null &&
                now.difference(_lastShakeTime!).inMilliseconds > 500)) {
          _shakeStartTime = now;
        }
        _lastShakeTime = now;
        if (now.difference(_shakeStartTime!).inMilliseconds >
            (_requiredDuration * 1000)) {
          _shakeStartTime = null;
          _sendSOS();
        }
      }
    });
  }

  void _startLiveLocationTracking() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'location': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'timestamp': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));
        });
  }

  void _stopLiveLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  Future<void> _startRecordingLoop() async {
    await _recorder.startRecording();
    if (_isSOSActive) _audioPlayer.resume();
    _recordingLoopTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      String? filePath = await _recorder.stopRecording();
      await Future.delayed(const Duration(milliseconds: 200));
      await _recorder.startRecording();
      if (_isSOSActive) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('siren_enabled') ?? true) await _audioPlayer.resume();
      }
      if (filePath != null) _uploadEvidence(filePath);
    });
  }

  void _startSirenWatchdog() {
    _sirenWatchdog?.cancel();
    _sirenWatchdog = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isSOSActive) {
        timer.cancel();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool('siren_enabled') ?? true) &&
          _audioPlayer.state != PlayerState.playing) {
        _audioPlayer.resume();
      }
    });
  }

  Future<void> _uploadEvidence(String filePath) async {
    String? downloadUrl = await _storageService.uploadAudio(filePath);
    final User? user = FirebaseAuth.instance.currentUser;
    if (downloadUrl != null && user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('audios')
          .add({
            'url': downloadUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'auto_chunk_15s',
          });
    }
  }

  Future<void> _sendSOS() async {
    if (_isSOSActive) return;
    if (mounted) setState(() => _isSOSActive = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sos_active', true);
    await FullScreenAlertService.showFullScreenAlert();
    if (prefs.getBool('disguise_enabled') ?? false) {
      if (mounted)
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const DisguiseScreen()));
    }
    _startLiveLocationTracking();
    if (prefs.getBool('siren_enabled') ?? true) {
      await _playSiren();
      _startSirenWatchdog();
    }
    await Future.delayed(const Duration(milliseconds: 1500));
    _startRecordingLoop();
    _sendSMSAlerts();
    if (prefs.getBool('call_112_enabled') ?? true) _callEmergency();
  }

  Future<void> _stopSOS() async {
    try {
      _isSOSActive = false;
      if (mounted) setState(() => _isSOSActive = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_sos_active', false);
      await prefs.setBool('sms_sent_by_background', false);
      _recordingLoopTimer?.cancel();
      _recordingLoopTimer = null;
      _sirenWatchdog?.cancel();
      _sirenWatchdog = null;
      await _audioPlayer.stop();
      await _audioPlayer.release();
      _stopLiveLocationTracking();
      if (_recorder.isRecording) {
        String? filePath = await _recorder.stopRecording();
        if (filePath != null) await _uploadEvidence(filePath);
      }
    } catch (e) {
      debugPrint("Stop SOS Error: $e");
    }
  }

  Future<void> _playSiren() async {
    try {
      if (_audioPlayer.state == PlayerState.playing) return;
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setSource(AssetSource('siren.mp3'));
      await _audioPlayer.resume();
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Siren Error: $e");
    }
  }

  Future<void> _callEmergency() async {
    try {
      final Uri launchUri = Uri(scheme: 'tel', path: '112');
      if (await canLaunchUrl(launchUri))
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Call Error: $e");
    }
  }

  Future<void> _sendSMSAlerts() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String dashboardLink = "https://guardian-live.netlify.app/?uid=${user.uid}";
    String message = "HELP! I am in danger! Track me LIVE here: $dashboardLink";
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .get();
      for (var doc in snapshot.docs) {
        String phone = doc['phone'];
        await Telephony.instance.sendSms(to: phone, message: message);
      }
    } catch (e) {
      debugPrint("SMS Error: $e");
    }
  }

  Future<void> _logout() async {
    await _stopSOS();
    final service = FlutterBackgroundService();
    if (await service.isRunning()) service.invoke("stopService");
    await FirebaseAuth.instance.signOut();
    if (mounted)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    // --- DYNAMIC DESIGN ---
    Color bgColorTop;
    Color bgColorBottom;
    Color pulseColor;
    Color buttonColor;
    Color textColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;
    double iconOpacity;

    if (_isSOSActive) {
      bgColorTop = Colors.red.shade900;
      bgColorBottom = Colors.black;
      pulseColor = Colors.redAccent;
      buttonColor = Colors.white;
      textColor = Colors.white;
      statusTitle = "EMERGENCY ACTIVE";
      statusSubtitle = "Broadcasting Live Evidence";
      statusIcon = Icons.warning_amber_rounded;
      iconOpacity = 1.0;
    } else if (_isMasterEnabled) {
      // SYSTEM ON: SOS button will work
      bgColorTop = const Color(0xFF064E3B);
      bgColorBottom = const Color(0xFF10B981);
      pulseColor = const Color(0xFF34D399);
      buttonColor = Colors.deepOrangeAccent;
      textColor = Colors.white;
      statusTitle = "GUARDIAN READY";
      statusSubtitle = "Manual SOS Available";
      statusIcon = Icons.shield_rounded;
      iconOpacity = 1.0;
    } else {
      // SYSTEM OFF: Everything disabled
      bgColorTop = const Color(0xFF0F172A);
      bgColorBottom = Colors.black;
      pulseColor = Colors.grey.shade800;
      buttonColor = Colors.grey.shade900;
      textColor = Colors.white38;
      statusTitle = "SYSTEM PAUSED";
      statusSubtitle = "Tap Switch to Activate";
      statusIcon = Icons.power_settings_new;
      iconOpacity = 0.3;
    }

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgColorTop, bgColorBottom],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 50),
                      Text(
                        "GUARDIAN",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor.withOpacity(0.9),
                          letterSpacing: 4,
                        ),
                      ),
                      _buildGlassIconButton(Icons.settings, () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                        _checkServiceStatus();
                        _loadSettings();
                      }, iconOpacity),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ScaleTransition(
                      scale: (_isMasterEnabled || _isSOSActive)
                          ? _pulseAnimation
                          : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        padding: const EdgeInsets.all(35),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pulseColor.withOpacity(0.15),
                          border: Border.all(
                            color: pulseColor.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            if (_isMasterEnabled || _isSOSActive)
                              BoxShadow(
                                color: pulseColor.withOpacity(0.5),
                                blurRadius: 60,
                                spreadRadius: 15,
                              ),
                          ],
                        ),
                        child: Icon(
                          statusIcon,
                          size: 90,
                          color: _isMasterEnabled || _isSOSActive
                              ? Colors.white
                              : pulseColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      statusTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 40,
                    left: 30,
                    right: 30,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isSOSActive
                            ? _stopSOS
                            : (_isMasterEnabled ? _sendSOS : null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: double.infinity,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: buttonColor,
                            boxShadow: [
                              if (_isMasterEnabled || _isSOSActive)
                                BoxShadow(
                                  color: buttonColor.withOpacity(0.4),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _isSOSActive ? "STOP EMERGENCY" : "TAP FOR SOS",
                              style: TextStyle(
                                color: _isSOSActive
                                    ? Colors.red.shade900
                                    : (_isMasterEnabled
                                          ? Colors.white
                                          : Colors.white10),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 35),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch.adaptive(
                              value: _isMasterEnabled,
                              onChanged: (_) => _toggleService(),
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF10B981),
                              inactiveThumbColor: Colors.blueGrey,
                              inactiveTrackColor: Colors.white10,
                            ),
                            const SizedBox(width: 15),
                            Text(
                              _isMasterEnabled ? "SYSTEM ACTIVE" : "SYSTEM OFF",
                              style: TextStyle(
                                color: _isMasterEnabled
                                    ? Colors.white
                                    : Colors.white30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton(
    IconData icon,
    VoidCallback onTap,
    double opacity,
  ) {
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
