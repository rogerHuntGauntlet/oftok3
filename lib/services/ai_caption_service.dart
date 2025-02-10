import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AICaptionService {
  static final AICaptionService _instance = AICaptionService._internal();
  
  factory AICaptionService() {
    return _instance;
  }
  
  AICaptionService._internal() {
    // Initialize OpenAI with API key from .env
    OpenAI.apiKey = dotenv.env['OPENAI_API_KEY']!;
  }

  Future<String> generateAICaption(String prompt) async {
    try {
      final completion = await OpenAI.instance.chat.create(
        model: 'gpt-4',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'You are a creative social media caption writer. Generate a catchy, engaging caption for a video.',
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
      final content = message.content;
      
      // Handle null or empty content
      if (content == null || 
          content.isEmpty || 
          content.first.text == null || 
          content.first.text?.trim().isEmpty == true) {
        throw Exception('No caption generated');
      }

      final text = content.first.text;
      if (text == null) {
        throw Exception('Generated caption is null');
      }

      return text;
    } catch (error) {
      print("Error generating caption: $error");
      throw Exception('Failed to generate caption: $error');
    }
  }
} 