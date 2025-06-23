import 'dart:typed_data';

class FaceData {
  final String id;
  final String name;
  final List<List<double>> embeddings;
  final String imagePath;
  final DateTime createdAt;

  FaceData({
    required this.id,
    required this.name,
    required List<double> embedding,
    required this.imagePath,
    required this.createdAt,
  }) : embeddings = [embedding];

  FaceData.withMultipleEmbeddings({
    required this.id,
    required this.name,
    required this.embeddings,
    required this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'embeddings': embeddings,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FaceData.fromJson(Map<String, dynamic> json) {
    final embeddings =
        (json['embeddings'] as List).map((e) => List<double>.from(e)).toList();

    return FaceData.withMultipleEmbeddings(
      id: json['id'],
      name: json['name'],
      embeddings: embeddings,
      imagePath: json['imagePath'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  List<double> get primaryEmbedding => embeddings.first;

  FaceData addEmbedding(List<double> newEmbedding) {
    final newEmbeddings = List<List<double>>.from(embeddings);
    newEmbeddings.add(newEmbedding);

    return FaceData.withMultipleEmbeddings(
      id: id,
      name: name,
      embeddings: newEmbeddings,
      imagePath: imagePath,
      createdAt: createdAt,
    );
  }
}

class FaceDetectionResult {
  final bool faceDetected;
  final List<double>? embedding;
  final Uint8List? croppedFace;
  final String? error;

  FaceDetectionResult({
    required this.faceDetected,
    this.embedding,
    this.croppedFace,
    this.error,
  });
}

class FaceRecognitionResult {
  final bool recognized;
  final String? personName;
  final double? confidence;
  final String? personId;

  FaceRecognitionResult({
    required this.recognized,
    this.personName,
    this.confidence,
    this.personId,
  });
}
