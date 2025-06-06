
import 'dart:io';
import 'package:flutter/foundation.dart';
//import 'dart:typed_data';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
//import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
//import 'package:url_launcher/url_launcher.dart';
import 'package:image/image.dart' as img;
import 'candidate_storage.dart';
import 'package:file_picker/file_picker.dart';


class CameraModel extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  List<Map<String, String>> _results = [];

  XFile? get image => _image;
  List<Map<String, String>> get results => _results;

  Future<void> takePhoto() async {
    final PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      _image = image;
    } else {
      debugPrint("Camera permission denied");
    }
    notifyListeners(); // Notify listeners to update the UI
  }

  Future<void> pickImage() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final PermissionStatus status = await Permission.photos.request();
      if (status.isGranted) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
        );
        _image = image;
      } else {
        debugPrint("Photo permission denied");
      }
    } else {
      // Desktop platforms (Linux, Windows, macOS)
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final imagePath = result.files.single.path!;
        _image = XFile(imagePath);
      }
    }
    notifyListeners(); // Notify listeners to update the UI
  }

  Future<void> uploadImage() async {
    _results.clear();
    if (_image == null) return;

    try {
      final uri = Uri.parse('https://api.brickognize.com/internal/search/');
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final bytes = await _image!.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'query_image',
          bytes,
          filename: 'upload.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      } else {
        final originalBytes = await _image!.readAsBytes();
        final compressedBytes = await compressImage(originalBytes);
        final file = http.MultipartFile.fromBytes(
          'query_image',
          compressedBytes,
          filename: 'upload.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(file);
      }
      debugPrint("Uploading to server");
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: \n\n  $responseBody \n\n");
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final detectedItems = data['detected_items'] as List;
        final results = <Map<String, String>>[];

        for (var item in detectedItems) {
          final candidates = item['candidate_items'] as List;
          for (var candidate in candidates) {
            final id = candidate['id'];
            await CandidateStorage.save(id, candidate);

            final externalItems = candidate['external_items'] as List;
            final url = externalItems.isNotEmpty ? externalItems[0]['url'] : '';
            results.add({
              'id': candidate['id'].toString(),
              'name': candidate['name'],
              'image': candidate['image_url'],
              'score': candidate['score'].toStringAsFixed(2),
              'url': url,
            });
          }
        }

        _results = results;
      } else {
        debugPrint(
          "Upload failed: \${response.statusCode} \${response.reasonPhrase}",
        );
      }
    } catch (e) {
      debugPrint("Error uploading image: \$e");
    }
    notifyListeners(); // Notify listeners to update the UI
  }

  Future<Uint8List> compressImage(Uint8List inputBytes) async {
    if (inputBytes.lengthInBytes < 2 * 1024 * 1024) {
      debugPrint("Image is already less than 2MB, no compression needed.");
      return inputBytes;
    }
    final image = img.decodeImage(inputBytes);
    if (image == null) throw Exception("Could not decode image");

    int quality = 95;
    Uint8List compressed = Uint8List.fromList(
      img.encodeJpg(image, quality: quality),
    );

    while (compressed.lengthInBytes > 2 * 1024 * 1024 && quality > 10) {
      quality -= 5;
      compressed = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
    debugPrint(
      "Final compressed image size: ${compressed.lengthInBytes} bytes, quality: $quality",
    );
    return compressed;
  }

  void clearResults() {
    _results.clear();
    notifyListeners(); // Triggers UI rebuild
  }
}