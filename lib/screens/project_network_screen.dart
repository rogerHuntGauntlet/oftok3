import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:ohftokv3/models/project.dart';
import 'package:ohftokv3/services/project_service.dart';
import 'project_details_screen.dart';
import 'dart:math' as math;

class ProjectNetworkScreen extends StatefulWidget {
  const ProjectNetworkScreen({super.key});

  @override
  State<ProjectNetworkScreen> createState() => _ProjectNetworkScreenState();
}

class _ProjectNetworkScreenState extends State<ProjectNetworkScreen> {
  final Graph graph = Graph()..isTree = false;
  late Algorithm algorithm;
  Map<String, Node> nodes = {};
  final _projectService = ProjectService();
  bool _isHelpExpanded = true;
  bool _isRefreshing = false;
  Size? _size;

  @override
  void initState() {
    super.initState();
    _initializeAlgorithm();
  }

  void _initializeAlgorithm() {
    if (_size == null) {
      _size = const Size(1000, 1000);
    }
    algorithm = FruchtermanReingoldAlgorithm(
      iterations: 100,  // Reduced iterations for more stability
    )..setDimensions(_size!.width, _size!.height);
  }

  Future<void> _refreshGraph() async {
    setState(() {
      _isRefreshing = true;
    });

    // Single gentle refresh with minimal movement
    setState(() {
      algorithm = FruchtermanReingoldAlgorithm(
        iterations: 50,
      )..setDimensions(_size!.width, _size!.height);
    });
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _initializeAlgorithm();
      _isRefreshing = false;
    });
  }

  void _buildGraph(List<Project> projects) {
    // Clear existing graph
    graph.nodes.clear();
    nodes.clear();

    // Calculate center position
    final centerX = _size!.width / 2;
    final centerY = _size!.height / 2;
    final radius = math.min(_size!.width, _size!.height) * 0.3;
    
    // Create nodes in a circular layout
    for (var i = 0; i < projects.length; i++) {
      final project = projects[i];
      final angle = (2 * math.pi * i) / projects.length;
      
      // Calculate position on the circle
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      
      final node = Node.Id(project.id)
        ..x = x
        ..y = y;
      nodes[project.id] = node;
      graph.addNode(node);
    }
  }

  void _openProject(BuildContext context, Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen size
    _size = MediaQuery.of(context).size;

    return StreamBuilder<List<Project>>(
      stream: _projectService.getPublicProjects(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final projects = snapshot.data!;
        if (projects.isEmpty) {
          return const Center(
            child: Text('No projects found'),
          );
        }

        _buildGraph(projects);

        return Stack(
          children: [
            InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.01,
              maxScale: 5.0,
              child: GraphView(
                graph: graph,
                algorithm: algorithm,
                paint: Paint()
                  ..color = Colors.black
                  ..strokeWidth = 1.0
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  // Find the project for this node
                  final project = projects.firstWhere(
                    (p) => p.id == node.key?.value,
                    orElse: () => throw Exception('Project not found'),
                  );

                  // Calculate node size based on metrics
                  final baseSize = 50.0; // Base size for all nodes
                  final collaboratorScore = project.collaboratorIds.length * 5.0;
                  final videoScore = project.videoIds.length * 3.0;
                  final likeScore = project.favoritedBy.length * 4.0;
                  
                  // Total size with upper and lower bounds
                  final totalSize = (baseSize + collaboratorScore + videoScore + likeScore)
                      .clamp(50.0, 120.0);

                  return GestureDetector(
                    onTap: () => _openProject(context, project),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: totalSize,
                      height: totalSize,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          center: Alignment.center,
                          radius: 0.8,
                          colors: [
                            Colors.pinkAccent,
                            Colors.deepPurpleAccent,
                            Colors.blueAccent,
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.tealAccent,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withOpacity(0.6),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  project.name.substring(0, 2).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: totalSize / 4,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 4.0,
                                        color: Colors.black54,
                                        offset: Offset(2.0, 2.0),
                                      ),
                                    ],
                                  ),
                                ),
                                if (totalSize >= 80) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: totalSize / 8,
                                        color: Colors.tealAccent,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${project.collaboratorIds.length}',
                                        style: TextStyle(
                                          fontSize: totalSize / 8,
                                          color: Colors.white,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 2.0,
                                              color: Colors.black45,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.favorite,
                                        size: totalSize / 8,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${project.favoritedBy.length}',
                                        style: TextStyle(
                                          fontSize: totalSize / 8,
                                          color: Colors.white,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 2.0,
                                              color: Colors.black45,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Help text overlay
            Positioned(
              bottom: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 280, // Fixed width to ensure consistent appearance
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurpleAccent, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isHelpExpanded = !_isHelpExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Project Network',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: _isRefreshing
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.refresh, color: Colors.white),
                                    ),
                                    tooltip: 'Refresh layout',
                                    onPressed: _isRefreshing ? null : _refreshGraph,
                                  ),
                                  Icon(
                                    _isHelpExpanded ? Icons.expand_less : Icons.expand_more,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isHelpExpanded)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• Larger circles = More activity\n'
                                '• Connected projects share collaborators\n'
                                '• Thicker lines = More shared collaborators\n'
                                '• Pinch to zoom in/out\n'
                                '• Drag to pan around\n'
                                '• Tap a project to view details',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
} 