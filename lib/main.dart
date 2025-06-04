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
import 'package:dropdown_search/dropdown_search.dart';

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
      body: CameraPageBody(model: model), // <-- pass the model here
    );
  }
}

class CameraPageBody extends StatefulWidget {
  final CameraModel model;
  const CameraPageBody({super.key, required this.model});

  @override
  State<CameraPageBody> createState() => _CameraPageBodyState();
}

class _CameraPageBodyState extends State<CameraPageBody> {
  final Map<String, Map<String, String?>> _editableData = {};

  final binOptions = [
    'Able',
    'Bob',
    'Chip',
    'Denyy',
    'Emma',
    'Fiona',
    'Gale',
    'Harry',
    'Ian',
    'Jane',
    'Kate',
    'Lyn',
    'Mike',
    'Nick',
    'Osca',
    'Paul',
    'Queen',
    'Rick',
    'Stew',
    'Tom',
    'Uma',
    'Vilot',
    'Walter',
    'Xena',
    'Yara',
    'Zoie',
  ];
  final columnOptions = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
  final rowOptions = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];

  @override
  void initState() {
    super.initState();
    _loadAllEditableData();
  }

  Future<void> _loadAllEditableData() async {
    for (var item in widget.model.results) {
      final id = item['id'];
      if (id == null) continue;
      final stored = await CandidateStorage.load(id);
      _editableData[id] = {
        'bin': stored['bin'],
        'row': stored['row'],
        'column': stored['column'],
      };
    }
    setState(() {});
  }

  void _updateField(String id, String field, String? value) async {
    final stored = await CandidateStorage.load(id);
    stored[field] = value;
    await CandidateStorage.save(id, stored);
    setState(() {
      _editableData[id]?[field] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: 100,
          height: 100,
          child: widget.model.image == null
              ? const Text("No image selected")
              : kIsWeb
              ? Image.network(widget.model.image!.path)
              : Image.file(File(widget.model.image!.path)),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                widget.model.clearResults();
                await widget.model.takePhoto();
                await widget.model.uploadImage();
                await _loadAllEditableData();
              },
              child: const Text("Take Photo"),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () async {
                widget.model.clearResults();
                await widget.model.pickImage();
                await widget.model.uploadImage();
                await _loadAllEditableData();
              },
              child: const Text("Pick from Gallery"),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.model.results.length,
            itemBuilder: (context, index) {
              final item = widget.model.results[index];
              final id = item['id']!;
              final fields = _editableData[id] ?? {};

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
                            Text("ID: $id"),
                            Text("Score: ${item['score']}"),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                EditableDropdownAutocomplete(
                    
                                  label: 'Bin',
                                  options: binOptions,
                                  value: fields['bin'],
                                  onChanged: (value) {
                                    _updateField(id, 'bin', value);
                                    if (value == null || value.isEmpty) {
                                      _updateField(id, 'column', null);
                                      _updateField(id, 'row', null);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                EditableDropdownAutocomplete(
                         
                                  label: 'Column',
                                  options: columnOptions,
                                  value: fields['column'],
                                  enabled: (fields['bin']?.isNotEmpty ?? false),
                                  onChanged: (value) {
                                    _updateField(id, 'column', value);
                                    if (value == null || value.isEmpty) {
                                      _updateField(id, 'row', null);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                EditableDropdownAutocomplete(
                 
                                  label: 'Row',
                                  options: rowOptions,
                                  value: fields['row'],
                                  enabled:
                                      (fields['column']?.isNotEmpty ?? false),
                                  onChanged: (value) {
                                    _updateField(id, 'row', value);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


class EditableDropdownAutocomplete extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final bool enabled;
  final void Function(String?) onChanged;

  const EditableDropdownAutocomplete({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: value ?? ''),
        optionsBuilder: (TextEditingValue textEditingValue) {
          final input = textEditingValue.text.toLowerCase();
          if (input.isEmpty) return const Iterable<String>.empty();
          return options.where(
            (option) => option.toLowerCase().startsWith(input),
          );
        },
        onSelected: (String selection) {
          onChanged(selection);
        },
        fieldViewBuilder:
            (context, controller, focusNode, onEditingComplete) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            decoration: InputDecoration(labelText: label),
            onEditingComplete: () {
              final input = controller.text.trim();
              final match = options.firstWhere(
                (o) => o.toLowerCase() == input.toLowerCase(),
                orElse: () => '',
              );
              if (match.isNotEmpty) {
                controller.text = match;
                onChanged(match);
              } else {
                controller.clear();
                onChanged(null);
              }
              onEditingComplete();
            },
          );
        },
      ),
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
