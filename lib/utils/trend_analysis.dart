import 'dart:math' as math;

/// Kelas untuk hasil analisis tren
class TrendAnalysis {
  final double slope; // Kemiringan (m)
  final double intercept; // Intersep (b)
  final double correlation; // Korelasi (r)
  final double rSquared; // R² (koefisien determinasi)
  final List<double> predictions; // Prediksi nilai

  TrendAnalysis({
    required this.slope,
    required this.intercept,
    required this.correlation,
    required this.rSquared,
    required this.predictions,
  });

  /// Prediksi nilai untuk x tertentu
  double predict(double x) => slope * x + intercept;

  /// Persentase perubahan rata-rata
  double get averageChangePercent => slope * 100;
}

/// Kelas untuk analisis korelasi
class CorrelationAnalysis {
  final double correlation; // Nilai korelasi (r)
  final String strength; // Kekuatan hubungan
  final String direction; // Arah hubungan

  CorrelationAnalysis({
    required this.correlation,
    required this.strength,
    required this.direction,
  });
}

/// Utility untuk analisis tren dan statistik
class TrendAnalysisUtils {
  /// Regresi linear: y = mx + b
  /// x = waktu (index), y = nilai transaksi
  static TrendAnalysis linearRegression(List<double> values) {
    if (values.isEmpty) {
      return TrendAnalysis(
        slope: 0,
        intercept: 0,
        correlation: 0,
        rSquared: 0,
        predictions: [],
      );
    }

    final n = values.length;
    final x = List.generate(n, (i) => i.toDouble()); // [0, 1, 2, ...]

    // Hitung rata-rata
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = values.reduce((a, b) => a + b) / n;

    // Hitung slope (m) dan intercept (b)
    double numerator = 0;
    double denominator = 0;

    for (int i = 0; i < n; i++) {
      numerator += (x[i] - xMean) * (values[i] - yMean);
      denominator += math.pow(x[i] - xMean, 2);
    }

    final slope = denominator != 0 ? numerator / denominator : 0;
    final intercept = yMean - slope * xMean;

    // Hitung korelasi (r)
    double sumXY = 0;
    double sumX2 = 0;
    double sumY2 = 0;

    for (int i = 0; i < n; i++) {
      final xDiff = x[i] - xMean;
      final yDiff = values[i] - yMean;
      sumXY += xDiff * yDiff;
      sumX2 += xDiff * xDiff;
      sumY2 += yDiff * yDiff;
    }

    final correlation = (sumX2 * sumY2) != 0
        ? sumXY / math.sqrt(sumX2 * sumY2)
        : 0;

    // R² (koefisien determinasi)
    final rSquared = math.pow(correlation, 2).toDouble();

    // Buat prediksi untuk semua titik + 3 titik ke depan
    final predictions = List.generate(n + 3, (i) => slope * i + intercept);

    return TrendAnalysis(
      slope: slope.toDouble(),
      intercept: intercept.toDouble(),
      correlation: correlation.toDouble(),
      rSquared: rSquared,
      predictions: predictions,
    );
  }

  /// Korelasi Pearson antara dua variabel
  static CorrelationAnalysis correlation(List<double> x, List<double> y) {
    if (x.isEmpty || y.isEmpty || x.length != y.length) {
      return CorrelationAnalysis(
        correlation: 0,
        strength: 'Tidak ada data',
        direction: 'Netral',
      );
    }

    final n = x.length;
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;

    double sumXY = 0;
    double sumX2 = 0;
    double sumY2 = 0;

    for (int i = 0; i < n; i++) {
      final xDiff = x[i] - xMean;
      final yDiff = y[i] - yMean;
      sumXY += xDiff * yDiff;
      sumX2 += xDiff * xDiff;
      sumY2 += yDiff * yDiff;
    }

    final r = (sumX2 * sumY2) != 0 ? sumXY / math.sqrt(sumX2 * sumY2) : 0;

    // Tentukan kekuatan hubungan
    final absR = r.abs();
    String strength;
    if (absR >= 0.8) {
      strength = 'Sangat Kuat';
    } else if (absR >= 0.6) {
      strength = 'Kuat';
    } else if (absR >= 0.4) {
      strength = 'Sedang';
    } else if (absR >= 0.2) {
      strength = 'Lemah';
    } else {
      strength = 'Sangat Lemah';
    }

    // Tentukan arah hubungan
    final direction = r > 0
        ? 'Positif'
        : r < 0
        ? 'Negatif'
        : 'Netral';

    return CorrelationAnalysis(
      correlation: r.toDouble(),
      strength: strength,
      direction: direction,
    );
  }

  /// Hitung rata-rata
  static double mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Hitung standar deviasi
  static double standardDeviation(List<double> values) {
    if (values.isEmpty) return 0;

    final avg = mean(values);
    final variance =
        values.map((v) => math.pow(v - avg, 2)).reduce((a, b) => a + b) /
        values.length;

    return math.sqrt(variance);
  }

  /// Hitung persentase perubahan
  static double percentChange(double oldValue, double newValue) {
    if (oldValue == 0) return 0;
    return ((newValue - oldValue) / oldValue) * 100;
  }
}
