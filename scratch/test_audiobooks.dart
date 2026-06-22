import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('==================================================');
  print('TESTING ECLIPSE AUDIOBOOKS ADDON ENDPOINTS');
  print('==================================================\n');

  // Base URL for the Eclipse Addon architecture setup
  const String baseUrl = 'https://improved-all-in-one.cyrusna29.workers.dev/eyJub19wb2RjYXN0Ijp0cnVlLCJub19yYWRpbyI6dHJ1ZSwic2VhcmNoX29yZGVyIjpbImhpZmkiLCJxb2J1eiIsImRlZXplciIsInNjIiwiaWEiXSwic3RyZWFtX29yZGVyIjpbInFvYnV6IiwiaGlmaSIsImRlZXplciIsInNjIiwiaWEiXX0/audiobook';

  // 1. Fetch Manifest
  print('1. Fetching manifest from $baseUrl/manifest.json');
  try {
    final manifestRes = await http.get(Uri.parse('$baseUrl/manifest.json'));
    if (manifestRes.statusCode == 200) {
      print('✅ Manifest fetched successfully:');
      print(manifestRes.body);
    } else {
      print('❌ Failed to fetch manifest: ${manifestRes.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching manifest: $e');
  }
  print('\n--------------------------------------------------\n');

  // 2. Search Query using Eclipse Addon query architecture: /search?q=query
  const String query = 'sherlock';
  final String searchUrl = '$baseUrl/search?q=${Uri.encodeComponent(query)}';
  print('2. Sending Search Query:');
  print('URL: $searchUrl\n');

  try {
    final http.Response response = await http.get(Uri.parse(searchUrl));
    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic>? tracks = json['tracks'];
      
      if (tracks != null && tracks.isNotEmpty) {
        print('✅ Success! Found ${tracks.length} matching audiobooks.');
        print('Showing top 3 entries:\n');
        
        for (int i = 0; i < tracks.length && i < 3; i++) {
          final dynamic track = tracks[i];
          print('Track #${i + 1}:');
          print(' - ID: ${track['id']}');
          print(' - Title: ${track['title']}');
          print(' - Artist/Author: ${track['artist']}');
          print(' - Artwork URL: ${track['artworkURL']}');
          print(' - Stream URL: ${track['streamURL']}');
          print(' - Format: ${track['format']}');
          print(' - Duration: ${track['duration']}');
          print('');
        }

        // Test dynamic stream resolution endpoint: /stream/{trackId}
        final String firstId = tracks[0]['id'];
        final String streamUrl = '$baseUrl/stream/${Uri.encodeComponent(firstId)}';
        
        print('3. Testing Stream Resolution:');
        print('URL: $streamUrl\n');

        final http.Response streamResponse = await http.get(Uri.parse(streamUrl));
        if (streamResponse.statusCode == 200) {
          final Map<String, dynamic> streamJson = jsonDecode(streamResponse.body);
          print('✅ Stream URL resolved successfully:');
          print('Resolved Direct URL: ${streamJson['url']}');
        } else {
          print('❌ Failed to resolve stream. Status: ${streamResponse.statusCode}');
        }
      } else {
        print('❌ No tracks found in search response.');
        print('Raw Response: ${response.body}');
      }
    } else {
      print('❌ Search request failed. Status Code: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Connection or Execution error occurred during search: $e');
  }
}
