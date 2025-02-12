import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/psychedelic_icon_widget.dart';
import '../utils/widget_to_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class IconGeneratorScreen extends StatefulWidget {
  const IconGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<IconGeneratorScreen> createState() => _IconGeneratorScreenState();
}

class _IconGeneratorScreenState extends State<IconGeneratorScreen> {
  final GlobalKey _iconKey = GlobalKey();
  final GlobalKey _foregroundKey = GlobalKey();
  bool _isGenerating = false;
  String _status = '';

  Future<void> _generateIcons() async {
    setState(() {
      _isGenerating = true;
      _status = 'Generating icons...';
    });

    try {
      // Ensure the assets/icon directory exists
      final appDir = await getApplicationDocumentsDirectory();
      final iconDir = Directory(path.join(appDir.path, '../../assets/icon'));
      if (!await iconDir.exists()) {
        await iconDir.create(recursive: true);
      }

      // Generate main app icon (1024x1024)
      final iconBytes = await capturePsychedelicIcon(_iconKey, pixelRatio: 1.0);
      final iconFile = File(path.join(iconDir.path, 'app_icon.png'));
      await iconFile.writeAsBytes(iconBytes);

      // Generate foreground icon (108x108)
      final foregroundBytes = await capturePsychedelicIcon(_foregroundKey, pixelRatio: 1.0);
      final foregroundFile = File(path.join(iconDir.path, 'app_icon_foreground.png'));
      await foregroundFile.writeAsBytes(foregroundBytes);

      setState(() {
        _status = 'Icons generated successfully!\n\nNow run:\nflutter pub get\nflutter pub run flutter_launcher_icons';
      });
    } catch (e) {
      setState(() {
        _status = 'Error generating icons: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Icon Generator'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview of the main app icon
            const Text('Main App Icon Preview (1024x1024):'),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: PsychedelicIconWidget(
                repaintKey: _iconKey,
                size: 1024,
              ),
            ),
            const SizedBox(height: 40),
            
            // Preview of the foreground icon
            const Text('Foreground Icon Preview (108x108):'),
            const SizedBox(height: 20),
            SizedBox(
              width: 108,
              height: 108,
              child: PsychedelicIconWidget(
                repaintKey: _foregroundKey,
                size: 108,
              ),
            ),
            const SizedBox(height: 40),
            
            // Generate button and status
            if (_isGenerating)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _generateIcons,
                child: const Text('Generate Icons'),
              ),
            const SizedBox(height: 20),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status.contains('Error') ? Colors.red : Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 