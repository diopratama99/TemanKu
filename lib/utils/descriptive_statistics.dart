import 'dart:math' as math;

/// Model untuk hasil perhitungan statistika deskriptif
class DescriptiveStatistics {
  final List<double> data;

  // Ukuran Pemusatan
  late final double mean;
  late final double median;
  late final double mode;

  // Ukuran Variasi
  late final double range;
  late final double variance;
  late final double standardDeviation;
  late final double coefficientOfVariation;

  // Kuartil, Desil, Persentil
  late final double q1; // Kuartil 1 (25%)
  late final double q2; // Kuartil 2 (50% = Median)
  late final double q3; // Kuartil 3 (75%)
  late final double iqr; // Interquartile Range

  late final Map<int, double> deciles; // Desil 1-9
  late final Map<int, double> percentiles; // Persentil tertentu

  // Boxplot Data
  late final double min;
  late final double max;
  late final double lowerFence; // Batas bawah outlier
  late final double upperFence; // Batas atas outlier
  late final List<double> outliers;

  // Ukuran Kemencengan (Skewness) dan Keruncingan (Kurtosis)
  late final double skewness;
  late final double kurtosis;

  // Z-Scores untuk setiap data
  late final List<double> zScores;

  DescriptiveStatistics(this.data) {
    if (data.isEmpty) {
      _initializeEmpty();
    } else {
      _calculate();
    }
  }

  void _initializeEmpty() {
    mean = 0;
    median = 0;
    mode = 0;
    range = 0;
    variance = 0;
    standardDeviation = 0;
    coefficientOfVariation = 0;
    q1 = 0;
    q2 = 0;
    q3 = 0;
    iqr = 0;
    deciles = {};
    percentiles = {};
    min = 0;
    max = 0;
    lowerFence = 0;
    upperFence = 0;
    outliers = [];
    skewness = 0;
    kurtosis = 0;
    zScores = [];
  }

  void _calculate() {
    final sortedData = List<double>.from(data)..sort();
    final n = data.length;

    // Min & Max
    min = sortedData.first;
    max = sortedData.last;

    // Mean (Rata-rata)
    mean = data.reduce((a, b) => a + b) / n;

    // Median
    median = _percentile(sortedData, 50);

    // Mode (Modus - nilai yang paling sering muncul)
    mode = _calculateMode(data);

    // Range (Rentang)
    range = max - min;

    // Variance (Varians)
    final squaredDiffs = data.map((x) => math.pow(x - mean, 2)).toList();
    variance = squaredDiffs.reduce((a, b) => a + b) / n;

    // Standard Deviation (Simpangan Baku)
    standardDeviation = math.sqrt(variance);

    // Coefficient of Variation (Koefisien Variasi)
    coefficientOfVariation = mean != 0 ? (standardDeviation / mean) * 100 : 0;

    // Kuartil
    q1 = _percentile(sortedData, 25);
    q2 = median;
    q3 = _percentile(sortedData, 75);
    iqr = q3 - q1;

    // Desil (D1 - D9)
    deciles = {for (int i = 1; i <= 9; i++) i: _percentile(sortedData, i * 10)};

    // Persentil (P10, P25, P50, P75, P90, P95, P99)
    percentiles = {
      10: _percentile(sortedData, 10),
      25: q1,
      50: median,
      75: q3,
      90: _percentile(sortedData, 90),
      95: _percentile(sortedData, 95),
      99: _percentile(sortedData, 99),
    };

    // Boxplot - Fence & Outliers
    lowerFence = q1 - (1.5 * iqr);
    upperFence = q3 + (1.5 * iqr);
    outliers = data.where((x) => x < lowerFence || x > upperFence).toList();

    // Z-Scores
    if (standardDeviation != 0) {
      zScores = data.map((x) => (x - mean) / standardDeviation).toList();
    } else {
      zScores = List.filled(n, 0);
    }

    // Skewness (Kemencengan)
    if (standardDeviation != 0) {
      final cubedDiffs = data
          .map((x) => math.pow((x - mean) / standardDeviation, 3))
          .toList();
      skewness = cubedDiffs.reduce((a, b) => a + b) / n;
    } else {
      skewness = 0;
    }

    // Kurtosis (Keruncingan)
    if (standardDeviation != 0) {
      final fourthDiffs = data
          .map((x) => math.pow((x - mean) / standardDeviation, 4))
          .toList();
      kurtosis =
          (fourthDiffs.reduce((a, b) => a + b) / n) - 3; // Excess kurtosis
    } else {
      kurtosis = 0;
    }
  }

  /// Menghitung persentil ke-p dari data terurut
  double _percentile(List<double> sortedData, int p) {
    if (sortedData.isEmpty) return 0;
    if (p <= 0) return sortedData.first;
    if (p >= 100) return sortedData.last;

    final n = sortedData.length;
    final position = (p / 100) * (n - 1);
    final lower = position.floor();
    final upper = position.ceil();

    if (lower == upper) {
      return sortedData[lower];
    }

    final weight = position - lower;
    return sortedData[lower] * (1 - weight) + sortedData[upper] * weight;
  }

  /// Menghitung modus (nilai yang paling sering muncul)
  double _calculateMode(List<double> data) {
    if (data.isEmpty) return 0;

    final frequency = <double, int>{};
    for (final value in data) {
      frequency[value] = (frequency[value] ?? 0) + 1;
    }

    int maxFreq = 0;
    double modeValue = data.first;

    frequency.forEach((value, freq) {
      if (freq > maxFreq) {
        maxFreq = freq;
        modeValue = value;
      }
    });

    // Jika semua frekuensi sama (tidak ada modus), return mean
    if (maxFreq == 1) return mean;

    return modeValue;
  }

  /// Interpretasi Skewness
  String get skewnessInterpretation {
    if (skewness.abs() < 0.5) {
      return 'Simetris (tidak miring)';
    } else if (skewness < -0.5) {
      return 'Miring ke kiri (negatif)';
    } else {
      return 'Miring ke kanan (positif)';
    }
  }

  /// Interpretasi Kurtosis
  String get kurtosisInterpretation {
    if (kurtosis.abs() < 0.5) {
      return 'Mesokurtik (normal)';
    } else if (kurtosis < -0.5) {
      return 'Platikurtik (datar)';
    } else {
      return 'Leptokurtik (runcing)';
    }
  }

  /// Mendapatkan kategori Z-Score
  static String getZScoreCategory(double zScore) {
    final absZ = zScore.abs();
    if (absZ < 1) {
      return 'Normal';
    } else if (absZ < 2) {
      return 'Agak Ekstrem';
    } else if (absZ < 3) {
      return 'Ekstrem';
    } else {
      return 'Sangat Ekstrem';
    }
  }

  /// Mengecek apakah nilai adalah outlier
  bool isOutlier(double value) {
    return value < lowerFence || value > upperFence;
  }

  @override
  String toString() {
    return '''
Descriptive Statistics:
- N: ${data.length}
- Mean: ${mean.toStringAsFixed(2)}
- Median: ${median.toStringAsFixed(2)}
- Mode: ${mode.toStringAsFixed(2)}
- Std Dev: ${standardDeviation.toStringAsFixed(2)}
- Skewness: ${skewness.toStringAsFixed(2)} ($skewnessInterpretation)
- Kurtosis: ${kurtosis.toStringAsFixed(2)} ($kurtosisInterpretation)
    ''';
  }
}
