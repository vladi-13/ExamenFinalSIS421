import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart';
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

class OCRScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const OCRScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _OCRScreenState createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _extractedText = '';
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    // Solicitar permisos
    final cameraPermission = await Permission.camera.request();

    if (cameraPermission != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Permiso de cámara requerido'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (widget.cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('No se encontraron cámaras'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error inicializando cámara: $e');
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Error inicializando cámara: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _captureAndProcess() async {
    if (!_isCameraInitialized || _isProcessing) return;

    try {
      final image = await _cameraController!.takePicture();
      await _processImageForOCR(image.path);
    } catch (e) {
      print('Error capturando imagen: $e');
    }
  }

  void _clearText() {
    setState(() {
      _extractedText = '';
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'OCR con Cámara',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          if (_extractedText.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: _clearText,
              tooltip: 'Limpiar texto',
            ),
        ],
      ),
      body: Column(
        children: [
          // Vista previa de la cámara
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isCameraInitialized
                    ? Stack(
                        children: [
                          FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width:
                                  _cameraController!
                                      .value
                                      .previewSize
                                      ?.height ??
                                  1,
                              height:
                                  _cameraController!.value.previewSize?.width ??
                                  1,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                          if (_isProcessing)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Procesando imagen...',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Overlay de guías
                          if (!_isProcessing)
                            Container(
                              margin: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.blue),
                              SizedBox(height: 16),
                              Text(
                                'Inicializando cámara...',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Área de texto extraído
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Texto Extraído:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Spacer(),
                      if (_extractedText.isNotEmpty &&
                          _extractedText !=
                              'Captura una imagen para extraer texto...')
                        IconButton(
                          icon: Icon(Icons.copy, color: Colors.grey.shade600),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _extractedText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Texto copiado al portapapeles'),
                              ),
                            );
                          },
                          tooltip: 'Copiar texto',
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _extractedText.isEmpty
                              ? 'Captura una imagen para extraer texto...'
                              : _extractedText,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.4,
                            color: _extractedText.isEmpty
                                ? Colors.grey.shade500
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Botón de captura
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCameraInitialized && !_isProcessing
            ? _captureAndProcess
            : null,
        icon: Icon(_isProcessing ? Icons.hourglass_empty : Icons.camera_alt),
        label: Text(_isProcessing ? 'Procesando...' : 'Capturar'),
        backgroundColor: _isProcessing ? Colors.grey : Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
