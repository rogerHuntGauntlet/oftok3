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
        title: Text('Analytics: ${widget.project.name}'),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Sessions',
              _analytics!['totalSessions'].toString(),
              Icons.timer,
            ),
            _buildMetricCard(
              'Avg Session Duration',
              '${(_analytics!['averageSessionDuration'] as Duration).inMinutes}m',
              Icons.access_time,
            ),
            _buildMetricCard(
              'Total Engagements',
              widget.project.totalEngagements.toString(),
              Icons.favorite,
            ),
            _buildMetricCard(
              'Avg Video Completion',
              '${(widget.project.averageVideoCompletionRate * 100).toStringAsFixed(1)}%',
              Icons.movie,
            ),
          ],
        );
      }
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
                    PieChartSectionData(
                      value: widget.project.likeCount.toDouble(),
                      title: 'Likes\n${widget.project.likeCount}',
                      color: Colors.red,
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: widget.project.commentCount.toDouble(),
                      title: 'Comments\n${widget.project.commentCount}',
                      color: Colors.blue,
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: widget.project.shareCount.toDouble(),
                      title: 'Shares\n${widget.project.shareCount}',
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
          ],
        ),
      ),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video ${entry.key}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
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