import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Donut Chart untuk menampilkan distribusi per kategori
class CategoryDonutChart extends StatefulWidget {
  final Map<String, double> categoryData;
  final String title;
  final Color primaryColor;

  const CategoryDonutChart({
    super.key,
    required this.categoryData,
    required this.title,
    this.primaryColor = Colors.blue,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categoryData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Belum ada data untuk ditampilkan',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final total = widget.categoryData.values.reduce((a, b) => a + b);
    final sortedEntries = widget.categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart
        SizedBox(
          height: 200,
          child: Row(
            children: [
              // Donut Chart
              Expanded(
                flex: 5,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 45,
                    sections: _buildSections(sortedEntries, total),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Legend
              Expanded(flex: 3, child: _buildLegend(sortedEntries, total)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Detail List
        _buildDetailList(sortedEntries, total),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(
    List<MapEntry<String, double>> entries,
    double total,
  ) {
    final colors = _generateColors(entries.length);

    return List.generate(entries.length, (index) {
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 55.0 : 50.0;
      final fontSize = isTouched ? 12.0 : 11.0;

      final percentage = (entries[index].value / total * 100);

      return PieChartSectionData(
        color: colors[index],
        value: entries[index].value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    });
  }

  Widget _buildLegend(List<MapEntry<String, double>> entries, double total) {
    final colors = _generateColors(entries.length);
    final displayEntries = entries.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayEntries.length,
      itemBuilder: (context, index) {
        final entry = displayEntries[index];
        final percentage = (entry.value / total * 100);
        final categoryName = _extractCategoryName(entry.key);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            children: [
              // Dot indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  categoryName,
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailList(
    List<MapEntry<String, double>> entries,
    double total,
  ) {
    final colors = _generateColors(entries.length);
    final money = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detail per Kategori:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          final percentage = (entry.value / total * 100);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors[index].withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors[index].withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Emoji/Icon from category name
                Text(
                  _extractEmoji(entry.key),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _extractCategoryName(entry.key),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money.format(entry.value),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors[index],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors[index],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Extract emoji from category name (format: "🎓 Pendidikan")
  String _extractEmoji(String categoryName) {
    if (categoryName.isEmpty) return '📝';
    final parts = categoryName.split(' ');
    if (parts.isEmpty) return '📝';
    // First part should be emoji
    return parts[0];
  }

  // Extract category name without emoji
  String _extractCategoryName(String categoryName) {
    if (categoryName.isEmpty) return categoryName;
    final parts = categoryName.split(' ');
    if (parts.length <= 1) return categoryName;
    // Join all parts except first (emoji)
    return parts.sublist(1).join(' ');
  }

  List<Color> _generateColors(int count) {
    // Palet warna yang bagus dan kontras
    const baseColors = [
      Color(0xFFE74C3C), // Red
      Color(0xFF3498DB), // Blue
      Color(0xFF2ECC71), // Green
      Color(0xFFF39C12), // Orange
      Color(0xFF9B59B6), // Purple
      Color(0xFF1ABC9C), // Turquoise
      Color(0xFFE67E22), // Carrot
      Color(0xFF34495E), // Dark Blue Gray
      Color(0xFFFF6B9D), // Pink
      Color(0xFF16A085), // Green Sea
    ];

    if (count <= baseColors.length) {
      return baseColors.take(count).toList();
    }

    // Jika lebih dari 10, generate warna tambahan
    final colors = List<Color>.from(baseColors);
    for (int i = baseColors.length; i < count; i++) {
      colors.add(_generateColor(i));
    }
    return colors;
  }

  Color _generateColor(int index) {
    final hue = (index * 137.5) % 360; // Golden angle
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }
}
