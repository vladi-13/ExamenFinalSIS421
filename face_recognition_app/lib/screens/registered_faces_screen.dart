import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../services/face_recognition_service.dart';
import '../models/face_data.dart';

class RegisteredFacesScreen extends StatefulWidget {
  const RegisteredFacesScreen({Key? key}) : super(key: key);

  @override
  State<RegisteredFacesScreen> createState() => _RegisteredFacesScreenState();
}

class _RegisteredFacesScreenState extends State<RegisteredFacesScreen> {
  List<FaceData> _faces = [];
  StreamSubscription<List<FaceData>>? _facesSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToFacesChanges();
  }

  @override
  void dispose() {
    _facesSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToFacesChanges() {
    // Obtener el estado inicial al suscribirse
    if (mounted) {
      setState(() {
        _faces = FaceRecognitionService.instance.registeredFaces;
      });
    }

    // Escuchar cambios futuros
    _facesSubscription =
        FaceRecognitionService.instance.facesStream.listen((faces) {
      if (mounted) {
        setState(() {
          _faces = faces;
        });
      }
    });
  }

  Future<void> _deleteFace(FaceData face) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
            '¿Estás seguro de que quieres eliminar a ${face.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await FaceRecognitionService.instance.deleteFace(face.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${face.name} ha sido eliminado.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar el rostro. Inténtalo de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rostros Registrados (${_faces.length})'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: _faces.isEmpty ? _buildEmptyView() : _buildFacesList(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.face_retouching_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay rostros registrados',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa la función "Registrar Nuevo Rostro" para agregar personas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFacesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _faces.length,
      itemBuilder: (context, index) {
        final face = _faces[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _buildFaceImage(face),
            title: Text(
              face.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrado: ${_formatDate(face.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${face.id}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteFace(face);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _showFaceDetails(face),
          ),
        );
      },
    );
  }

  Widget _buildFaceImage(FaceData face) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: File(face.imagePath).existsSync()
            ? Image.file(
                File(face.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        color: Colors.grey.shade400,
        size: 32,
      ),
    );
  }

  void _showFaceDetails(FaceData face) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(face.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.shade200,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: File(face.imagePath).existsSync()
                      ? Image.file(
                          File(face.imagePath),
                          fit: BoxFit.cover,
                        )
                      : _buildPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Nombre:', face.name),
            _buildDetailRow('ID:', face.id),
            _buildDetailRow('Registrado:', _formatDate(face.createdAt)),
            _buildDetailRow(
                'Embeddings:', '${face.embeddings.length} variaciones'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFace(face);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
