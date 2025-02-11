import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import '../models/video.dart';
import 'dart:convert';

class AICaptionService {
  static final AICaptionService _instance = AICaptionService._internal();
  
  factory AICaptionService() {
    return _instance;
  }
  
  AICaptionService._internal() {
    // Initialize OpenAI with API key from .env
    OpenAI.apiKey = dotenv.env['OPENAI_API_KEY']!;
  }

  Future<Map<String, dynamic>> generateAICaption(String prompt) async {
    try {
      final completion = await OpenAI.instance.chat.create(
        model: 'gpt-4',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'You are a creative social media caption writer. Generate a catchy, engaging caption and relevant tags for a video. Format your response as JSON with "caption" and "tags" fields. Tags should be relevant keywords and topics, max 5 tags.',
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                prompt,
              ),
            ],
          ),
        ],
      );

      final message = completion.choices.first.message;
      final content = message.content?.first.text;
      if (content == null || content.trim().isEmpty) {
        throw Exception('No caption generated');
      }

      // Parse the JSON response
      try {
        // Remove any markdown code block markers if present
        final cleanJson = content.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> result = Map<String, dynamic>.from(
          jsonDecode(cleanJson) as Map,
        );
        return {
          'caption': result['caption'] as String? ?? 'No caption generated',
          'tags': (result['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        };
      } catch (e) {
        print('Error parsing AI response: $e');
        // If JSON parsing fails, try to extract caption and return without tags
        return {
          'caption': content,
          'tags': <String>[],
        };
      }
    } catch (error) {
      print("Error generating caption: $error");
      throw Exception('Failed to generate caption: $error');
    }
  }

  // Generate project title and description from voice transcript
  Future<Map<String, dynamic>> generateProjectDetails(String voiceTranscript) async {
    try {
      final response = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                "You are a helpful assistant that generates concise project titles, descriptions, and tags. Format your response as JSON with the following fields:\n"
                "- title: catchy and brief (max 50 chars)\n"
                "- description: informative but concise (max 200 chars)\n"
                "- tags: list of relevant keywords and topics (max 5 tags)",
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                "Generate a title, description, and tags from this transcript: $voiceTranscript",
              ),
            ],
          ),
        ],
      );

      final content = response.choices.first.message.content?.first.text;
      if (content == null || content.trim().isEmpty) {
        throw Exception('No project details generated');
      }

      try {
        // Remove any markdown code block markers if present
        final cleanJson = content.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> result = Map<String, dynamic>.from(
          jsonDecode(cleanJson) as Map,
        );
        return {
          'title': result['title'] as String? ?? 'New Project',
          'description': result['description'] as String? ?? voiceTranscript,
          'tags': (result['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        };
      } catch (e) {
        print('Error parsing AI response: $e');
        return {
          'title': 'New Project',
          'description': voiceTranscript,
          'tags': <String>[],
        };
      }
    } catch (e) {
      print('Error generating project details: $e');
      return {
        'title': 'New Project',
        'description': voiceTranscript,
        'tags': <String>[],
      };
    }
  }

  // Find related videos based on description
  Future<List<Video>> findRelatedVideos({
    required String description,
    required List<Video> availableVideos,
    required int minVideos,
  }) async {
    try {
      if (availableVideos.isEmpty) return [];

      // Create embeddings for the description
      final descriptionEmbedding = await _createEmbedding(description);
      
      // Get embeddings for all video titles and descriptions
      final videosWithScores = await Future.wait(
        availableVideos.map((video) async {
          final videoEmbedding = await _createEmbedding(
            '${video.title} ${video.description ?? ""} ${video.tags.join(" ")}',
          );
          final similarity = _calculateCosineSimilarity(
            descriptionEmbedding,
            videoEmbedding,
          );
          return MapEntry(video, similarity);
        }),
      );

      // Sort by similarity score
      videosWithScores.sort((a, b) => b.value.compareTo(a.value));

      // Return at least minVideos videos, more if they have good similarity scores
      final threshold = 0.5; // Minimum similarity score to include
      final results = videosWithScores
          .where((entry) => entry.value > threshold)
          .map((entry) => entry.key)
          .take(max(minVideos, 5)) // Take at least minVideos, up to 5 if they meet threshold
          .toList();

      // If we don't have enough videos meeting the threshold, just take the top minVideos
      if (results.length < minVideos) {
        return videosWithScores
            .map((entry) => entry.key)
            .take(minVideos)
            .toList();
      }

      return results;
    } catch (e) {
      print('Error finding related videos: $e');
      // Return random selection if AI matching fails
      availableVideos.shuffle();
      return availableVideos.take(minVideos).toList();
    }
  }

  // Create embedding for text using OpenAI
  Future<List<double>> _createEmbedding(String text) async {
    final response = await OpenAI.instance.embedding.create(
      model: "text-embedding-ada-002",
      input: [text],
    );
    return response.data.first.embeddings;
  }

  // Calculate cosine similarity between two embeddings
  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    normA = sqrt(normA);
    normB = sqrt(normB);
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (normA * normB);
  }
} 