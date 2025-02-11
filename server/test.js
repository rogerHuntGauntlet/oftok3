const Replicate = require('replicate');
require('dotenv').config();

async function test() {
  const replicate = new Replicate({
    auth: process.env.REPLICATE_API_TOKEN,
  });

  try {
    console.log('Starting video generation...');
    const prediction = await replicate.predictions.create({
      version: "luma/ray",
      input: {
        prompt: "A short video of a peaceful waterfall"
      }
    });

    console.log('Waiting for completion...');
    const result = await replicate.predictions.wait(prediction.id);
    console.log('Result:', result);
  } catch (error) {
    console.error('Error:', error);
  }
}

test(); 