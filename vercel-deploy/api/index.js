import Replicate from 'replicate';

// List of moderation keywords
const MODERATION_KEYWORDS = [
  'nsfw',
  'nude',
  'explicit',
  'porn',
  'sex',
  'adult',
  'xxx',
  'violence',
  'gore',
  'blood',
  'death',
  'kill',
  'murder',
  'terrorist',
  'hate',
  'racist',
  'discrimination',
  'offensive',
];

// Function to check if content should be moderated
function shouldModerateContent(prompt) {
  const lowerPrompt = prompt.toLowerCase();
  return MODERATION_KEYWORDS.some(keyword => lowerPrompt.includes(keyword));
}

export default async (req, res) => {
  // Debug logging
  console.log('Request received:', {
    method: req.method,
    url: req.url,
    headers: req.headers,
    body: req.body,
    env: {
      hasReplicateToken: !!process.env.REPLICATE_API_TOKEN,
      tokenLength: process.env.REPLICATE_API_TOKEN ? process.env.REPLICATE_API_TOKEN.length : 0
    }
  });

  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    // Verify authentication
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('Missing or invalid Authorization header:', authHeader);
      return res.status(401).json({
        success: false,
        error: 'Authentication required - Bearer token missing'
      });
    }

    const token = authHeader.split(' ')[1];
    if (!process.env.API_SECRET_KEY) {
      console.error('API_SECRET_KEY not set in environment');
      return res.status(500).json({
        success: false,
        error: 'Server configuration error - API secret key not set'
      });
    }

    if (token !== process.env.API_SECRET_KEY) {
      console.log('Token mismatch:', {
        providedToken: token.substring(0, 10) + '...',
        expectedToken: process.env.API_SECRET_KEY.substring(0, 10) + '...',
        match: token === process.env.API_SECRET_KEY
      });
      return res.status(401).json({
        success: false,
        error: 'Invalid authentication token'
      });
    }

    // Initialize Replicate with its API token
    if (!process.env.REPLICATE_API_TOKEN) {
      console.error('REPLICATE_API_TOKEN not set in environment');
      return res.status(500).json({
        success: false,
        error: 'Server configuration error - Replicate API token not set'
      });
    }

    // Check if this is a status check request
    if (req.method === 'GET') {
      const { id } = req.query;
      if (!id) {
        return res.status(400).json({ error: 'Prediction ID is required' });
      }

      console.log('Checking prediction status:', id);
      const replicate = new Replicate({
        auth: process.env.REPLICATE_API_TOKEN,
      });

      const prediction = await replicate.predictions.get(id);
      console.log('Prediction status:', prediction.status);
      
      return res.json({
        success: true,
        status: prediction.status,
        output: prediction.output,
        error: prediction.error
      });
    }

    // Handle initial video generation request
    if (req.method === 'POST') {
      const { prompt } = req.body;
      
      if (!prompt) {
        return res.status(400).json({ error: 'Prompt is required' });
      }

      // Check content moderation
      if (shouldModerateContent(prompt)) {
        console.log('Content moderation triggered for prompt:', prompt);
        return res.status(400).json({
          success: false,
          error: 'Your prompt contains content that violates our community guidelines.',
          isModeratedContent: true
        });
      }

      console.log('Starting video generation with prompt:', prompt);
      const replicate = new Replicate({
        auth: process.env.REPLICATE_API_TOKEN,
      });

      // Start the prediction without waiting
      const prediction = await replicate.predictions.create({
        version: "luma/ray",
        input: { 
          prompt,
          width: 1080,  // Standard mobile video width
          height: 1920, // Standard mobile video height (9:16 aspect ratio)
          num_frames: 150, // Increased frames for smoother video
          fps: 30 // Standard mobile video framerate
        }
      });

      console.log('Prediction created:', prediction.id);
      return res.json({
        success: true,
        id: prediction.id,
        status: prediction.status
      });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Video generation error:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
}; 