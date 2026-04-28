import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isDarkMode = false; // Local state to handle UI live

  @override
  void initState() {
    super.initState();
    _loadThemeAndSync();
  }

  // Load Dark Mode preference and Sync Contacts
  Future<void> _loadThemeAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode_enabled') ?? false;
    });
    _syncContactsToLocal();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _syncContactsToLocal() async {
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('contacts')
          .get();

      List<String> phones = snapshot.docs
          .map((doc) => doc['phone'] as String)
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('contact_phones', phones);
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<void> _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (user != null) {
      String phone = _phoneController.text.trim();
      String name = _nameController.text.trim();

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('contacts')
            .add({'name': name, 'phone': phone});

        final prefs = await SharedPreferences.getInstance();
        List<String> currentPhones =
            prefs.getStringList('contact_phones') ?? [];
        if (!currentPhones.contains(phone)) {
          currentPhones.add(phone);
          await prefs.setStringList('contact_phones', currentPhones);
        }

        _nameController.clear();
        _phoneController.clear();
        FocusScope.of(context).unfocus(); // Close keyboard
      } catch (e) {
        debugPrint("Error adding contact: $e");
      }
    }
  }

  Future<void> _deleteContact(String docId, String phoneToDelete) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('contacts')
          .doc(docId)
          .delete();

      final prefs = await SharedPreferences.getInstance();
      List<String> currentPhones = prefs.getStringList('contact_phones') ?? [];
      currentPhones.remove(phoneToDelete);
      await prefs.setStringList('contact_phones', currentPhones);
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Design Colors
    final Color scaffoldBg = _isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color cardBg = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = _isDarkMode
        ? Colors.white
        : Colors.blueGrey.shade900;
    final Color inputFieldBg = _isDarkMode
        ? const Color(0xFF334155)
        : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          "Trusted Contacts",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- TOP INPUT SECTION ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTextField(
                  _nameController,
                  "Contact Name",
                  Icons.person_outline,
                  inputFieldBg,
                  _isDarkMode,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _phoneController,
                  "Phone Number",
                  Icons.phone_android_outlined,
                  inputFieldBg,
                  _isDarkMode,
                  isPhone: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      "Add to Emergency List",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- LIST SECTION ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),
                  Text(
                    "Your Active Guardians",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor.withOpacity(0.6),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .collection('contacts')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.redAccent,
                            ),
                          );
                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 80,
                                  color: textColor.withOpacity(0.2),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "No contacts yet",
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final contact = docs[index];
                            final String name = contact['name'];
                            final String phone = contact['phone'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isDarkMode
                                      ? Colors.white10
                                      : Colors.transparent,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 5,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.redAccent.withOpacity(
                                    0.1,
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(
                                  phone,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_sweep_outlined,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteContact(contact.id, phone),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER: TEXT FIELDS ---
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    Color bg,
    bool isDark, {
    bool isPhone = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
        prefixIcon: Icon(icon, color: Colors.redAccent, size: 22),
        filled: true,
        fillColor: bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}
