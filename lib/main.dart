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
      appBar: AppBar(centerTitle: true, title: const Text('Brick Ganise')),
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
        const SizedBox(height: 4),
        SizedBox(
          width: 100,
          height: 100,
          child: widget.model.image == null
              ? const Text("No image selected")
              : kIsWeb
              ? Image.network(widget.model.image!.path)
              : Image.file(File(widget.model.image!.path)),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                widget.model.clearResults();
                setState(() {});
                await widget.model.takePhoto();
                setState(() {});
                await widget.model.uploadImage();
                await _loadAllEditableData();
              },
              child: const Text("Photo"),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () async {
                widget.model.clearResults();
                setState(() {});
                await widget.model.pickImage();
                setState(() {});
                await widget.model.uploadImage();
                await _loadAllEditableData();
              },
              child: const Text("Gallery"),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Image + Text
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.network(
                            item['image']!,
                            width: 100,
                            height: 100,
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
                                    fontSize: 10,
                                  ),
                                ),
                                Text("ID: $id"),
                                Text("Score: ${item['score']}"),
                              ],
                            ),
                          ),
                        ],
                      ),
                   //   const SizedBox(height: 8),

                      // Bottom row: 3 dropdowns
                      Row(
                        children: [
                          Expanded(
                            child: EditableDropdownMenu(
                              options: binOptions,
                              value: fields['bin'],
                              onChanged: (value) =>
                                  _updateField(id, 'bin', value),
                            ),
                          ),
                          //const SizedBox(width: 4),
                          Expanded(
                            child: EditableDropdownMenu(
                              options: columnOptions,
                              value: fields['column'],
                              onChanged: (value) =>
                                  _updateField(id, 'column', value),
                            ),
                          ),
                          //const SizedBox(width: 4),
                          Expanded(
                            child: EditableDropdownMenu(
                              options: rowOptions,
                              value: fields['row'],
                              onChanged: (value) =>
                                  _updateField(id, 'row', value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
    return SizedBox(
      height: 40, // smaller height
      child: DropdownMenuTheme(
        data: DropdownMenuThemeData(
          textStyle: const TextStyle(fontSize: 12), // smaller font
          menuStyle: MenuStyle(
            visualDensity: VisualDensity.compact, // tighter spacing
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            isDense: true,
          ),
        ),
        child: DropdownMenu<String?>(
          initialSelection: value,
          enabled: enabled,
          onSelected: onChanged,
          dropdownMenuEntries: [
            const DropdownMenuEntry<String?>(
              value: null,
              label: '?',
            ),
            ...options.map(
              (option) => DropdownMenuEntry(value: option, label: option),
            ),
          ],
        ),
      ),
    );
  }
}
