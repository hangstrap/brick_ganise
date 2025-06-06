import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'candidate_storage.dart';
import 'dart:io';
import 'camera_model.dart';
//import 'package:file_picker/file_picker.dart';

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
                                EditableDropdownMenu(
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
                                EditableDropdownMenu(
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
                                EditableDropdownMenu(          
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

class EditableDropdownMenu extends StatelessWidget {
  final List<String> options;
  final String? value;
  final bool enabled;
  final void Function(String?) onChanged;

  const EditableDropdownMenu({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DropdownMenu<String?>(
        initialSelection: value,
        enabled: enabled,
        onSelected: onChanged,
            dropdownMenuEntries: [
        const DropdownMenuEntry<String?>(
          value: null,
          label: '(none)', // or 'Select one', etc.
        ),
        ...options.map(
          (option) => DropdownMenuEntry(value: option, label: option),
        ),
      ],
      ),
    );
  }
}
