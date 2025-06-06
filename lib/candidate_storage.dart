

import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';


class CandidateStorage {
  static Future<Directory> _getDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final subdir = Directory('${dir.path}/brick_ganise/candidates/');
    if (!await subdir.exists()) {
      await subdir.create(recursive: true);
    }
    return subdir;
  }

  static Future<File> _getFile(String id) async {
    final dir = await _getDir();
    return File('${dir.path}/$id.json');
  }

  static Future<Map<String, dynamic>> load(String id) async {
    final file = await _getFile(id);
    if (await file.exists()) {
      final contents = await file.readAsString();
      debugPrint( "loaded candidate data $contents");
      try{
      var json = jsonDecode(contents);
      return json;
      }catch(e){
        debugPrint(e.toString());
        return {};
      }
    }
    return {};
  }

  static Future<void> save(String id, Map<String, dynamic> newData) async {
    final file = await _getFile(id);
    final existing = await load(id);

      // Merge all keys from existing into newData if missing
  for (var key in existing.keys) {
    if (!newData.containsKey(key)) {
      newData[key] = existing[key];
    }
  }
  var json = jsonEncode(newData);
    await file.writeAsString( json);
    debugPrint( "saving cadidate data  $json");
  }
}
