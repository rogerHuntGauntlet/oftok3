const Replicate = require('replicate');

module.exports = async (req, res) => {
  // Enable CORS with Authorization header
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version');

  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    // Verify authentication
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const token = authHeader.split(' ')[1];
    if (token !== process.env.REPLICATE_API_TOKEN) {
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

      const replicate = new Replicate({
        auth: process.env.REPLICATE_API_TOKEN,
      });

      const prediction = await replicate.predictions.get(id);
      
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

      const replicate = new Replicate({
        auth: process.env.REPLICATE_API_TOKEN,
      });

      // Start the prediction without waiting
      const prediction = await replicate.predictions.create({
        version: "luma/ray",
        input: { prompt }
      });

      return res.json({
        success: true,
        id: prediction.id,
        status: prediction.status
      });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Video generation error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
}; 