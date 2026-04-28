import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// Import your existing screens
import 'trusted_contacts_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // State Variables
  double _shakeDuration = 3.0;
  bool _isServiceRunning = false;
  bool _isShakeFeatureOn = true;
  bool _isDarkMode = false;

  // Toggles
  bool _isSirenEnabled = true;
  bool _isCallEnabled = true;
  bool _isDisguiseEnabled = false;

  String _currentMode = 'Custom';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkServiceStatus();
  }

  // --- UPDATED HELP CONTENT MAPPING ---
  final Map<String, String> _helpContent = {
    "Appearance":
        "Dark Mode changes the app's theme to a darker color palette, which is easier on the eyes in low-light environments and saves battery.",
    "Trusted Contacts":
        "These are the people who will receive an SMS with your live location link whenever you trigger an SOS.",
    "Master Protection":
        "The main switch for the background engine. If this is OFF, the app will not monitor for shakes or safety tasks.",
    "Shake Response":
        "When enabled, you can trigger an emergency alert by shaking your phone. Adjust the timer to prevent accidental triggers.",
    "Quick Modes Info":
        "• LOUD: Maximum visibility. Plays siren and opens emergency dialer.\n\n• GHOST: Stealth mode. Silent trigger and shows a fake black screen to hide the app.\n\n• CUSTOM: Your personal settings. Change toggles manually below.",
    "Disguise Mode":
        "Shows a completely black screen on SOS, making the phone look like it is turned off to hide your activity from attackers.",
    "Play Siren":
        "Triggers a high-volume police siren from your phone to attract help and scare off attackers.",
    "Auto-Call 112":
        "Automatically opens your phone's dialer with the emergency number pre-filled for a one-tap call.",
  };

  void _showHelp(String title, String key) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              _helpContent[key] ?? "Information not available.",
              style: TextStyle(
                fontSize: 15,
                color: _isDarkMode ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildCard(Color cardBg, {required Widget child}) => Container(
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _buildSectionTitle(String title, Color textColor, {String? helpKey}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
            if (helpKey != null)
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.grey,
                ),
                onPressed: () => _showHelp(title, helpKey),
              ),
          ],
        ),
      );

  // --- CORE LOGIC ---
  Future<void> _checkServiceStatus() async {
    bool isRunning = await FlutterBackgroundService().isRunning();
    if (mounted) setState(() => _isServiceRunning = isRunning);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _shakeDuration = prefs.getDouble('shake_duration') ?? 3.0;
        _isSirenEnabled = prefs.getBool('siren_enabled') ?? true;
        _isCallEnabled = prefs.getBool('call_112_enabled') ?? true;
        _isDisguiseEnabled = prefs.getBool('disguise_enabled') ?? false;
        _isShakeFeatureOn = prefs.getBool('shake_feature_enabled') ?? true;
        _isDarkMode = prefs.getBool('dark_mode_enabled') ?? false;
        _currentMode = prefs.getString('safety_mode') ?? 'Custom';
      });
    }
  }

  Future<void> _toggleService(bool value) async {
    final service = FlutterBackgroundService();
    value ? await service.startService() : service.invoke("stopService");
    setState(() => _isServiceRunning = value);
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', value);
    setState(() => _isDarkMode = value);
  }

  Future<void> _setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentMode = mode);
    await prefs.setString('safety_mode', mode);
    if (mode == 'Loud') {
      await _updateToggle('siren_enabled', true);
      await _updateToggle('call_112_enabled', true);
      await _updateToggle('disguise_enabled', false);
    } else if (mode == 'Ghost') {
      await _updateToggle('siren_enabled', false);
      await _updateToggle('call_112_enabled', false);
      await _updateToggle('disguise_enabled', true);
    }
  }

  Future<void> _updateToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'siren_enabled') _isSirenEnabled = value;
      if (key == 'call_112_enabled') _isCallEnabled = value;
      if (key == 'disguise_enabled') _isDisguiseEnabled = value;
    });
  }

  Future<void> _manualToggle(String key, bool value) async {
    await _updateToggle(key, value);
    if (_currentMode != 'Custom') {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _currentMode = 'Custom');
      await prefs.setString('safety_mode', 'Custom');
    }
  }

  Future<void> _logout() async {
    await _toggleService(false);
    await FirebaseAuth.instance.signOut();
    if (mounted)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBg = _isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color cardBg = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = _isDarkMode
        ? Colors.white
        : Colors.blueGrey.shade700;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- APPEARANCE ---
            _buildSectionTitle("Appearance", textColor, helpKey: "Appearance"),
            _buildCard(
              cardBg,
              child: SwitchListTile(
                secondary: Icon(
                  Icons.dark_mode,
                  color: _isDarkMode ? Colors.yellow : Colors.grey,
                ),
                title: Text(
                  "Dark Mode",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                value: _isDarkMode,
                activeColor: Colors.redAccent,
                onChanged: _toggleDarkMode,
              ),
            ),

            const SizedBox(height: 30),

            // --- TRUSTED CONTACTS ---
            _buildSectionTitle(
              "Emergency Contacts",
              textColor,
              helpKey: "Trusted Contacts",
            ),
            _buildCard(
              cardBg,
              child: ListTile(
                leading: const Icon(Icons.people_alt, color: Colors.blue),
                title: Text(
                  "Trusted Contacts",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  "Manage SOS recipients",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white60 : Colors.grey,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrustedContactsScreen(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- MASTER PROTECTION ---
            _buildSectionTitle(
              "System Status",
              textColor,
              helpKey: "Master Protection",
            ),
            _buildCard(
              cardBg,
              child: SwitchListTile(
                secondary: Icon(
                  Icons.power_settings_new,
                  color: _isServiceRunning ? Colors.green : Colors.grey,
                ),
                title: Text(
                  "Master Protection",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  _isServiceRunning ? "Module is Running" : "Module is Offline",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white60 : Colors.grey,
                  ),
                ),
                value: _isServiceRunning,
                activeColor: Colors.green,
                onChanged: _toggleService,
              ),
            ),

            const SizedBox(height: 30),

            // --- SHAKE DETECTION ---
            _buildSectionTitle(
              "Shake Detection",
              textColor,
              helpKey: "Shake Response",
            ),
            _buildCard(
              cardBg,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      Icons.vibration,
                      color: _isShakeFeatureOn ? Colors.orange : Colors.grey,
                    ),
                    title: Text(
                      "Shake Response",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    value: _isShakeFeatureOn,
                    onChanged: (v) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('shake_feature_enabled', v);
                      setState(() => _isShakeFeatureOn = v);
                    },
                  ),
                  if (_isShakeFeatureOn) ...[
                    const Divider(indent: 70),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Shake Time",
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              Text(
                                "${_shakeDuration.toStringAsFixed(0)}s",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _shakeDuration,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            activeColor: Colors.redAccent,
                            onChanged: (v) async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setDouble('shake_duration', v);
                              setState(() => _shakeDuration = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- QUICK MODES: HELP KEY CHANGED TO SHOW ALL MODES ---
            _buildSectionTitle(
              "Quick Modes",
              textColor,
              helpKey: "Quick Modes Info",
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildModeCard(
                  "Loud",
                  Icons.volume_up,
                  Colors.redAccent,
                  "Siren+Call",
                  cardBg,
                ),
                _buildModeCard(
                  "Ghost",
                  Icons.visibility_off,
                  Colors.blueGrey,
                  "Silent",
                  cardBg,
                ),
                _buildModeCard(
                  "Custom",
                  Icons.tune,
                  Colors.blueAccent,
                  "Manual",
                  cardBg,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- RESPONSE FEATURES: REMOVED HELP BUTTON FROM TITLE ---
            _buildSectionTitle("Response Features", textColor),
            _buildCard(
              cardBg,
              child: Column(
                children: [
                  _buildConfigTile(
                    "Disguise Mode",
                    "Black screen on SOS",
                    Icons.masks,
                    Colors.purple,
                    _isDisguiseEnabled,
                    (v) => _manualToggle('disguise_enabled', v),
                    _isDarkMode,
                  ),
                  const Divider(height: 1, indent: 70),
                  _buildConfigTile(
                    "Play Siren",
                    "Trigger loud alarm",
                    Icons.notifications_active,
                    Colors.orange,
                    _isSirenEnabled,
                    (v) => _manualToggle('siren_enabled', v),
                    _isDarkMode,
                  ),
                  const Divider(height: 1, indent: 70),
                  _buildConfigTile(
                    "Auto-Call 112",
                    "Emergency dialer",
                    Icons.phone_forwarded,
                    Colors.green,
                    _isCallEnabled,
                    (v) => _manualToggle('call_112_enabled', v),
                    _isDarkMode,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- LOGOUT ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("Logout from Guardian"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    String mode,
    IconData icon,
    Color color,
    String subtitle,
    Color cardBg,
  ) {
    bool isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: MediaQuery.of(context).size.width * 0.27,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : cardBg,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              mode,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: _isDarkMode ? Colors.white60 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigTile(
    String title,
    String sub,
    IconData icon,
    Color col,
    bool val,
    Function(bool) fn,
    bool isDark,
  ) => SwitchListTile(
    secondary: Icon(icon, color: col),
    title: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _showHelp(title, title), // title is used as key here
          child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
        ),
      ],
    ),
    subtitle: Text(
      sub,
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white60 : Colors.grey,
      ),
    ),
    value: val,
    activeColor: col,
    onChanged: fn,
  );
}
