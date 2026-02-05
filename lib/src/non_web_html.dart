// Minimal stub used when dart:html is unavailable (non-web platforms).
// This file is selected via conditional import when not compiling to web.
library non_web_html;

import 'dart:async';

class File {}

class FileUploadInputElement {
  bool multiple = false;
  String? accept;
  List<File>? files;
  void click() {}
  Stream<void> get onChange => const Stream<void>.empty();
}

class FileReader {
  dynamic result;
  Stream<void> get onLoad => const Stream<void>.empty();
  void readAsDataUrl(File file) {}
}

class Blob {
  Blob(List<dynamic> parts, String type);
}

class Url {
  static String createObjectUrlFromBlob(dynamic _) => '';
  static void revokeObjectUrl(String _) {}
}

class AnchorElement {
  String? href;
  String? download;
  dynamic style;
  AnchorElement({this.href});
  void click() {}
  void remove() {}
}

class Document {
  Body? body;
}

class Body {
  void append(dynamic _) {}
}

final document = Document();
