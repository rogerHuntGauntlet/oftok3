const { initializeApp } = require('firebase/app');
const { getFirestore, collection, query, where, getDocs, updateDoc, serverTimestamp } = require('firebase/firestore');
const { getStorage, ref, uploadBytes, getDownloadURL } = require('firebase/storage');
const { Configuration, OpenAIApi } = require('openai');
const dotenv = require('dotenv');
const path = require('path');
const https = require('https');
const { Readable } = require('stream');
const os = require('os');
const fs = require('fs').promises;
const { spawn } = require('child_process');

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
  const tempDir = os.tmpdir();
  const videoPath = path.join(tempDir, `${videoId}.mp4`);
  const thumbnailPath = path.join(tempDir, `${videoId}_thumb.jpg`);
  const gifPath = path.join(tempDir, `${videoId}_preview.gif`);

  try {
    // Download video to temp file
    console.log('Downloading video for thumbnail generation...');
    const videoBuffer = await downloadVideo(videoUrl);
    await fs.writeFile(videoPath, videoBuffer);

    // Generate thumbnail using FFmpeg
    console.log('Generating thumbnail using FFmpeg...');
    await new Promise((resolve, reject) => {
      const ffmpeg = spawn('tools/ffmpeg/ffmpeg-6.1.1-essentials_build/bin/ffmpeg.exe', [
        '-i', videoPath,
        '-vf', 'thumbnail,scale=1280:720',
        '-frames:v', '1',
        thumbnailPath
      ]);

      ffmpeg.stderr.on('data', (data) => {
        console.log(`FFmpeg: ${data}`);
      });

      ffmpeg.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`FFmpeg process exited with code ${code}`));
        }
      });
    });

    // Generate preview GIF using FFmpeg
    console.log('Generating preview GIF...');
    await new Promise((resolve, reject) => {
      const ffmpeg = spawn('tools/ffmpeg/ffmpeg-6.1.1-essentials_build/bin/ffmpeg.exe', [
        '-i', videoPath,
        '-vf', 'scale=480:-1:flags=lanczos,fps=15', // 480p width, 15fps
        '-t', '3', // 3 second preview
        '-y', gifPath
      ]);

      ffmpeg.stderr.on('data', (data) => {
        console.log(`FFmpeg GIF: ${data}`);
      });

      ffmpeg.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`FFmpeg GIF process exited with code ${code}`));
        }
      });
    });

    // Upload thumbnail to Firebase Storage
    console.log('Reading thumbnail file...');
    const thumbnailBuffer = await fs.readFile(thumbnailPath);
    
    console.log('Uploading thumbnail to Firebase Storage...');
    const thumbnailRef = ref(storage, `thumbnails/${videoId}.jpg`);
    await uploadBytes(thumbnailRef, thumbnailBuffer, {
      contentType: 'image/jpeg'
    });
    
    // Upload GIF to Firebase Storage
    console.log('Reading GIF file...');
    const gifBuffer = await fs.readFile(gifPath);
    
    console.log('Uploading GIF to Firebase Storage...');
    const gifRef = ref(storage, `previews/${videoId}.gif`);
    await uploadBytes(gifRef, gifBuffer, {
      contentType: 'image/gif'
    });
    
    // Get the public URLs
    const thumbnailUrl = await getDownloadURL(thumbnailRef);
    const previewUrl = await getDownloadURL(gifRef);

    // Cleanup temp files
    await fs.unlink(videoPath);
    await fs.unlink(thumbnailPath);
    await fs.unlink(gifPath);

    return { thumbnailUrl, previewUrl };
  } catch (error) {
    console.error('Error generating thumbnail/preview:', error);
    // Cleanup temp files in case of error
    try {
      await fs.unlink(videoPath);
      await fs.unlink(thumbnailPath);
      await fs.unlink(gifPath);
    } catch {}
    throw error;
  }
}

async function convertToHLS(videoPath, videoId) {
  const tempDir = os.tmpdir();
  const hlsDir = path.join(tempDir, `hls_${videoId}`);
  
  try {
    // Create HLS directory
    await fs.mkdir(hlsDir, { recursive: true });
    
    // Convert video to HLS using FFmpeg
    console.log('Converting video to HLS format...');
    await new Promise((resolve, reject) => {
      const ffmpeg = spawn('tools/ffmpeg/ffmpeg-6.1.1-essentials_build/bin/ffmpeg.exe', [
        '-i', videoPath,
        '-profile:v', 'baseline',
        '-level', '3.0',
        '-start_number', '0',
        '-hls_time', '10',
        '-hls_list_size', '0',
        '-f', 'hls',
        path.join(hlsDir, 'playlist.m3u8')
      ]);

      ffmpeg.stderr.on('data', (data) => {
        console.log(`FFmpeg HLS: ${data}`);
      });

      ffmpeg.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`FFmpeg HLS process exited with code ${code}`));
        }
      });
    });

    // Upload HLS files to Firebase Storage
    console.log('Uploading HLS files to Firebase Storage...');
    const files = await fs.readdir(hlsDir);
    
    for (const file of files) {
      const filePath = path.join(hlsDir, file);
      const fileBuffer = await fs.readFile(filePath);
      const contentType = file.endsWith('.m3u8') ? 'application/x-mpegURL' : 'video/MP2T';
      
      const hlsRef = ref(storage, `videos/${videoId}/hls/${file}`);
      await uploadBytes(hlsRef, fileBuffer, {
        contentType: contentType
      });
    }

    // Get the playlist URL
    const playlistRef = ref(storage, `videos/${videoId}/hls/playlist.m3u8`);
    const hlsUrl = await getDownloadURL(playlistRef);

    // Cleanup HLS directory
    for (const file of files) {
      await fs.unlink(path.join(hlsDir, file));
    }
    await fs.rmdir(hlsDir);

    return hlsUrl;
  } catch (error) {
    console.error('Error converting to HLS:', error);
    // Cleanup on error
    try {
      const files = await fs.readdir(hlsDir);
      for (const file of files) {
        await fs.unlink(path.join(hlsDir, file));
      }
      await fs.rmdir(hlsDir);
    } catch {}
    throw error;
  }
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
          let tempVideoPath = null;

          if (videoUrl) {
            if (videoUrl.includes('replicate.delivery') || 
                videoUrl.includes('replicate.com/api') || 
                videoUrl.includes('replicate-api')) {
              console.log('Found external video URL, converting to Firebase URL...');
              videoUrl = await handleReplicateVideo(video.url, doc.id);
              needsMetadataUpdate = true;
            }
          }

          const updates = {};

          // Download video if we need to process it
          if (!video.hlsUrl || true) { // Force download for all videos
            console.log('Downloading video for processing...');
            const videoBuffer = await downloadVideo(videoUrl);
            tempVideoPath = path.join(os.tmpdir(), `${doc.id}.mp4`);
            await fs.writeFile(tempVideoPath, videoBuffer);
          }

          // Generate HLS if needed
          if (!video.hlsUrl) {
            console.log('Generating HLS stream...');
            try {
              const hlsUrl = await convertToHLS(tempVideoPath, doc.id);
              updates.hlsUrl = hlsUrl;
              console.log('HLS URL:', hlsUrl);
            } catch (hlsError) {
              console.error('Error generating HLS:', hlsError);
            }
          }

          // Generate thumbnail for all videos
          console.log('Generating thumbnail...');
          try {
            const { thumbnailUrl, previewUrl } = await generateThumbnail(videoUrl, doc.id);
            updates.thumbnailUrl = thumbnailUrl;
            updates.previewUrl = previewUrl;
            console.log('Thumbnail URL:', thumbnailUrl);
            console.log('Preview URL:', previewUrl);
          } catch (thumbError) {
            console.error('Error generating thumbnail:', thumbError);
          }

          // Generate AI content if needed
          if (video.isAiGenerated || !video.description || !video.tags || needsMetadataUpdate) {
            console.log('Generating AI content...');
            const aiContent = await generateAIContent(video.title || 'Untitled Video', video.isAiGenerated);
            if (aiContent) {
              if (video.isAiGenerated) updates.title = aiContent.title;
              updates.description = aiContent.description;
              updates.tags = aiContent.tags;
            }
          }

          // Update video URL if changed
          if (videoUrl !== video.url) {
            updates.url = videoUrl;
          }

          // Update the document if we have any changes
          if (Object.keys(updates).length > 0) {
            updates.updatedAt = serverTimestamp();
            await updateDoc(doc.ref, updates);
            console.log(`✓ Updated video metadata:`, updates);
          } else {
            console.log('No updates needed for this video.');
          }

          // Cleanup temp video file if it exists
          if (tempVideoPath) {
            try {
              await fs.unlink(tempVideoPath);
            } catch {}
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