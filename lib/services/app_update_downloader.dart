import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppUpdateDownloader {
  const AppUpdateDownloader();

  Future<File> download(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri);
    final streamed = await http.Client().send(request);
    final total = streamed.contentLength ?? 0;

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/vpn-update.apk');
    if (await file.exists()) {
      await file.delete();
    }

    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : -1);
      }
    } finally {
      await sink.close();
    }

    return file;
  }
}
