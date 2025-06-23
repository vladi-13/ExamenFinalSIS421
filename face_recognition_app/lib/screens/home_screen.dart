import 'package:flutter/material.dart';
import 'dart:async';
import 'camera_screen.dart';
import 'registered_faces_screen.dart';
import '../services/face_recognition_service.dart';
import '../models/face_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInitializing = true;
  String _status = 'Inicializando...';
  List<FaceData> _registeredFaces = [];
  StreamSubscription<List<FaceData>>? _facesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _subscribeToFacesChanges();
  }

  @override
  void dispose() {
    _facesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    setState(() {
      _status = 'Cargando modelo de IA...';
    });

    final success = await FaceRecognitionService.instance.initialize();

    setState(() {
      _isInitializing = false;
      _status = success ? 'Servicio listo' : 'Error inicializando servicio';
    });
  }

  void _subscribeToFacesChanges() {
    // Obtener el estado inicial al suscribirse
    if (mounted) {
      setState(() {
        _registeredFaces = FaceRecognitionService.instance.registeredFaces;
      });
    }

    // Escuchar cambios futuros
    _facesSubscription =
        FaceRecognitionService.instance.facesStream.listen((faces) {
      if (mounted) {
        setState(() {
          _registeredFaces = faces;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconocimiento Facial IA'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isInitializing ? _buildLoadingView() : _buildMainView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _status,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    final registeredCount = _registeredFaces.length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.face,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sistema de Reconocimiento Facial',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Edge AI - Procesamiento local',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Estadísticas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$registeredCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text('Rostros\nRegistrados'),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          '< 200ms',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const Text('Tiempo de\nReconocimiento'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Botones principales
            ElevatedButton.icon(
              onPressed: () => _navigateToCamera(CameraMode.recognize),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Reconocer Rostro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () => _navigateToCamera(CameraMode.register),
              icon: const Icon(Icons.person_add),
              label: const Text('Registrar Nuevo Rostro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () => _navigateToRegisteredFaces(),
              icon: const Icon(Icons.people),
              label: Text('Ver Rostros Registrados ($registeredCount)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Consejos para mejor reconocimiento
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Consejos para mejor reconocimiento',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTip('💡', 'Buena iluminación frontal'),
                    _buildTip('📐', 'Rostro centrado y frontal'),
                    _buildTip('😐', 'Expresión neutra al registrar'),
                    _buildTip('📱', 'Mantén el dispositivo estable'),
                    _buildTip('🔄', 'Registra múltiples ángulos'),
                    _buildTip(
                        '✨', 'Usa "Mejorar Registro" si la confianza es baja'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCamera(CameraMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(mode: mode),
      ),
    );
  }

  void _navigateToRegisteredFaces() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisteredFacesScreen(),
      ),
    );
  }
}
