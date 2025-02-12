import admin from 'firebase-admin';
import OpenAI from 'openai';
import ffmpeg from 'fluent-ffmpeg';
import dotenv from 'dotenv';
import path from 'path';
import https from 'https';
import { Readable } from 'stream';
import fs from 'fs';
import os from 'os';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables from the root .env file
dotenv.config({ path: path.join(__dirname, '../.env') });

// Set FFmpeg path
const ffmpegPath = path.join(__dirname, '../tools/ffmpeg/ffmpeg-6.1.1-essentials_build/bin/ffmpeg.exe');
ffmpeg.setFfmpegPath(ffmpegPath);

// Initialize Firebase Admin
const serviceAccount = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../ohftok-gauntlet-firebase-adminsdk-fbsvc-d26983d27a.json'), 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET
});

const db = admin.firestore();
const storage = admin.storage().bucket();

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

async function uploadToStorage(buffer, path, contentType) {
  const file = storage.file(path);
  await file.save(buffer, {
    contentType,
    metadata: {
      contentType
    }
  });
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: '03-01-2500'
  });
  return url;
}

async function generateThumbnail(videoPath, videoId) {
  const thumbnailPath = path.join(os.tmpdir(), `${videoId}_thumb.jpg`);
  
  return new Promise((resolve, reject) => {
    ffmpeg(videoPath)
      .screenshots({
        timestamps: ['00:00:01'],
        filename: `${videoId}_thumb.jpg`,
        folder: os.tmpdir(),
        size: '1280x720'
      })
      .on('end', async () => {
        try {
          // Upload thumbnail to Firebase Storage
          const thumbnailBuffer = await fs.promises.readFile(thumbnailPath);
          const thumbnailUrl = await uploadToStorage(
            thumbnailBuffer,
            `thumbnails/${videoId}.jpg`,
            'image/jpeg'
          );
          
          // Cleanup
          await fs.promises.unlink(thumbnailPath);
          resolve(thumbnailUrl);
        } catch (error) {
          reject(error);
        }
      })
      .on('error', reject);
  });
}

async function convertToHLS(videoPath, videoId) {
  const hlsDir = path.join(os.tmpdir(), `hls_${videoId}`);
  await fs.promises.mkdir(hlsDir, { recursive: true });
  
  return new Promise((resolve, reject) => {
    ffmpeg(videoPath)
      .addOption('-profile:v', 'baseline')
      .addOption('-level', '3.0')
      .addOption('-start_number', '0')
      .addOption('-hls_time', '10')
      .addOption('-hls_list_size', '0')
      .addOption('-f', 'hls')
      .output(path.join(hlsDir, 'playlist.m3u8'))
      .on('end', async () => {
        try {
          // Upload HLS files to Firebase Storage
          const files = await fs.promises.readdir(hlsDir);
          for (const file of files) {
            const filePath = path.join(hlsDir, file);
            const contentType = file.endsWith('.m3u8') ? 'application/x-mpegURL' : 'video/MP2T';
            const fileBuffer = await fs.promises.readFile(filePath);
            await uploadToStorage(
              fileBuffer,
              `videos/${videoId}/hls/${file}`,
              contentType
            );
          }
          
          // Get master playlist URL
          const [hlsUrl] = await storage
            .file(`videos/${videoId}/hls/playlist.m3u8`)
            .getSignedUrl({
              action: 'read',
              expires: '03-01-2500'
            });
          
          // Cleanup
          await fs.promises.rm(hlsDir, { recursive: true });
          resolve(hlsUrl);
        } catch (error) {
          reject(error);
        }
      })
      .on('error', reject);
  });
}

async function processVideo(videoPath, videoId) {
  try {
    console.log('Generating thumbnail...');
    const thumbnailUrl = await generateThumbnail(videoPath, videoId);
    
    console.log('Converting to HLS...');
    const hlsUrl = await convertToHLS(videoPath, videoId);
    
    return { thumbnailUrl, hlsUrl };
  } catch (error) {
    console.error('Error processing video:', error);
    throw error;
  }
}

async function downloadAndProcessVideo(videoUrl, videoId) {
  const videoPath = path.join(os.tmpdir(), `${videoId}.mp4`);
  
  try {
    console.log('Downloading video...');
    const videoBuffer = await downloadVideo(videoUrl);
    await fs.promises.writeFile(videoPath, videoBuffer);
    
    const results = await processVideo(videoPath, videoId);
    
    // Cleanup
    await fs.promises.unlink(videoPath);
    
    return results;
  } catch (error) {
    // Cleanup on error
    try {
      await fs.promises.unlink(videoPath);
    } catch {}
    throw error;
  }
}

async function updateVideoMetadata() {
  try {
    console.log('Starting video metadata update process...');
    console.log('Service account project ID:', serviceAccount.project_id);
    console.log('Storage bucket:', process.env.FIREBASE_STORAGE_BUCKET);
    
    const videosRef = db.collection('videos');
    console.log('Getting videos from Firestore...');
    
    try {
      const videosSnapshot = await videosRef.get();
      console.log(`Found ${videosSnapshot.size} videos to update`);
      
      if (videosSnapshot.size === 0) {
        console.log('No videos found in the database.');
        return;
      }

      // Log first video for debugging
      const firstDoc = videosSnapshot.docs[0];
      console.log('First video data:', firstDoc.data());

      const batchSize = 3; // Reduced batch size due to intensive processing
      const videos = videosSnapshot.docs;

      for (let i = 0; i < videos.length; i += batchSize) {
        const batch = videos.slice(i, i + batchSize);
        console.log(`\nProcessing batch ${Math.floor(i/batchSize) + 1} of ${Math.ceil(videos.length/batchSize)}`);

        // Process batch sequentially to avoid memory issues
        for (const doc of batch) {
          const video = doc.data();
          console.log(`\nProcessing video: ${video.title || 'Untitled'} (${doc.id})`);
          console.log('Video data:', video);

          try {
            const needsHLS = !video.hlsUrl;
            const needsThumbnail = !video.thumbnailUrl;
            const needsMetadataUpdate = video.isAiGenerated || !video.description || !video.tags;

            console.log('Needs HLS:', needsHLS);
            console.log('Needs thumbnail:', needsThumbnail);
            console.log('Needs metadata update:', needsMetadataUpdate);

            if (needsHLS || needsThumbnail) {
              console.log('Processing video file...');
              console.log('Video URL:', video.url);
              const { thumbnailUrl, hlsUrl } = await downloadAndProcessVideo(video.url, doc.id);

              const updates = {
                ...(needsHLS ? { hlsUrl } : {}),
                ...(needsThumbnail ? { thumbnailUrl } : {}),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
              };

              if (needsMetadataUpdate) {
                console.log('Generating AI content...');
                const aiContent = await generateAIContent(video.title || 'Untitled Video', video.isAiGenerated);
                if (aiContent) {
                  updates.description = aiContent.description;
                  updates.tags = aiContent.tags;
                  if (video.isAiGenerated) {
                    updates.title = aiContent.title;
                  }
                }
              }

              console.log('Updating video with:', updates);
              await doc.ref.update(updates);
              console.log(`✓ Updated video: ${doc.id}`);
            } else {
              console.log('Video already has all required fields. Skipping.');
            }
          } catch (error) {
            console.error(`× Error processing video ${doc.id}:`, error);
          }
        }

        // Add a delay between batches
        if (i + batchSize < videos.length) {
          console.log('\nWaiting 5 seconds before next batch...');
          await new Promise(resolve => setTimeout(resolve, 5000));
        }
      }
    } catch (firestoreError) {
      console.error('Error accessing Firestore:', firestoreError);
      throw firestoreError;
    }
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

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

async function handleReplicateVideo(videoUrl, videoId) {
  if (!videoUrl.includes('replicate.delivery') && !videoUrl.includes('replicate.com/api') && !videoUrl.includes('replicate-api')) {
    return videoUrl;
  }

  console.log(`Downloading video from external service: ${videoUrl}`);
  const videoBuffer = await downloadVideo(videoUrl);
  
  console.log('Uploading to Firebase Storage...');
  const videoRef = storage.file(`videos/${videoId}.mp4`);
  await videoRef.save(videoBuffer, {
    contentType: 'video/mp4'
  });
  const firebaseUrl = await videoRef.getSignedUrl({
    action: 'read',
    expires: '03-01-2500'
  });
  
  console.log(`Video uploaded to Firebase: ${firebaseUrl}`);
  return firebaseUrl;
}

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

// Export all functions
export {
  downloadVideo,
  handleReplicateVideo,
  generateAIContent,
  generateThumbnail,
  convertToHLS,
  processVideo,
  downloadAndProcessVideo,
  updateVideoMetadata
};

// Run the update
console.log('Starting script...');
updateVideoMetadata().then(() => {
  console.log('Script completed successfully');
  process.exit(0);
}).catch(error => {
  console.error('Script failed:', error);
  process.exit(1);
}); 