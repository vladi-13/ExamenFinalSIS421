import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_recognition_service.dart';
import '../models/face_data.dart';

enum CameraMode { recognize, register }

class CameraScreen extends StatefulWidget {
  final CameraMode mode;

  const CameraScreen({Key? key, required this.mode}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _status = 'Inicializando cámara...';
  String? _lastResult;
  FaceRecognitionResult? _lastRecognitionResult; // Para mejorar registro

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Solicitar permisos
    final cameraPermission = await Permission.camera.request();
    if (cameraPermission != PermissionStatus.granted) {
      setState(() {
        _status = 'Permiso de cámara denegado';
      });
      return;
    }

    try {
      // Obtener cámaras disponibles
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _status = 'No se encontraron cámaras';
        });
        return;
      }

      // Inicializar controlador con cámara frontal si está disponible
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      setState(() {
        _isInitialized = true;
        _status = widget.mode == CameraMode.recognize
            ? 'Posiciona tu rostro en el marco'
            : 'Prepárate para registrar tu rostro';
      });
    } catch (e) {
      setState(() {
        _status = 'Error inicializando cámara: $e';
      });
    }
  }

  Future<void> _captureAndProcess() async {
    if (!_isInitialized || _isProcessing || _controller == null) return;

    setState(() {
      _isProcessing = true;
      _status = 'Procesando...';
      _lastResult = null;
    });

    try {
      // Capturar imagen
      final image = await _controller!.takePicture();

      // Procesar rostro
      final result =
          await FaceRecognitionService.instance.detectAndProcessFace(image);

      if (!result.faceDetected) {
        setState(() {
          _status = result.error ?? 'No se detectó rostro';
          _isProcessing = false;
        });
        return;
      }

      if (widget.mode == CameraMode.recognize) {
        await _handleRecognition(result);
      } else {
        await _handleRegistration(result);
      }
    } catch (e) {
      setState(() {
        _status = 'Error procesando imagen: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleRecognition(FaceDetectionResult result) async {
    if (result.embedding == null) {
      setState(() {
        _status = 'Error generando embedding';
        _isProcessing = false;
        _lastRecognitionResult = null;
      });
      return;
    }

    final recognition =
        await FaceRecognitionService.instance.recognizeFace(result.embedding!);

    setState(() {
      _lastRecognitionResult = recognition;

      if (recognition.recognized) {
        final confidence = recognition.confidence ?? 0.0;

        if (confidence >= 85) {
          _status = '¡Rostro reconocido!';
          _lastResult = '${recognition.personName}\n'
              'Confianza: ${confidence.toStringAsFixed(1)}%';
        } else if (confidence >= 70) {
          _status = 'Rostro probablemente reconocido';
          _lastResult = '${recognition.personName}\n'
              'Confianza: ${confidence.toStringAsFixed(1)}%\n'
              '(Confianza baja - considerar mejorar registro)';
        } else {
          _status = 'Rostro reconocido con baja confianza';
          _lastResult = '${recognition.personName}\n'
              'Confianza: ${confidence.toStringAsFixed(1)}%\n'
              '(Muy baja confianza)';
        }
      } else {
        _status = 'Rostro no reconocido';
        _lastResult = 'Persona desconocida\n'
            'Considera registrar este rostro';
      }
      _isProcessing = false;
    });
  }

  Future<void> _handleRegistration(FaceDetectionResult result) async {
    if (result.embedding == null || result.croppedFace == null) {
      setState(() {
        _status = 'Error procesando rostro';
        _isProcessing = false;
      });
      return;
    }

    // Solicitar nombre
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) {
      setState(() {
        _status = 'Registro cancelado';
        _isProcessing = false;
      });
      return;
    }

    // Registrar rostro
    final success = await FaceRecognitionService.instance.registerFace(
      name: name,
      embedding: result.embedding!,
      faceImage: result.croppedFace!,
    );

    setState(() {
      if (success) {
        _status = '¡Rostro registrado exitosamente!';
        _lastResult = 'Bienvenido, $name';
      } else {
        _status = 'Error registrando rostro';
        _lastResult = 'Inténtalo de nuevo';
      }
      _isProcessing = false;
    });
  }

  Future<String?> _showNameDialog() async {
    String? name;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Rostro'),
        content: TextField(
          onChanged: (value) => name = value,
          decoration: const InputDecoration(
            labelText: 'Nombre de la persona',
            hintText: 'Ingresa el nombre',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, name),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _improveRegistration() async {
    if (_lastRecognitionResult == null ||
        !_lastRecognitionResult!.recognized ||
        _lastRecognitionResult!.personId == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Mejorando registro...';
    });

    try {
      // Capturar nueva imagen para mejorar el registro
      final image = await _controller!.takePicture();
      final result =
          await FaceRecognitionService.instance.detectAndProcessFace(image);

      if (result.faceDetected && result.embedding != null) {
        final success =
            await FaceRecognitionService.instance.improveFaceRegistration(
          personId: _lastRecognitionResult!.personId!,
          newEmbedding: result.embedding!,
        );

        setState(() {
          if (success) {
            _status = '¡Registro mejorado!';
            _lastResult = 'Se agregó una nueva variación del rostro\n'
                'para ${_lastRecognitionResult!.personName}';
          } else {
            _status = 'Error mejorando registro';
            _lastResult = 'Inténtalo de nuevo';
          }
          _isProcessing = false;
        });
      } else {
        setState(() {
          _status = 'No se detectó rostro para mejorar';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error mejorando registro: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == CameraMode.recognize
            ? 'Reconocer Rostro'
            : 'Registrar Rostro'),
        backgroundColor: widget.mode == CameraMode.recognize
            ? Colors.blue.shade700
            : Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Vista de cámara
          Expanded(
            flex: 3,
            child: _buildCameraView(),
          ),

          // Panel de información
          Expanded(
            flex: 1,
            child: _buildInfoPanel(),
          ),
        ],
      ),
      floatingActionButton: _buildCaptureButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraView() {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Vista de cámara
        CameraPreview(_controller!),

        // Overlay con guía facial
        CustomPaint(
          painter: FaceGuidePainter(),
        ),

        // Indicador de procesamiento
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Procesando con IA...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Estado actual
            Text(
              _status,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Resultado
            if (_lastResult != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.mode == CameraMode.recognize
                      ? Colors.blue.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.mode == CameraMode.recognize
                        ? Colors.blue.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  _lastResult!,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.mode == CameraMode.recognize
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Botón para mejorar registro (solo en modo reconocimiento)
            if (widget.mode == CameraMode.recognize &&
                _lastRecognitionResult != null &&
                _lastRecognitionResult!.recognized &&
                (_lastRecognitionResult!.confidence ?? 0) < 85)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _improveRegistration,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Mejorar Registro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return FloatingActionButton.extended(
      onPressed: _isInitialized && !_isProcessing ? _captureAndProcess : null,
      backgroundColor: widget.mode == CameraMode.recognize
          ? Colors.blue.shade700
          : Colors.green.shade700,
      foregroundColor: Colors.white,
      icon: Icon(widget.mode == CameraMode.recognize
          ? Icons.search
          : Icons.person_add),
      label:
          Text(widget.mode == CameraMode.recognize ? 'Reconocer' : 'Registrar'),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// Painter para la guía facial
class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Dibujar óvalo guía en el centro
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3;

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: radius * 2.2,
      ),
      paint,
    );

    // Dibujar esquinas
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final ovalRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2.2,
    );

    // Esquina superior izquierda
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top),
      Offset(ovalRect.left + cornerLength, ovalRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top),
      Offset(ovalRect.left, ovalRect.top + cornerLength),
      cornerPaint,
    );

    // Esquina superior derecha
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.top),
      Offset(ovalRect.right - cornerLength, ovalRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.top),
      Offset(ovalRect.right, ovalRect.top + cornerLength),
      cornerPaint,
    );

    // Esquina inferior izquierda
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom),
      Offset(ovalRect.left + cornerLength, ovalRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom),
      Offset(ovalRect.left, ovalRect.bottom - cornerLength),
      cornerPaint,
    );

    // Esquina inferior derecha
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.bottom),
      Offset(ovalRect.right - cornerLength, ovalRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.bottom),
      Offset(ovalRect.right, ovalRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
