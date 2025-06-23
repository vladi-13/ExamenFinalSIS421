import 'dart:math' as math;

class MathUtils {
  /// Calcular distancia euclidiana entre dos vectores
  static double euclideanDistance(List<double> vector1, List<double> vector2) {
    if (vector1.length != vector2.length) {
      throw ArgumentError('Los vectores deben tener la misma longitud');
    }

    double sum = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      double diff = vector1[i] - vector2[i];
      sum += diff * diff;
    }
    return math.sqrt(sum);
  }

  /// Calcular similitud coseno entre dos vectores
  static double cosineSimilarity(List<double> vector1, List<double> vector2) {
    if (vector1.length != vector2.length) {
      throw ArgumentError('Los vectores deben tener la misma longitud');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (math.sqrt(norm1) * math.sqrt(norm2));
  }

  /// Normalizar vector (L2 normalization)
  static List<double> normalizeVector(List<double> vector) {
    double norm = 0.0;
    for (double value in vector) {
      norm += value * value;
    }
    norm = math.sqrt(norm);

    if (norm == 0.0) {
      return vector;
    }

    return vector.map((value) => value / norm).toList();
  }

  /// Convertir confianza a porcentaje
  static double confidenceToPercentage(double similarity) {
    return (similarity * 100).clamp(0.0, 100.0);
  }
}
