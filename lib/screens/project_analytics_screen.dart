import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/project.dart';
import '../services/analytics_service.dart';

class ProjectAnalyticsScreen extends StatefulWidget {
  final Project project;

  const ProjectAnalyticsScreen({Key? key, required this.project}) : super(key: key);

  @override
  _ProjectAnalyticsScreenState createState() => _ProjectAnalyticsScreenState();
}

class _ProjectAnalyticsScreenState extends State<ProjectAnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final analytics = await _analyticsService.getProjectAnalytics(widget.project.id);
    if (mounted) {
      setState(() {
        _analytics = analytics;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Project Analytics'),
            Text(
              widget.project.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _analytics == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadAnalytics,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildOverviewCards(),
                    const SizedBox(height: 24),
                    _buildEngagementChart(),
                    const SizedBox(height: 24),
                    _buildVideoCompletionRates(),
                    const SizedBox(height: 24), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card width based on screen size
        final screenWidth = constraints.maxWidth;
        final crossAxisCount = screenWidth > 600 ? 4 : 2;
        final cardWidth = (screenWidth - (16 * (crossAxisCount + 1))) / crossAxisCount;
        final cardHeight = cardWidth * 0.7; // Maintain aspect ratio

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildMetricCard(
              'Total Sessions',
              _analytics!['totalSessions'].toString(),
              Icons.timer,
              width: cardWidth,
              height: cardHeight,
            ),
            _buildMetricCard(
              'Avg Session',
              '${(_analytics!['averageSessionDuration'] as Duration).inMinutes}m',
              Icons.access_time,
              width: cardWidth,
              height: cardHeight,
            ),
            _buildMetricCard(
              'Engagements',
              widget.project.totalEngagements.toString(),
              Icons.favorite,
              width: cardWidth,
              height: cardHeight,
            ),
            _buildMetricCard(
              'Video Completion',
              '${(widget.project.averageVideoCompletionRate * 100).toStringAsFixed(1)}%',
              Icons.movie,
              width: cardWidth,
              height: cardHeight,
            ),
          ],
        );
      }
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, {required double width, required double height}) {
    return SizedBox(
      width: width,
      height: height,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementChart() {
    final totalEngagements = widget.project.totalEngagements;
    if (totalEngagements == 0) {
      return _buildEmptyState('No engagement data yet', Icons.bar_chart);
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Breakdown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.5,
              child: PieChart(
                PieChartData(
                  sections: [
                    if (widget.project.likeCount > 0)
                      PieChartSectionData(
                        value: widget.project.likeCount.toDouble(),
                        title: '${widget.project.likeCount}',
                        color: Colors.red,
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (widget.project.commentCount > 0)
                      PieChartSectionData(
                        value: widget.project.commentCount.toDouble(),
                        title: '${widget.project.commentCount}',
                        color: Colors.blue,
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (widget.project.shareCount > 0)
                      PieChartSectionData(
                        value: widget.project.shareCount.toDouble(),
                        title: '${widget.project.shareCount}',
                        color: Colors.green,
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('Likes', Colors.red, widget.project.likeCount),
                _buildLegendItem('Comments', Colors.blue, widget.project.commentCount),
                _buildLegendItem('Shares', Colors.green, widget.project.shareCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('$label: $value'),
      ],
    );
  }

  Widget _buildVideoCompletionRates() {
    if (widget.project.videoCompletionRates.isEmpty) {
      return _buildEmptyState('No video completion data yet', Icons.movie);
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Completion Rates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...widget.project.videoCompletionRates.entries.map((entry) {
              final completionRate = entry.value * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video ${entry.key}',
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${completionRate.toStringAsFixed(1)}% completed',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 