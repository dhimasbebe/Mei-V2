import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/models/dashboard.dart';
import 'empty_state.dart';

/// Grafik garis interaktif untuk tren pemeliharaan (Tahap 3 — WS G).
///
/// * Sentuh/geser untuk melihat tooltip berisi nilai + tanggal (AC-G4).
/// * Warna garis memakai brand [AppColors.primary]; grid/teks dari
///   `context.pal` sehingga ikut mode gelap (tanpa hardcode warna).
/// * Menghormati *reduce-motion*: bila animasi sistem dimatikan, grafik
///   digambar seketika tanpa transisi masuk (AC-F5).
class InteractiveLineChart extends StatelessWidget {
  const InteractiveLineChart({
    super.key,
    required this.data,
    this.tinggi = 300,
    this.labelGaris,
  });

  /// Titik data (label = tanggal/periode, jumlah = nilai).
  final List<TrendPoint> data;

  /// Tinggi area grafik.
  final double tinggi;

  /// Nama seri pada tooltip (mis. "pemeliharaan").
  final String? labelGaris;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'Belum ada data',
        message: 'Tidak ada pemeliharaan pada periode ini.',
      );
    }

    final AppPalette pal = context.pal;
    final bool tanpaAnimasi =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final String satuan = labelGaris ?? 'pemeliharaan';
    final double maxY =
        data.map((TrendPoint t) => t.jumlah.toDouble()).reduce(
                  (double a, double b) => a > b ? a : b,
                ) *
            1.25;

    return SizedBox(
      height: tinggi,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 5 ? 5 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (double v) =>
                FlLine(color: pal.borderSubtle, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 34),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (data.length / 6).ceilToDouble().clamp(1, 60),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.toInt();
                  if (i < 0 || i >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final String l = data[i].label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l.length > 5 ? l.substring(5) : l,
                      style: TextStyle(fontSize: 9, color: pal.textSecondary),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) => pal.surfaceAlt,
              tooltipRoundedRadius: 8,
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((LineBarSpot s) {
                  final int i = s.x.toInt();
                  final String tanggal =
                      (i >= 0 && i < data.length) ? data[i].label : '${s.x}';
                  return LineTooltipItem(
                    '$tanggal\n${s.y.toInt()} $satuan',
                    TextStyle(
                      color: pal.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
            getTouchedSpotIndicator:
                (LineChartBarData bar, List<int> indexes) {
              return indexes.map((int i) {
                return TouchedSpotIndicatorData(
                  FlLine(color: AppColors.primary, strokeWidth: 1.5),
                  FlDotData(
                    getDotPainter: (
                      FlSpot spot,
                      double percent,
                      LineChartBarData barData,
                      int index,
                    ) =>
                        FlDotCirclePainter(
                      radius: 5,
                      color: pal.surface,
                      strokeWidth: 3,
                      strokeColor: AppColors.primary,
                    ),
                  ),
                );
              }).toList();
            },
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: data
                  .asMap()
                  .entries
                  .map((MapEntry<int, TrendPoint> e) =>
                      FlSpot(e.key.toDouble(), e.value.jumlah.toDouble()))
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.25,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: data.length <= 20,
                getDotPainter: (
                  FlSpot spot,
                  double percent,
                  LineChartBarData barData,
                  int index,
                ) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.primary,
                  strokeWidth: 1.5,
                  strokeColor: pal.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.primary.withValues(alpha: 0.28),
                    AppColors.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: tanpaAnimasi ? Duration.zero : const Duration(milliseconds: 220),
        curve: tanpaAnimasi ? Curves.linear : Curves.easeOutCubic,
      ),
    );
  }
}
