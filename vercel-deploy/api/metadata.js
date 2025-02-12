import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import OpenAI from 'openai';
import { v4 as uuidv4 } from 'uuid';

// Initialize Firebase Admin
try {
  // Parse the service account JSON from environment variable
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  
  initializeApp({
    credential: cert(serviceAccount),
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET
  });
} catch (error) {
  console.error('Failed to initialize Firebase Admin:', error);
  throw new Error('Firebase initialization failed');
}

const db = getFirestore();
const storage = getStorage();

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

async function generateAIContent(title, isAIGenerated = false) {
  try {
    const prompt = isAIGenerated 
      ? `This is an AI-generated video. Generate an engaging title, description, and 3-5 relevant tags that would work well on social media. The current title/prompt was: "${title}". Return as JSON with title, description, and tags.`
      : `Generate a catchy description and 3-5 relevant tags for this video title: "${title}"`;

    const response = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [{
        role: "system",
        content: "You are a helpful assistant that generates engaging social media video metadata. For AI-generated videos, create viral-worthy titles. Always respond with valid JSON in this format: {\"title\": \"engaging title here\", \"description\": \"engaging description here\", \"tags\": [\"tag1\", \"tag2\", \"tag3\"]}"
      }, {
        role: "user",
        content: prompt
      }],
      temperature: 0.7,
      max_tokens: 200
    });

    const content = response.choices[0].message.content;
    console.log('AI Response:', content);
    
    try {
      const result = JSON.parse(content);
      if (!result.description || !Array.isArray(result.tags)) {
        throw new Error('Invalid response format');
      }
      return result;
    } catch (parseError) {
      console.error('Error parsing AI response:', parseError);
      return null;
    }
  } catch (error) {
    console.error('Error generating AI content:', error?.response?.data || error);
    return null;
  }
}

async function generateThumbnail(videoId) {
  // Generate a random nature-themed placeholder thumbnail
  const width = 1280;
  const height = 720;
  const category = 'nature';
  return `https://source.unsplash.com/random/${width}x${height}/?${category}`;
}

export default async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
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
    if (token !== process.env.API_SECRET_KEY) {
      return res.status(401).json({
        success: false,
        error: 'Invalid authentication token'
      });
    }

    const { videoId, title, isAiGenerated = false } = req.body;

    if (!videoId || !title) {
      return res.status(400).json({
        success: false,
        error: 'Video ID and title are required'
      });
    }

    // Get the video document
    const videoDoc = await getFirestore().doc(`videos/${videoId}`).get();
    if (!videoDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'Video not found'
      });
    }

    console.log('Generating AI content...');
    const aiContent = await generateAIContent(title, isAiGenerated);
    
    console.log('Generating thumbnail...');
    const thumbnailUrl = await generateThumbnail(videoId);

    // Update the video document
    const updateData = {
      title: isAiGenerated ? aiContent?.title || title : title,
      description: aiContent?.description,
      tags: aiContent?.tags || [],
      thumbnailUrl: thumbnailUrl,
      updatedAt: getFirestore().FieldValue.serverTimestamp(),
      isAiGenerated: isAiGenerated
    };

    await getFirestore().doc(`videos/${videoId}`).update(updateData);

    return res.json({
      success: true,
      data: {
        ...updateData,
        id: videoId
      }
    });

  } catch (error) {
    console.error('Metadata update error:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
}; 