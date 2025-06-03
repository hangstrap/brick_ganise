import 'dart:typed_data';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: _CameraPage());
  }
}

class _CameraPage extends StatefulWidget {
  const _CameraPage({super.key});
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  List<Map<String, String>> _results = [];

  // Function to take a photo using the camera
  Future<void> _takePhoto() async {
    final PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      setState(() {
        _image = image;
      });
    } else {
      debugPrint("Camera permission denied");
    }
  }

  // Function to pick an image from gallery
  Future<void> _pickImage() async {
    final PermissionStatus status = await Permission.photos.request();
    if (status.isGranted) {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      setState(() {
        _image = image;
      });
    } else {
      debugPrint("Photo permission denied");
    }
  }

  Future<void> _uploadImage() async {
    _results.clear(); // Clear previous results
    if (_image == null) return;

    try {
      var uri = Uri.parse('https://api.brickognize.com/internal/search/');
      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        // Read file as bytes for web
        final bytes = await _image!.readAsBytes();

        var multipartFile = http.MultipartFile.fromBytes(
          'query_image',
          bytes,
          filename: 'upload.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        debugPrint("File size: ${multipartFile.length} bytes");
        request.files.add(multipartFile);
      } else {
        Uint8List originalBytes = await _image!.readAsBytes();
        //        Uint8List compressedBytes = await compressImage(originalBytes);
        // Non-web: use file path
        var file = http.MultipartFile.fromBytes(
          'query_image',
          originalBytes,
          filename: 'upload.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        debugPrint("File size: ${file.length} bytes");
        request.files.add(file);
      }

      debugPrint("about to send request with file: ${_image!.path}");
      // Send the request
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final detectedItems = data['detected_items'] as List;
        final List<Map<String, String>> results = [];

        for (var item in detectedItems) {
          final candidates = item['candidate_items'] as List;
          for (var candidate in candidates) {
            final externalItems = candidate['external_items'] as List;
            final url = externalItems.isNotEmpty
                ? externalItems[0]['url']
                : null;

            results.add({
              'name': candidate['name'],
              'image': candidate['image_url'],
              'score': candidate['score'].toStringAsFixed(2),
              'url': url ?? '',
            });
          }
        }

        setState(() {
          _results = results;
        });
      } else {
        debugPrint(
          "Upload failed with status: ${response.statusCode} ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
    }
  }

  Future<Uint8List> compressImage(Uint8List inputBytes) async {
    final image = img.decodeImage(inputBytes);
    if (image == null) {
      throw Exception("Could not decode image");
    }

    int quality = 95;
    Uint8List compressed = Uint8List.fromList(
      img.encodeJpg(image, quality: quality),
    );

    while (compressed.lengthInBytes > 2 * 1024 * 1024 && quality > 10) {
      quality -= 5;
      compressed = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
    debugPrint("Compressed image size: ${compressed.lengthInBytes} bytes");
    debugPrint("Final quality: $quality");
    return compressed;
  }

  Future<Uint8List?> _compressImage(String path) async {
    final result = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: 200, // Resize image
      minHeight: 200,
      quality: 10, // Compression quality (0–100)
      format: CompressFormat.jpeg,
    );
    return result;
  }

  void handleBrickognizeResponse(String jsonResponse) {
    final data = jsonDecode(jsonResponse);

    final detectedItems = data['detected_items'] as List;
    for (var item in detectedItems) {
      final candidates = item['candidate_items'] as List;

      for (var candidate in candidates) {
        final name = candidate['name'];
        final score = candidate['score'];
        final imageUrl = candidate['image_url'];
        final external = candidate['external_items'] as List;

        final bricklinkUrl = external.isNotEmpty
            ? external[0]['url']
            : 'No link';

        debugPrint('Name: $name');
        debugPrint('Score: ${score.toStringAsFixed(2)}');
        debugPrint('Image URL: $imageUrl');
        debugPrint('BrickLink: $bricklinkUrl');
        debugPrint('---');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter Camera App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 200,
              height: 200,
              child: _image == null
                  ? Text("No image selected")
                  : kIsWeb
                  ? Image.network(_image!.path)
                  : Image.file(File(_image!.path)),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _takePhoto,
                  child: Text("Take Photo"),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text("Pick from Gallery"),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadImage,
              child: Text("Upload Image"),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return Card(
                    margin: EdgeInsets.all(8),
                    child: ListTile(
                      leading: Image.network(
                        item['image']!,
                        width: 50,
                        height: 50,
                      ),
                      title: Text(item['name']!),
                      subtitle: Text("Score: ${item['score']}"),
                      trailing: Icon(Icons.open_in_new),
                      onTap: () {
                        final url = item['url'];
                        if (url != null && url.isNotEmpty) {
                          launchUrl(Uri.parse(url));
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
