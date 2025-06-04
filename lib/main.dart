import 'package:provider/provider.dart';
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
  runApp(
    ChangeNotifierProvider(create: (_) => CameraModel(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CameraPage());
  }
}

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Camera App')),
      body: const CameraPageBody(),
    );
  }
}

class CameraPageBody extends StatelessWidget {
  const CameraPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<CameraModel>(context);

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
              },
              child: const Text("Take Photo"),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () async {
                await model.pickImage();
                await model.uploadImage();
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
              final id = item['id']!;
              return FutureBuilder<Map<String, dynamic>>(
                future: CandidateStorage.load(id),
                builder: (context, snapshot) {
                  //                 final storedData = snapshot.data ?? {};
                  //                  final comment = storedData['comment'] ?? '';
                  //                final controller = TextEditingController(text: comment);
                  final binValue = snapshot.data?['bin'] as String?;
                  final rowValue = snapshot.data?['row'] as String?;
                  final columnValue = snapshot.data?['column'] as String?;
                  const binOptions = ['A', 'B', 'C', 'D', 'E'];
                  const rowOptions = ['1', '2', '3', '4', '5'];
                  const columnOptions = ['1', '2', '3', '4', '5'];

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // image + icon column unchanged
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

                                // Dropdowns for Bin, Row, Column
                                DropdownButtonFormField<String>(
                                  value: binValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Bin (optional)',
                                  ),
                                  items: [null, ...binOptions].map((e) {
                                    return DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e ?? 'None'),
                                    );
                                  }).toList(),
                                  onChanged: (val) async {
                                    final updated = Map<String, dynamic>.from(
                                      item,
                                    );
                                    updated['bin'] = val;
                                    await CandidateStorage.save(
                                      item['id'] as String,
                                      updated,
                                    );
                                    // Optional: Trigger UI update, e.g. by calling setState or notifyListeners in your model
                                  },
                                ),

                                const SizedBox(height: 8),

                                DropdownButtonFormField<String>(
                                  value: rowValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Row (optional)',
                                  ),
                                  items: [null, ...rowOptions].map((e) {
                                    return DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e ?? 'None'),
                                    );
                                  }).toList(),
                                  onChanged: (val) async {
                                    final updated = Map<String, dynamic>.from(
                                      item,
                                    );
                                    updated['row'] = val;
                                    await CandidateStorage.save(
                                      item['id'] as String,
                                      updated,
                                    );
                                  },
                                ),

                                const SizedBox(height: 8),

                                DropdownButtonFormField<String>(
                                  value: columnValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Column (optional)',
                                  ),
                                  items: [null, ...columnOptions].map((e) {
                                    return DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e ?? 'None'),
                                    );
                                  }).toList(),
                                  onChanged: (val) async {
                                    final updated = Map<String, dynamic>.from(
                                      item,
                                    );
                                    updated['column'] = val;
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
    final PermissionStatus status = await Permission.photos.request();
    if (status.isGranted) {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      _image = image;
    } else {
      debugPrint("Photo permission denied");
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
