// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

const String apiKey = '3wh5y2gyd7pk6icg8gm11jv4n';
const String athleteId = 'i454129';

void main() async {
  print('🚀 Starting Intervals.icu Upload Test...');

  // 1. Prepare Authentication Header
  // The username is literally the string "API_KEY", the password is your actual key.
  String basicAuth = 'Basic ${base64Encode(utf8.encode('API_KEY:$apiKey'))}';

  // 2. Define the Workout Data
  // Intervals.icu is smart: if you put the workout steps in the "description"
  // using their specific text format, it auto-creates the graph.
  final Map<String, dynamic> workoutPayload = {
    "category": "WORKOUT",
    "start_date_local": getTomorrowDateString(), // Schedule for tomorrow 10am
    "type": "Run",
    "name": "Test VMA Auto-Upload",
    "description":
        "Warmup\n- 10m 60% vma\n\nMain Set\n- 5x 400m 105% vma\n- 90s 60% vma\n\nCooldown\n- 5m 50% vma",
    "filename": "test_workout.zwo", // Optional hint to parser
  };

  // 3. The API Endpoint (POST to create, PUT to update)
  final Uri url = Uri.parse(
    'https://intervals.icu/api/v1/athlete/$athleteId/events',
  );

  try {
    print('📡 Sending request to ${url.toString()}...');

    final response = await http.post(
      url,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
      body: jsonEncode(workoutPayload),
    );

    // 4. Handle Response
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ SUCCESS! Workout created.');
      print('Response ID: ${jsonDecode(response.body)['id']}');
      print('Check your calendar at: https://intervals.icu/calendar');
    } else {
      print('❌ ERROR: Upload failed.');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
  }
}

// Helper to get a valid ISO string for "Tomorrow at 10:00 AM"
String getTomorrowDateString() {
  final now = DateTime.now();
  final tomorrow = now.add(const Duration(days: 1));
  // Format: YYYY-MM-DDTHH:mm:ss
  final iso = tomorrow.toIso8601String();
  // Remove milliseconds/timezone for simplicity (Intervals prefers Local time string)
  return '${iso.substring(0, 10)}T10:00:00';
}
