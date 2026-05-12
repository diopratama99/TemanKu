import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../theme/app_theme.dart';
import '../utils/descriptive_statistics.dart';

/// Widget untuk menampilkan Boxplot
class BoxPlotWidget extends StatelessWidget {
  final DescriptiveStatistics stats;
  final String Function(num) formatValue;
  final Color color;

  const BoxPlotWidget({
    super.key,
    required this.stats,
    required this.formatValue,
    this.color = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.data.isEmpty) {
      return const Center(child: Text('Tidak ada data untuk ditampilkan'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        const Text(
          'Grafik Sebaran Data',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Grafik ini menunjukkan bagaimana uangmu tersebar dari nilai terkecil sampai terbesar',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        // Legend
        _buildLegend(),
        const SizedBox(height: 24),

        // Boxplot Chart
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _BoxPlotPainter(stats: stats, color: color),
            child: Container(),
          ),
        ),

        const SizedBox(height: 24),

        // Statistics Summary
        _buildStatsSummary(),

        // Outliers Info
        if (stats.outliers.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildOutliersInfo(),
        ],
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: Colors.red,
          label: 'Terkecil',
          value: formatValue(stats.min),
        ),
        _LegendItem(
          color: color.withOpacity(0.6),
          label: '25%',
          value: formatValue(stats.q1),
        ),
        _LegendItem(
          color: color,
          label: 'Tengah',
          value: formatValue(stats.median),
        ),
        _LegendItem(
          color: color.withOpacity(0.6),
          label: '75%',
          value: formatValue(stats.q3),
        ),
        _LegendItem(
          color: Colors.red,
          label: 'Terbesar',
          value: formatValue(stats.max),
        ),
      ],
    );
  }

  Widget _buildStatsSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow(label: 'Rentang Total', value: formatValue(stats.range)),
          const Divider(height: 16),
          _StatRow(
            label: 'Rentang Normal (50% data)',
            value: formatValue(stats.iqr),
          ),
        ],
      ),
    );
  }

  Widget _buildOutliersInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transaksi Tidak Biasa: ${stats.outliers.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Nilai-nilai ini jauh berbeda dari kebiasaan normalmu:',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: stats.outliers.map((outlier) {
              return Chip(
                label: Text(
                  formatValue(outlier),
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: Colors.orange.withOpacity(0.2),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Custom Painter untuk Boxplot
class _BoxPlotPainter extends CustomPainter {
  final DescriptiveStatistics stats;
  final Color color;

  _BoxPlotPainter({required this.stats, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2;

    final outlierPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    final fencePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Calculate positions
    final padding = 40.0;
    final plotWidth = size.width - (padding * 2);
    final centerY = size.height / 2;
    final boxHeight = size.height * 0.4;

    // Find data range for scaling
    final dataMin = stats.min;
    final dataMax = stats.max;
    final dataRange = dataMax - dataMin;

    if (dataRange == 0) return;

    // Scale function
    double scaleX(double value) {
      return padding + ((value - dataMin) / dataRange) * plotWidth;
    }

    final minX = scaleX(stats.min);
    final q1X = scaleX(stats.q1);
    final medianX = scaleX(stats.median);
    final q3X = scaleX(stats.q3);
    final maxX = scaleX(stats.max);
    final lowerFenceX = scaleX(stats.lowerFence);
    final upperFenceX = scaleX(stats.upperFence);

    // Draw fence lines (dashed)
    _drawDashedLine(
      canvas,
      Offset(lowerFenceX, centerY - boxHeight / 2),
      Offset(lowerFenceX, centerY + boxHeight / 2),
      fencePaint,
    );
    _drawDashedLine(
      canvas,
      Offset(upperFenceX, centerY - boxHeight / 2),
      Offset(upperFenceX, centerY + boxHeight / 2),
      fencePaint,
    );

    // Draw whiskers (min to Q1, Q3 to max)
    final whiskerY1 = centerY - boxHeight / 4;
    final whiskerY2 = centerY + boxHeight / 4;

    // Left whisker
    canvas.drawLine(Offset(minX, centerY), Offset(q1X, centerY), strokePaint);
    canvas.drawLine(
      Offset(minX, whiskerY1),
      Offset(minX, whiskerY2),
      strokePaint,
    );

    // Right whisker
    canvas.drawLine(Offset(q3X, centerY), Offset(maxX, centerY), strokePaint);
    canvas.drawLine(
      Offset(maxX, whiskerY1),
      Offset(maxX, whiskerY2),
      strokePaint,
    );

    // Draw box (Q1 to Q3)
    final boxRect = Rect.fromLTRB(
      q1X,
      centerY - boxHeight / 2,
      q3X,
      centerY + boxHeight / 2,
    );

    paint.color = color.withOpacity(0.3);
    canvas.drawRect(boxRect, paint);

    paint.style = PaintingStyle.stroke;
    paint.color = color;
    paint.strokeWidth = 2;
    canvas.drawRect(boxRect, paint);

    // Draw median line
    paint.style = PaintingStyle.fill;
    paint.color = color;
    canvas.drawRect(
      Rect.fromLTRB(
        medianX - 2,
        centerY - boxHeight / 2,
        medianX + 2,
        centerY + boxHeight / 2,
      ),
      paint,
    );

    // Draw outliers
    for (final outlier in stats.outliers) {
      final x = scaleX(outlier);
      canvas.drawCircle(Offset(x, centerY), 4, outlierPaint);
    }

    // Draw labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw axis labels
    _drawLabel(canvas, textPainter, 'Min', Offset(minX, size.height - 20));
    _drawLabel(canvas, textPainter, 'Q1', Offset(q1X, size.height - 20));
    _drawLabel(canvas, textPainter, 'Med', Offset(medianX, size.height - 20));
    _drawLabel(canvas, textPainter, 'Q3', Offset(q3X, size.height - 20));
    _drawLabel(canvas, textPainter, 'Max', Offset(maxX, size.height - 20));
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final distance = (end - start).distance;
    final normalizedDistance = (end - start) / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashEnd = math.min(currentDistance + dashWidth, distance);
      canvas.drawLine(
        start + normalizedDistance * currentDistance,
        start + normalizedDistance * dashEnd,
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  void _drawLabel(
    Canvas canvas,
    TextPainter textPainter,
    String text,
    Offset position,
  ) {
    textPainter.text = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 10,
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _BoxPlotPainter oldDelegate) {
    return oldDelegate.stats != stats || oldDelegate.color != color;
  }
}
