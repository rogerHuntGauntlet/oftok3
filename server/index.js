require('dotenv').config();
const express = require('express');
const cors = require('cors');
const Replicate = require('replicate');

const app = express();
const port = process.env.PORT || 3000;

const replicate = new Replicate({
  auth: process.env.REPLICATE_API_TOKEN,
});

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ status: 'ok' });
});

app.post('/render', async (req, res) => {
  try {
    const { prompt } = req.body;
    
    if (!prompt) {
      return res.status(400).json({ error: 'Prompt is required' });
    }

    const output = await replicate.run("luma/ray", { 
      input: { prompt }
    });

    res.json({
      success: true,
      videoUrl: output
    });

  } catch (error) {
    console.error('Video generation error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
}); 