import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

/// Contrato para seleccionar y almacenar fotos de productos.
///
/// Devuelve rutas relativas (`photos/<nombre>.jpg`) que se guardan en
/// `product.photoPath`.
abstract interface class PhotoService {
  /// Selecciona una imagen (galería o cámara), la comprime y la guarda.
  /// Devuelve la ruta relativa o `null` si se canceló.
  Future<String?> pickAndSave(ImageSource source);

  /// Elimina la foto si existe (no lanza errores).
  Future<void> deletePhoto(String relativePath);
}

class LocalPhotoService implements PhotoService {
  final Future<XFile?> Function(ImageSource source) _pickFile;
  final Future<String> Function() baseDir;
  final int maxDimension;
  final int jpegQuality;

  LocalPhotoService({
    Future<XFile?> Function(ImageSource)? pickFile,
    required this.baseDir,
    this.maxDimension = 1024,
    this.jpegQuality = 80,
  }) : _pickFile = pickFile ??
            ((source) => ImagePicker().pickImage(
                  source: source,
                  maxWidth: 2048,
                  maxHeight: 2048,
                  imageQuality: 90,
                ));

  @override
  Future<String?> pickAndSave(ImageSource source) async {
    final picked = await _pickFile(source);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final needsResize =
        decoded.width > maxDimension || decoded.height > maxDimension;
    final resized =
        needsResize ? img.copyResize(decoded, width: maxDimension) : decoded;
    final jpg = img.encodeJpg(resized, quality: jpegQuality);

    final dir = await _photosDir();
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}.jpg';
    await File(p.join(dir.path, name)).writeAsBytes(jpg, flush: true);
    return p.join('photos', name);
  }

  @override
  Future<void> deletePhoto(String relativePath) async {
    try {
      final base = await baseDir();
      final file = File(p.join(base, relativePath));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Eliminación best-effort.
    }
  }

  Future<Directory> _photosDir() async {
    final base = await baseDir();
    final dir = Directory(p.join(base, 'photos'));
    await dir.create(recursive: true);
    return dir;
  }
}

/// Resuelve la ruta absoluta de una foto relativa (`photos/x.jpg`).
Future<String> absolutePhotoPath(String? relativePath) async {
  if (relativePath == null || relativePath.isEmpty) return '';
  final docs = await _documentsDir();
  return p.join(docs, relativePath);
}

Future<String> _documentsDir() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}
