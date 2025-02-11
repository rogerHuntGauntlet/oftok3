import Replicate from 'replicate';

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
    if (!process.env.REPLICATE_API_TOKEN) {
      console.error('REPLICATE_API_TOKEN not set in environment');
      return res.status(500).json({
        success: false,
        error: 'Server configuration error - API token not set'
      });
    }

    if (token !== process.env.REPLICATE_API_TOKEN) {
      console.log('Token mismatch:', {
        providedToken: token,
        expectedToken: process.env.REPLICATE_API_TOKEN,
        match: token === process.env.REPLICATE_API_TOKEN
      });
      return res.status(401).json({
        success: false,
        error: 'Invalid authentication token'
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

      console.log('Starting video generation with prompt:', prompt);
      const replicate = new Replicate({
        auth: process.env.REPLICATE_API_TOKEN,
      });

      // Start the prediction without waiting
      const prediction = await replicate.predictions.create({
        version: "luma/ray",
        input: { prompt }
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