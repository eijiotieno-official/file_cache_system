import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileCacheServices {
  /// Method to create the directory if it doesn't exist and get its path
  static Future<Directory> _getCacheDirectory() async {
    /// Get the application documents directory
    final applicationDocumentsDirectory =
        await getApplicationDocumentsDirectory();

    /// Define the cache directory path by appending "File_Cache/" to the application documents directory path
    final directory =
        Directory("${applicationDocumentsDirectory.path}/File_Cache/");

    /// Check if the cache directory exists
    if (!await directory.exists()) {
      /// Create the cache directory if it doesn't exist, including any necessary parent directories
      await directory.create(recursive: true);
    }

    /// Return the directory object representing the cache directory
    return directory;
  }

  /// Method to create a new file in the cache directory
  static Future<File> _createNewFile(String basename) async {
    /// Get the cache directory
    final cacheDirectory = await _getCacheDirectory();

    /// Define the full file path by appending the basename to the cache directory path
    File file = File("${cacheDirectory.path}$basename");

    /// Create the new file, including any necessary parent directories
    return await file.create(recursive: true);
  }

  /// Method to store a file in the cache directory
  static Future<File> _storeFile(File file) async {
    /// Create a new file in the cache directory with the same basename as the input file
    final newFile = await _createNewFile(path.basename(file.path));

    /// Copy the input file to the new file in the cache directory and return the new file
    return await file.copy(newFile.path);
  }

  /// Checks if a given URI is a URL that starts with "https://"
  static bool _isUrl(String uri) => uri.startsWith("https://");

  /// Cleans a URL by removing all non-word and non-space characters
  static String _cleanUrl(String url) =>
      url.replaceAll(RegExp(r'[^\w\s]+'), "");

  /// Downloads a file from the given URL and stores it in the cache directory
  static Future<File> _download(String url) async {
    /// Create a Dio instance for handling HTTP requests
    Dio dio = Dio();

    /// Send a GET request to download the file
    Response response = await dio.get(
      url,

      /// Specify response type as bytes to handle binary data
      options: Options(responseType: ResponseType.bytes),
    );

    /// Extract the file extension from the content-type header
    String? extension =
        response.headers.map['content-type']?.first.split('/').last;

    /// Generate a clean basename for the file using the cleaned URL and the extracted extension
    String basename = "${_cleanUrl(url)}.$extension";

    /// Get the temporary directory to store the downloaded file initially
    Directory tempDir = await getTemporaryDirectory();

    /// Create a temporary file with the generated basename in the temporary directory
    File tempFile = File("${tempDir.path}/$basename");

    /// Write the downloaded bytes to the temporary file
    await tempFile.writeAsBytes(response.data);

    /// Store the temporary file in the cache directory and return the new file
    return _storeFile(tempFile);
  }

  /// Stores a file either by downloading it from a URL or copying it from a local path
  static Future<File> put(String uri) async {
    /// Check if the given URI is a URL
    if (_isUrl(uri)) {
      /// If the URI is a URL, download the file
      return _download(uri);
    } else {
      /// If the URI is a local file path, create a File object
      File file = File(uri);

      /// Store the local file in the cache directory
      return _storeFile(file);
    }
  }

  /// Method to get a file from the cache by URI
  static Future<File?> get(String? uri) async {
    /// Return null if the URI is null
    if (uri == null) {
      return null;
    }

    /// Extract basename without extension from the URI
    String basenameWithoutExtension =
        _isUrl(uri) ? _cleanUrl(uri) : path.basenameWithoutExtension(uri);

    /// Get the cache directory
    final cacheDirectory = await _getCacheDirectory();

    /// Get a list of files in the cache directory
    final files = cacheDirectory.listSync();

    /// Iterate through files to find a match based on basename
    for (var element in files) {
      /// Check if the basename without extension matches
      if (path.basenameWithoutExtension(element.path) ==
          basenameWithoutExtension) {
        /// Return the matching file
        return File(element.path);
      }
    }

    /// Return null if no matching file is found
    return null;
  }

  /// Method to delete a file from the cache by URI
  static Future<void> delete(String uri) async {
    /// Get the file from the cache
    final file = await get(uri);

    /// Delete the file if it exists
    if (file != null) {
      await file.delete();
    }
  }
}
