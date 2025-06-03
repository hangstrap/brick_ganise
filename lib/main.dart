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
import 'package:image/image.dart' as img;
import 'candidate_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const CameraPage());
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final CameraModel model = CameraModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Camera App')),
      body: CameraPageBody(model: model),
    );
  }
}

class CameraPageBody extends StatelessWidget {
  final CameraModel model;
  const CameraPageBody({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 100,
          height: 100,
          child: model.image == null
              ? const Text("No image selected")
              : kIsWeb
              ? Image.network(model.image!.path)
              : Image.file(File(model.image!.path)),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                await model.takePhoto();
                await model.uploadImage();
                (context as Element).markNeedsBuild();
              },
              child: const Text("Take Photo"),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () async {
                await model.pickImage();
                await model.uploadImage();
                (context as Element).markNeedsBuild();
              },
              child: const Text("Pick from Gallery"),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: model.results.length,
            itemBuilder: (context, index) {
              final item = model.results[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: CandidateStorage.load(
                  item['id'] as String,
                ), // Load stored comment
                builder: (context, snapshot) {
                  final comment = snapshot.data?['comment'] ?? '';

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Image.network(
                                item['image']!,
                                width: 100,
                                height: 100,
                              ),
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () {
                                  final url = item['url'];
                                  if (url != null && url.isNotEmpty) {
                                    launchUrl(Uri.parse(url));
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text("ID: ${item['id']}"),
                                Text("Score: ${item['score']}"),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: TextEditingController(
                                    text: comment,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Comment',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (value) async {
                                    final updated = Map<String, dynamic>.from(
                                      item,
                                    );
                                    updated['comment'] = value;
                                    await CandidateStorage.save(
                                      item['id'] as String,
                                      updated,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class CameraModel {
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
  }

  Future<void> pickImage() async {
    final PermissionStatus status = await Permission.photos.request();
    if (status.isGranted) {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      _image = image;
    } else {
      debugPrint("Photo permission denied");
    }
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
  }

  Future<Uint8List> compressImage(Uint8List inputBytes) async {
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
    debugPrint("Compressed image size: \${compressed.lengthInBytes} bytes");
    return compressed;
  }
}
