import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:injectable/injectable.dart';

class TrackAudioMetadata {
  final int? bitRate;
  final int? sampleRate;
  final String? format;
  final int? channels;

  TrackAudioMetadata({this.bitRate, this.sampleRate, this.format, this.channels});
}

@lazySingleton
class AudioMetadataService {
  final Dio _dio;

  AudioMetadataService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<TrackAudioMetadata?> fetchMetadata(String urlOrPath, {String? format}) async {
    try {
      if (urlOrPath.startsWith('http')) {
        final List<int> receivedBytes = [];
        final cancelToken = CancelToken();
        
        try {
          final response = await _dio.get<ResponseBody>(
            urlOrPath,
            options: Options(
              responseType: ResponseType.stream,
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            ),
            cancelToken: cancelToken,
          );
          
          await for (final chunk in response.data!.stream) {
            receivedBytes.addAll(chunk);
            if (receivedBytes.length >= 262144) { // Fetch exactly 256KB
              cancelToken.cancel('Sufficient bytes received');
              break;
            }
          }
        } catch (e) {
          // Ignore expected cancel exception
          if (e is! DioException || e.type != DioExceptionType.cancel) {
            print('[AudioMetadataService] Failed to stream chunk from $urlOrPath: $e');
            return null;
          }
        }
        
        if (receivedBytes.isEmpty) return null;
        final bytes = Uint8List.fromList(receivedBytes);
        
        String formatHint = format?.toLowerCase() ?? 'mp3';
        if (formatHint == 'aac') formatHint = 'm4a';
        
        final lowerUrl = urlOrPath.toLowerCase();
        if (lowerUrl.contains('.flac')) formatHint = 'flac';
        else if (lowerUrl.contains('.mp3')) formatHint = 'mp3';
        else if (lowerUrl.contains('.m4a') || lowerUrl.contains('.aac')) formatHint = 'm4a';

        final info = await AudioDecoder.getAudioInfoBytes(bytes, formatHint: formatHint);
        return TrackAudioMetadata(
          bitRate: info.bitRate,
          sampleRate: info.sampleRate,
          format: info.format,
          channels: info.channels,
        );

      } else {
        // It's a local file
        String filePath = urlOrPath;
        if (urlOrPath.startsWith('file://')) {
          filePath = Uri.parse(urlOrPath).toFilePath();
        }
        final info = await AudioDecoder.getAudioInfo(filePath);
        if (info != null) {
          return TrackAudioMetadata(
            bitRate: info.bitRate,
            sampleRate: info.sampleRate,
            format: info.format,
            channels: info.channels,
          );
        }
        return null;
      }
    } catch (e) {
      print('[AudioMetadataService] Failed to extract metadata for $urlOrPath: $e');
      return null;
    }
  }
}
