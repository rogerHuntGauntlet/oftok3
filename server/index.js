require('dotenv').config();
const express = require('express');
const cors = require('cors');
const Replicate = require('replicate');

const app = express();
const port = process.env.PORT || 3000;

// Initialize Replicate client
const replicate = new Replicate({
  auth: process.env.REPLICATE_API_TOKEN,
});

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ status: 'ok' });
});

// Video generation endpoint
app.post('/generate-video', async (req, res) => {
  try {
    const { prompt } = req.body;

    if (!prompt) {
      return res.status(400).json({ error: 'Prompt is required' });
    }

    // Start the prediction
    const prediction = await replicate.predictions.create({
      version: "luma/ray",
      input: {
        prompt: prompt
      },
    });

    // Wait for the prediction to complete
    const result = await replicate.predictions.wait(prediction.id);

    if (result.error) {
      throw new Error(`Video generation failed: ${result.error}`);
    }

    if (!result.output) {
      throw new Error('No output URL was provided');
    }

    // Return the result
    res.json({
      success: true,
      videoUrl: result.output,
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