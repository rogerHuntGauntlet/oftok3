const { initializeApp } = require('firebase/app');
const { getFirestore, collection, query, where, getDocs, updateDoc, serverTimestamp } = require('firebase/firestore');
const { getStorage, ref, uploadBytes, getDownloadURL } = require('firebase/storage');
const { Configuration, OpenAIApi } = require('openai');
const dotenv = require('dotenv');
const path = require('path');
const https = require('https');
const { Readable } = require('stream');

// Load environment variables from the root .env file
dotenv.config({ path: path.join(__dirname, '../.env') });

// Initialize Firebase
const firebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN,
  projectId: process.env.FIREBASE_PROJECT_ID,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.FIREBASE_APP_ID,
  measurementId: process.env.FIREBASE_MEASUREMENT_ID
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const storage = getStorage(app);

// Initialize OpenAI
const configuration = new Configuration({
  apiKey: process.env.OPENAI_API_KEY,
});
const openai = new OpenAIApi(configuration);

async function downloadVideo(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download video: ${response.statusCode}`));
        return;
      }

      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => resolve(Buffer.concat(chunks)));
      response.on('error', reject);
    }).on('error', reject);
  });
}

async function uploadToFirebase(buffer, videoId) {
  const videoRef = ref(storage, `videos/${videoId}.mp4`);
  await uploadBytes(videoRef, buffer, {
    contentType: 'video/mp4'
  });
  return await getDownloadURL(videoRef);
}

async function handleReplicateVideo(videoUrl, videoId) {
  // Check for both replicate.delivery and video generation service URLs
  if (!videoUrl.includes('replicate.delivery') && !videoUrl.includes('replicate.com/api') && !videoUrl.includes('replicate-api')) {
    return videoUrl;
  }

  console.log(`Downloading video from external service: ${videoUrl}`);
  const videoBuffer = await downloadVideo(videoUrl);
  
  console.log('Uploading to Firebase Storage...');
  const firebaseUrl = await uploadToFirebase(videoBuffer, videoId);
  
  console.log(`Video uploaded to Firebase: ${firebaseUrl}`);
  return firebaseUrl;
}

async function generateAIContent(title, isAIGenerated = false) {
  try {
    // Different prompts based on whether it's an AI-generated video
    const prompt = isAIGenerated 
      ? `This is an AI-generated video. Generate an engaging title, description, and 3-5 relevant tags that would work well on social media. The current title/prompt was: "${title}". Return as JSON with title, description, and tags.`
      : `Generate a catchy description and 3-5 relevant tags for this video title: "${title}"`;

    const response = await openai.createChatCompletion({
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

    const content = response.data.choices[0].message.content;
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

async function generateThumbnail(videoUrl, videoId) {
  // TODO: Implement actual thumbnail generation
  // For now, use a more visually interesting placeholder
  const width = 1280;
  const height = 720;
  const category = 'nature'; // Can be: nature, city, technology, abstract
  return `https://source.unsplash.com/random/${width}x${height}/?${category}`;
}

async function updateVideoMetadata() {
  try {
    // Get all videos
    const videosRef = collection(db, 'videos');
    const videosSnapshot = await getDocs(videosRef);

    console.log(`Found ${videosSnapshot.size} videos to update`);

    // Process videos in batches to avoid rate limits
    const batchSize = 5;
    const videos = videosSnapshot.docs;

    for (let i = 0; i < videos.length; i += batchSize) {
      const batch = videos.slice(i, i + batchSize);
      console.log(`\nProcessing batch ${Math.floor(i/batchSize) + 1} of ${Math.ceil(videos.length/batchSize)}`);

      // Process batch concurrently
      await Promise.all(batch.map(async (doc) => {
        const video = doc.data();
        console.log(`\nProcessing video: ${video.title || 'Untitled'} (${doc.id})`);

        try {
          // Handle external video URL if needed
          let videoUrl = video.url;
          let needsMetadataUpdate = false;

          if (videoUrl) {
            if (videoUrl.includes('replicate.delivery') || 
                videoUrl.includes('replicate.com/api') || 
                videoUrl.includes('replicate-api')) {
              console.log('Found external video URL, converting to Firebase URL...');
              videoUrl = await handleReplicateVideo(video.url, doc.id);
              needsMetadataUpdate = true;
            }
          }

          // Always generate AI content for AI-generated videos or if metadata is missing
          if (video.isAiGenerated || !video.description || !video.tags || needsMetadataUpdate) {
            console.log('Generating AI content...');
            const aiContent = await generateAIContent(video.title || 'Untitled Video', video.isAiGenerated);
            if (!aiContent) return;

            // Generate new thumbnail
            console.log('Generating thumbnail...');
            const thumbnailUrl = await generateThumbnail(videoUrl, doc.id);

            // Update the video document with all new metadata
            await updateDoc(doc.ref, {
              title: video.isAiGenerated ? aiContent.title : video.title, // Only update title for AI-generated videos
              description: aiContent.description,
              tags: aiContent.tags,
              thumbnailUrl: thumbnailUrl,
              ...(videoUrl !== video.url ? { url: videoUrl } : {}),
              updatedAt: serverTimestamp()
            });

            console.log(`✓ Updated metadata for video: ${doc.id}`);
            if (video.isAiGenerated) {
              console.log(`  New title: ${aiContent.title}`);
            }
            console.log(`  Description: ${aiContent.description}`);
            console.log(`  Tags: ${aiContent.tags.join(', ')}`);
          }
        } catch (error) {
          console.error(`× Error processing video ${doc.id}:`, error);
        }
      }));

      // Add a delay between batches to avoid rate limits
      if (i + batchSize < videos.length) {
        console.log('\nWaiting 2 seconds before next batch...');
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }

    console.log('\nMetadata update completed!');
  } catch (error) {
    console.error('Fatal error:', error);
  }
}

module.exports = {
  handleReplicateVideo,
  generateAIContent,
  generateThumbnail,
  updateVideoMetadata
};

// Only run the update if this file is run directly
if (require.main === module) {
  updateVideoMetadata().then(() => process.exit());
} 