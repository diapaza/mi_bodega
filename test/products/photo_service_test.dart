import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mi_bodega/features/products/data/services/photo_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mibodega_photos_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<String> writeSourceImage({int size = 2000}) async {
    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(11, 107, 79));
    final bytes = img.encodePng(image);
    final f = File('${tempDir.path}/source.png');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  test('pickAndSave comprime y guarda; deletePhoto elimina', () async {
    final src = await writeSourceImage();
    final service = LocalPhotoService(
      pickFile: (_) async => XFile(src),
      baseDir: () async => tempDir.path,
    );

    final path = await service.pickAndSave(ImageSource.gallery);
    expect(path, startsWith('photos/'));
    expect(path, endsWith('.jpg'));

    final file = File('${tempDir.path}/$path');
    expect(await file.exists(), isTrue);

    final decoded = img.decodeImage(await file.readAsBytes())!;
    expect(decoded.width, lessThanOrEqualTo(1024));

    await service.deletePhoto(path!);
    expect(await file.exists(), isFalse);
  });

  test('cancelación devuelve null', () async {
    final service = LocalPhotoService(
      pickFile: (_) async => null,
      baseDir: () async => tempDir.path,
    );
    expect(await service.pickAndSave(ImageSource.camera), isNull);
  });

  test('deletePhoto tolera archivos inexistentes', () async {
    final service = LocalPhotoService(
      pickFile: (_) async => null,
      baseDir: () async => tempDir.path,
    );
    await service.deletePhoto('photos/no-existe.jpg');
  });
}
