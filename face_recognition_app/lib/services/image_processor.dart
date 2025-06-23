import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ImageProcessor {
  static const int targetWidth = 112;
  static const int targetHeight = 112;

  /// Convertir imagen de cámara a formato procesable
  static Future<img.Image?> convertCameraImage(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    try {
      // Decodificar imagen
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Rotar si es necesario (cámaras móviles suelen rotar)
      final rotatedImage = img.copyRotate(image, angle: 90);

      return rotatedImage;
    } catch (e) {
      print('Error convirtiendo imagen: $e');
      return null;
    }
  }

  /// Recortar rostro detectado de la imagen
  static img.Image? cropFace(img.Image image, Face face) {
    try {
      final boundingBox = face.boundingBox;

      // Expandir un poco el bounding box para obtener más contexto
      final padding = 20;
      final x = (boundingBox.left - padding).clamp(0, image.width).toInt();
      final y = (boundingBox.top - padding).clamp(0, image.height).toInt();
      final width =
          (boundingBox.width + 2 * padding).clamp(0, image.width - x).toInt();
      final height =
          (boundingBox.height + 2 * padding).clamp(0, image.height - y).toInt();

      // Recortar rostro
      final croppedFace = img.copyCrop(
        image,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      return croppedFace;
    } catch (e) {
      print('Error recortando rostro: $e');
      return null;
    }
  }

  /// Redimensionar imagen para el modelo
  static img.Image resizeForModel(img.Image image) {
    return img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Normalizar píxeles para el modelo (0-1 range)
  static List<List<List<List<double>>>> normalizeImageForModel(
      img.Image image) {
    final input = List.generate(
        1,
        (i) => List.generate(
            targetHeight,
            (y) => List.generate(
                targetWidth, (x) => List.generate(3, (c) => 0.0))));

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel = image.getPixel(x, y);

        // Normalizar a rango [0, 1] y luego a [-1, 1]
        input[0][y][x][0] = (pixel.r / 255.0 - 0.5) * 2.0; // R
        input[0][y][x][1] = (pixel.g / 255.0 - 0.5) * 2.0; // G
        input[0][y][x][2] = (pixel.b / 255.0 - 0.5) * 2.0; // B
      }
    }

    return input;
  }

  /// Convertir imagen a bytes para guardar
  static Uint8List imageToBytes(img.Image image) {
    return Uint8List.fromList(img.encodePng(image));
  }
}
