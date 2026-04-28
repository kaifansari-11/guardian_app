import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class StorageService {
  // 🔹 REPLACE THESE WITH YOUR CLOUDINARY DETAILS
  final String cloudName = "dg3qossyn";
  final String uploadPreset =
      "guardian_upload"; // The name you created (Unsigned)

  Future<String?> uploadAudio(String filePath) async {
    try {
      File file = File(filePath);
      if (!file.existsSync()) return null;

      Uri url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/video/upload",
      );
      // Note: Cloudinary treats audio as "video" resource_type usually, or "auto"

      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      debugPrint("☁️ Uploading to Cloudinary...");

      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final jsonResponse = json.decode(respStr);
        String downloadUrl = jsonResponse['secure_url'];

        debugPrint("✅ Upload Success! URL: $downloadUrl");
        return downloadUrl;
      } else {
        debugPrint("❌ Cloudinary Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error uploading: $e");
      return null;
    }
  }
}
