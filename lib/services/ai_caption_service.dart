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
  Future<Map<String, dynamic>> generateProjectDetails(String prompt, {bool isAiGenerated = false}) async {
    try {
      final systemPrompt = isAiGenerated
        ? "You are a creative video title and description generator specializing in AI-generated content. Your goal is to create viral-worthy, attention-grabbing titles and descriptions that highlight the unique and creative aspects of AI-generated videos. Format your response as JSON with:\n"
          "- title: create a catchy, compelling title that emphasizes the video's unique AI-generated nature (max 50 chars)\n"
          "- description: write an engaging description that explains the AI-generated content and hooks viewers (max 200 chars)\n"
          "- tags: list of relevant trending hashtags including AI-related tags (max 5 tags)\n\n"
          "Make the title and description creative, intriguing, and optimized for social media engagement. Focus on the innovative and artistic aspects of AI generation."
        : "You are a creative video title and description generator. Your goal is to create engaging, attention-grabbing titles and descriptions for social media videos. Format your response as JSON with:\n"
          "- title: create a catchy, compelling title that makes viewers want to watch (max 50 chars)\n"
          "- description: write an engaging description that expands on the title and hooks viewers (max 200 chars)\n"
          "- tags: list of relevant trending hashtags and topics (max 5 tags)\n\n"
          "Make the title and description creative, intriguing, and optimized for social media engagement. Avoid generic descriptions.";

      final userPrompt = isAiGenerated
        ? "Generate a viral-worthy title, description, and tags for this AI-generated video. The generation prompt was: $prompt"
        : "Generate a title, description, and tags for this video prompt: $prompt";

      final response = await OpenAI.instance.chat.create(
        model: "gpt-4",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(userPrompt),
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
          'title': result['title'] as String? ?? 'New Video',
          'description': result['description'] as String? ?? prompt,
          'tags': (result['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        };
      } catch (e) {
        print('Error parsing AI response: $e');
        return {
          'title': 'New Video',
          'description': prompt,
          'tags': <String>[],
        };
      }
    } catch (e) {
      print('Error generating project details: $e');
      return {
        'title': 'New Video',
        'description': prompt,
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