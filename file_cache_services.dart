import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileCacheServices {
  // Method to create the directory if it doesn't exist and get its path
  static Future<Directory> _getCacheDirectory() async {
    // Get the application documents directory
    final applicationDocumentsDirectory =
        await getApplicationDocumentsDirectory();

    // Define the cache directory path
    final directory =
        Directory("${applicationDocumentsDirectory.path}/File_Cache/");

    // Create the cache directory if it doesn't exist
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // Method to create a new file in the cache directory
  static Future<File> _createNewFile(String basename) async {
    final cacheDirectory = await _getCacheDirectory();
    File file = File("${cacheDirectory.path}$basename");
    return await file.create(recursive: true);
  }

  static Future<File> _storeFile(File file) async {
    final newFile = await _createNewFile(path.basename(file.path));
    return await file.copy(newFile.path);
  }

  static bool _isUrl(String uri) => uri.startsWith("https://");

  static String _cleanUrl(String url) =>
      url.replaceAll(RegExp(r'[^\w\s]+'), "");

  static Future<File> _download(String url) async {
    Dio dio = Dio();
    // Send GET request to download file
    Response response = await dio.get(
      url,
      // Specify response type as bytes
      options: Options(responseType: ResponseType.bytes),
    );

    String? extension =
        response.headers.map['content-type']?.first.split('/').last;

    String basename = "${_cleanUrl(url)}.$extension";

    Directory tempDir = await getTemporaryDirectory();

    File tempFile = File("${tempDir.path}$basename");

    return _storeFile(tempFile);
  }

  static Future<File> put(String uri) async {
    if (_isUrl(uri)) {
      return _download(uri);
    } else {
      File file = File(uri);
      return _storeFile(file);
    }
  }

  // Method to get a file from the cache by URI
  static Future<File?> get(String? uri) async {
    if (uri == null) {
      return null;
    }
    // Extract basename without extension from the URI
    String basenameWithoutExtension =
        _isUrl(uri) ? _cleanUrl(uri) : path.basenameWithoutExtension(uri);

    // Get the cache directory
    final cacheDirectory = await _getCacheDirectory();

    // Get a list of files in the cache directory
    final files = cacheDirectory.listSync();

    // Iterate through files to find a match based on basename
    for (var element in files) {
      if (path.basenameWithoutExtension(element.path) ==
          basenameWithoutExtension) {
        return File(element.path);
      }
    }
    return null;
  }

  // Method to delete a file from the cache by URI
  static Future<void> delete(String uri) async {
    // Get the file from the cache
    final file = await get(uri);
    // Delete the file if it exists
    if (file != null) {
      await file.delete();
    }
  }
}
