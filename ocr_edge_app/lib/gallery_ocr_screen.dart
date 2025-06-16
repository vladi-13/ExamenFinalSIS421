import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GalleryOCRScreen extends StatefulWidget {
  const GalleryOCRScreen({Key? key}) : super(key: key);

  @override
  _GalleryOCRScreenState createState() => _GalleryOCRScreenState();
}

class _GalleryOCRScreenState extends State<GalleryOCRScreen> {
  bool _isProcessing = false;
  String _extractedText = '';
  File? _selectedImage;
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<void> _pickImageFromGallery() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
          _extractedText = '';
        });

        await _processImageForOCR(_selectedImage!.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error seleccionando imagen: $e')));
    }
  }

  Future<void> _processImageForOCR(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

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

      setState(() {
        _extractedText = extractedText.isNotEmpty
            ? extractedText
            : 'No se detectó texto en la imagen';
      });

      // Guardar el historial de escaneo
      if (_extractedText.isNotEmpty &&
          _extractedText != 'No se detectó texto en la imagen') {
        await _saveScanHistory(imagePath, _extractedText);
      }
    } catch (e) {
      setState(() {
        _extractedText = 'Error al procesar la imagen: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveScanHistory(String imagePath, String extractedText) async {
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
      'text': extractedText,
      'timestamp': DateTime.now().toIso8601String(),
      'imagePath': imagePath,
    });
    await prefs.setString('scan_history', json.encode(history));
  }

  void _clearAll() {
    setState(() {
      _selectedImage = null;
      _extractedText = '';
    });
  }

  @override
  void dispose() {
    _textRecognizer.close();
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
        actions: [
          if (_selectedImage != null || _extractedText.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _clearAll,
              tooltip: 'Limpiar todo',
            ),
        ],
      ),
      body: Column(
        children: [
          // Área de imagen seleccionada
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _selectedImage != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (_isProcessing)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Procesando imagen...',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Selecciona una imagen',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Toca el botón para elegir una imagen de tu galería',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                      Icon(Icons.text_fields, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Texto Extraído:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade800,
                        ),
                      ),
                      Spacer(),
                      if (_extractedText.isNotEmpty &&
                          _extractedText != 'No se detectó texto en la imagen')
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
                              ? 'El texto extraído aparecerá aquí...'
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

      // Botón de selección
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _pickImageFromGallery,
        icon: Icon(_isProcessing ? Icons.hourglass_empty : Icons.photo_library),
        label: Text(_isProcessing ? 'Procesando...' : 'Seleccionar Imagen'),
        backgroundColor: _isProcessing ? Colors.grey : Colors.purple,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
