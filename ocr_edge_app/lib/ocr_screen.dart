import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart';

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
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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
      ResolutionPreset.high,
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

  Future<void> _captureAndProcessImage() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _extractedText = '';
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      await _processImageForOCR(picture.path);
    } catch (e) {
      print('Error capturando imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processImageForOCR(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final InputImage inputImage = InputImage.fromFile(imageFile);

      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += line.text + '\n';
        }
      }

      if (mounted) {
        setState(() {
          _extractedText = extractedText.isNotEmpty
              ? extractedText
              : 'No se detectó texto en la imagen';
        });
      }

      await _saveProcessedImage(imageFile);
    } catch (e) {
      print('Error procesando OCR: $e');
      if (mounted) {
        setState(() {
          _extractedText = 'Error al procesar la imagen: $e';
        });
      }
    }
  }

  Future<void> _saveProcessedImage(File imageFile) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savePath = join(appDir.path, fileName);

      await imageFile.copy(savePath);
      print('Imagen guardada en: $savePath');

      // Guardar el historial de escaneo
      final prefs = await SharedPreferences.getInstance();
      final String? historyString = prefs.getString('scan_history');
      List<Map<String, String>> history = [];
      if (historyString != null) {
        history = List<Map<String, String>>.from(
          json
              .decode(historyString)
              .map((item) => Map<String, String>.from(item)),
        );
      }
      history.insert(0, {
        // Añadir al principio para mostrar lo más reciente primero
        'text': _extractedText,
        'timestamp': DateTime.now().toIso8601String(),
        'imagePath': savePath,
      });
      await prefs.setString('scan_history', json.encode(history));
    } catch (e) {
      print('Error guardando imagen: $e');
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
    _textRecognizer.close();
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
                          CameraPreview(_cameraController!),
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
            ? _captureAndProcessImage
            : null,
        icon: Icon(_isProcessing ? Icons.hourglass_empty : Icons.camera_alt),
        label: Text(_isProcessing ? 'Procesando...' : 'Capturar'),
        backgroundColor: _isProcessing ? Colors.grey : Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
