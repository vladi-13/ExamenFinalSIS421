import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/face_data.dart';
import '../utils/math_utils.dart';
import 'image_processor.dart';

class FaceRecognitionService {
  static final FaceRecognitionService instance =
      FaceRecognitionService._internal();
  FaceRecognitionService._internal();

  // Stream para notificar cambios en los rostros registrados
  final StreamController<List<FaceData>> _facesController =
      StreamController<List<FaceData>>.broadcast();

  Interpreter? _interpreter;
  FaceDetector? _faceDetector;
  List<FaceData> _registeredFaces = [];
  bool _isInitialized = false;

  // Configuración del modelo
  static const String modelPath = 'assets/models/mobilefacenet.tflite';
  static const double recognitionThreshold =
      0.7; // Umbral de similitud más permisivo
  static const int embeddingSize = 128; // Tamaño del embedding MobileFaceNet

  /// Inicializar el servicio
  Future<bool> initialize() async {
    try {
      print('Inicializando servicio de reconocimiento facial...');

      // Inicializar TensorFlow Lite
      await _initializeTensorFlow();

      // Inicializar detector de rostros ML Kit
      await _initializeFaceDetector();

      // Cargar rostros registrados
      await _loadRegisteredFaces();

      _isInitialized = true;
      print('Servicio inicializado correctamente');
      return true;
    } catch (e) {
      print('Error inicializando servicio: $e');
      return false;
    }
  }

  /// Inicializar TensorFlow Lite
  Future<void> _initializeTensorFlow() async {
    try {
      // Cargar modelo desde assets
      final options = InterpreterOptions();

      // Habilitar GPU si está disponible
      if (Platform.isAndroid) {
        options.addDelegate(GpuDelegateV2());
      }

      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      print('Modelo TensorFlow Lite cargado');

      // Verificar dimensiones del modelo
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Input shape: $inputShape');
      print('Output shape: $outputShape');
    } catch (e) {
      print('Error cargando modelo TensorFlow Lite: $e');
      rethrow;
    }
  }

  /// Inicializar detector de rostros
  Future<void> _initializeFaceDetector() async {
    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.accurate,
    );

    _faceDetector = FaceDetector(options: options);
    print('Detector de rostros inicializado');
  }

  /// Detecta, recorta y procesa un rostro desde un archivo de imagen.
  Future<FaceDetectionResult> detectAndProcessFace(XFile imageFile) async {
    if (!_isInitialized) {
      return FaceDetectionResult(
        faceDetected: false,
        error: 'Servicio no inicializado',
      );
    }

    try {
      // 1. Detección de rostro
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceDetectionResult(
          faceDetected: false,
          error: 'No se detectó ningún rostro.',
        );
      }
      final face = faces.first;

      // 2. Recortar y procesar la imagen
      // Necesitamos leer los bytes de la imagen para procesarla con el paquete 'image'
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return FaceDetectionResult(
          faceDetected: false,
          error: 'No se pudo decodificar la imagen.',
        );
      }

      final croppedFace = ImageProcessor.cropFace(image, face);
      if (croppedFace == null) {
        return FaceDetectionResult(
          faceDetected: false,
          error: 'Error recortando rostro',
        );
      }

      // Redimensionar para el modelo
      final resizedFace = ImageProcessor.resizeForModel(croppedFace);

      // Generar embedding
      final embedding = await _generateEmbedding(resizedFace);
      if (embedding == null) {
        return FaceDetectionResult(
          faceDetected: false,
          error: 'Error generando embedding',
        );
      }

      return FaceDetectionResult(
        faceDetected: true,
        embedding: embedding,
        croppedFace: ImageProcessor.imageToBytes(resizedFace),
      );
    } catch (e) {
      print('Error detectando rostro: $e');
      return FaceDetectionResult(
        faceDetected: false,
        error: 'Error procesando: $e',
      );
    }
  }

  /// Generar embedding con TensorFlow Lite
  Future<List<double>?> _generateEmbedding(img.Image faceImage) async {
    try {
      // Normalizar imagen para el modelo
      final input = ImageProcessor.normalizeImageForModel(faceImage);

      // Preparar tensores de salida
      final output = List.generate(1, (i) => List.filled(embeddingSize, 0.0));

      // Ejecutar inferencia
      _interpreter!.run(input, output);

      // Normalizar embedding
      final embedding = MathUtils.normalizeVector(output[0]);

      return embedding;
    } catch (e) {
      print('Error generando embedding: $e');
      return null;
    }
  }

  /// Emitir notificación de cambios en los rostros registrados
  void _notifyFacesChanged() {
    _facesController.add(List.unmodifiable(_registeredFaces));
  }

  /// Stream para escuchar cambios en los rostros registrados
  Stream<List<FaceData>> get facesStream => _facesController.stream;

  /// Registrar nuevo rostro
  Future<bool> registerFace({
    required String name,
    required List<double> embedding,
    required Uint8List faceImage,
  }) async {
    try {
      // Generar ID único
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Guardar imagen
      final imagePath = await _saveFaceImage(id, faceImage);

      // Crear datos del rostro
      final faceData = FaceData(
        id: id,
        name: name,
        embedding: embedding,
        imagePath: imagePath,
        createdAt: DateTime.now(),
      );

      // Agregar a la lista
      _registeredFaces.add(faceData);

      // Guardar en almacenamiento persistente
      await _saveRegisteredFaces();

      print('Rostro registrado: $name');
      _notifyFacesChanged();
      return true;
    } catch (e) {
      print('Error registrando rostro: $e');
      return false;
    }
  }

  /// Reconocer rostro
  Future<FaceRecognitionResult> recognizeFace(List<double> embedding) async {
    if (_registeredFaces.isEmpty) {
      return FaceRecognitionResult(recognized: false);
    }

    double bestSimilarity = 0.0;
    String? bestMatchId;
    String? bestMatchName;

    // Comparar con todos los rostros registrados
    for (final registeredFace in _registeredFaces) {
      // Comparar con todos los embeddings de esta persona
      for (final storedEmbedding in registeredFace.embeddings) {
        final similarity = MathUtils.cosineSimilarity(
          embedding,
          storedEmbedding,
        );

        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatchId = registeredFace.id;
          bestMatchName = registeredFace.name;
        }
      }
    }

    // Verificar si supera el umbral
    if (bestSimilarity >= recognitionThreshold) {
      return FaceRecognitionResult(
        recognized: true,
        personName: bestMatchName,
        personId: bestMatchId,
        confidence: MathUtils.confidenceToPercentage(bestSimilarity),
      );
    }

    return FaceRecognitionResult(recognized: false);
  }

  /// Guardar imagen del rostro
  Future<String> _saveFaceImage(String id, Uint8List imageBytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final facesDir = Directory('${directory.path}/faces');

    if (!await facesDir.exists()) {
      await facesDir.create(recursive: true);
    }

    final filePath = '${facesDir.path}/$id.png';
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);

    return filePath;
  }

  /// Cargar rostros registrados
  Future<void> _loadRegisteredFaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final facesJson = prefs.getString('registered_faces');

      if (facesJson != null) {
        final List<dynamic> facesList = json.decode(facesJson);
        _registeredFaces =
            facesList.map((faceJson) => FaceData.fromJson(faceJson)).toList();

        print('Cargados ${_registeredFaces.length} rostros registrados');
      }
    } catch (e) {
      print('Error cargando rostros: $e');
      _registeredFaces = [];
    }
    // Notificar a los oyentes sobre el estado inicial
    _notifyFacesChanged();
  }

  /// Guardar rostros registrados
  Future<void> _saveRegisteredFaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final facesJson = json.encode(
        _registeredFaces.map((face) => face.toJson()).toList(),
      );

      await prefs.setString('registered_faces', facesJson);
    } catch (e) {
      print('Error guardando rostros: $e');
    }
  }

  /// Obtener lista de rostros registrados
  List<FaceData> get registeredFaces => List.unmodifiable(_registeredFaces);

  /// Eliminar rostro registrado
  Future<bool> deleteFace(String id) async {
    try {
      // 1. Encontrar el rostro que se va a eliminar
      final faceIndex = _registeredFaces.indexWhere((face) => face.id == id);
      if (faceIndex == -1) {
        print('Error: Rostro con ID $id no encontrado para eliminar.');
        return false;
      }
      final faceToDelete = _registeredFaces[faceIndex];

      // 2. Eliminar la imagen del dispositivo
      final file = File(faceToDelete.imagePath);
      if (await file.exists()) {
        await file.delete();
        print('Archivo de imagen eliminado: ${faceToDelete.imagePath}');
      }

      // 3. Eliminar el rostro de la lista en memoria
      _registeredFaces.removeAt(faceIndex);

      // 4. Guardar la lista actualizada en el almacenamiento persistente
      await _saveRegisteredFaces();
      print('Rostro eliminado de la base de datos: ${faceToDelete.name}');

      // 5. Notificar a la UI sobre el cambio
      _notifyFacesChanged();

      return true;
    } catch (e) {
      print('Error fatal durante la eliminación del rostro: $e');
      return false;
    }
  }

  /// Limpiar recursos
  void dispose() {
    _interpreter?.close();
    _faceDetector?.close();
    _facesController.close();
    _isInitialized = false;
  }

  /// Mejorar registro existente con nuevo embedding
  Future<bool> improveFaceRegistration({
    required String personId,
    required List<double> newEmbedding,
  }) async {
    try {
      final index = _registeredFaces.indexWhere((face) => face.id == personId);
      if (index == -1) {
        print('Persona no encontrada: $personId');
        return false;
      }

      final existingFace = _registeredFaces[index];
      final improvedFace = existingFace.addEmbedding(newEmbedding);

      // Reemplazar en la lista
      _registeredFaces[index] = improvedFace;

      // Guardar en almacenamiento persistente
      await _saveRegisteredFaces();

      print(
          'Registro mejorado para: ${existingFace.name} (${improvedFace.embeddings.length} embeddings)');
      _notifyFacesChanged();
      return true;
    } catch (e) {
      print('Error mejorando registro: $e');
      return false;
    }
  }
}
