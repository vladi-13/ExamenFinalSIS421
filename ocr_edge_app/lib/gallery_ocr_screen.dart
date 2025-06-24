import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart' as img;

// Lista de clases reconocidas por el modelo (0-9, A-Z)
const List<String> ocrClasses = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

class GalleryOCRScreen extends StatefulWidget {
  const GalleryOCRScreen({Key? key}) : super(key: key);

  @override
  _GalleryOCRScreenState createState() => _GalleryOCRScreenState();
}

class _GalleryOCRScreenState extends State<GalleryOCRScreen> {
  bool _isProcessing = false;
  String _extractedText = '';
  String? _selectedImagePath;
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'model_hybrid_quantized.tflite',
      );
      print('Modelo TFLite cargado correctamente');
    } catch (e) {
      print('Error cargando el modelo TFLite: $e');
    }
  }

  Future<void> _pickAndProcessImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path!;
        setState(() {
          _selectedImagePath = path;
          _extractedText = '';
        });
        await _processImageForOCR(path);
      }
    } catch (e) {
      print('Error seleccionando imagen: $e');
    }
  }

  Future<void> _processImageForOCR(String imagePath) async {
    if (_interpreter == null) {
      print('Intérprete no inicializado');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Leer y preprocesar la imagen
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('No se pudo decodificar la imagen');

      // Convertir a escala de grises y redimensionar
      final grayscale = img.grayscale(image);
      final resized = img.copyResize(grayscale, width: 64, height: 64);

      // Convertir a tensor y normalizar (0-255)
      var inputArray = Float32List(1 * 64 * 64 * 1);
      var inputIndex = 0;
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          // Obtener el valor de gris (0-255) y mantenerlo en ese rango
          inputArray[inputIndex++] = img
              .getRed(resized.getPixel(x, y))
              .toDouble();
        }
      }

      // Preparar el tensor de salida (36 clases)
      var outputArray = Float32List(1 * 36);

      // Ejecutar la inferencia
      var inputShape = [1, 64, 64, 1];
      var outputShape = [1, 36];

      _interpreter!.resizeInputTensor(0, inputShape);
      _interpreter!.allocateTensors();

      _interpreter!.run(inputArray, outputArray);

      // Encontrar la clase con mayor probabilidad
      var maxIndex = 0;
      var maxValue = outputArray[0];
      for (var i = 1; i < 36; i++) {
        if (outputArray[i] > maxValue) {
          maxValue = outputArray[i];
          maxIndex = i;
        }
      }

      // Obtener el carácter reconocido
      final recognizedChar = ocrClasses[maxIndex];

      // Guardar en el historial
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('ocr_history') ?? [];
      history.insert(
        0,
        'Carácter reconocido: $recognizedChar (${DateTime.now()})',
      );
      await prefs.setStringList('ocr_history', history);

      setState(() {
        _extractedText = recognizedChar;
        _isProcessing = false;
      });
    } catch (e) {
      print('Error en el procesamiento OCR: $e');
      setState(() {
        _extractedText = 'Error en el reconocimiento';
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'OCR desde Galería',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple.shade50,
        foregroundColor: Colors.purple.shade800,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_selectedImagePath != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.file(
                  File(_selectedImagePath!),
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_isProcessing)
                    const CircularProgressIndicator()
                  else
                    Text(
                      _extractedText.isEmpty ? 'No hay texto' : _extractedText,
                      style: const TextStyle(fontSize: 24),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _pickAndProcessImage,
                    child: const Text('Seleccionar Imagen'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
