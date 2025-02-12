const { initializeApp } = require('firebase/app');
const { getFirestore, doc, getDoc, updateDoc, serverTimestamp } = require('firebase/firestore');
const { getStorage, ref, uploadBytes, getDownloadURL } = require('firebase/storage');
const dotenv = require('dotenv');
const path = require('path');
const https = require('https');
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

async function generateThumbnail(videoPath, videoId) {
  const thumbnailPath = path.join(os.tmpdir(), `${videoId}_thumb.jpg`);

  try {
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

    // Upload thumbnail to Firebase Storage
    console.log('Reading thumbnail file...');
    const thumbnailBuffer = await fs.readFile(thumbnailPath);
    
    console.log('Uploading thumbnail to Firebase Storage...');
    const thumbnailRef = ref(storage, `thumbnails/${videoId}.jpg`);
    await uploadBytes(thumbnailRef, thumbnailBuffer, {
      contentType: 'image/jpeg'
    });
    
    // Get the public URL
    const thumbnailUrl = await getDownloadURL(thumbnailRef);

    // Cleanup temp file
    await fs.unlink(thumbnailPath);

    return thumbnailUrl;
  } catch (error) {
    console.error('Error generating thumbnail:', error);
    // Cleanup temp file in case of error
    try {
      await fs.unlink(thumbnailPath);
    } catch {}
    throw error;
  }
}

async function convertToHLS(videoPath, videoId) {
  const hlsDir = path.join(os.tmpdir(), `hls_${videoId}`);
  
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

async function retryVideo(videoId) {
  try {
    console.log(`Processing video: ${videoId}`);
    
    // Get the video document
    const videoRef = doc(db, 'videos', videoId);
    const videoDoc = await getDoc(videoRef);
    
    if (!videoDoc.exists()) {
      console.error('Video not found in database');
      return;
    }

    const video = videoDoc.data();
    console.log('Video data:', video);

    const updates = {};
    let tempVideoPath = null;

    try {
      // Download video
      console.log('Downloading video...');
      const videoBuffer = await downloadVideo(video.url);
      tempVideoPath = path.join(os.tmpdir(), `${videoId}.mp4`);
      await fs.writeFile(tempVideoPath, videoBuffer);

      // Upload to Firebase Storage
      console.log('Uploading to Firebase Storage...');
      const videoRef = ref(storage, `videos/${videoId}.mp4`);
      await uploadBytes(videoRef, videoBuffer, {
        contentType: 'video/mp4'
      });
      const videoUrl = await getDownloadURL(videoRef);
      updates.url = videoUrl;

      // Generate HLS if needed
      if (!video.hlsUrl) {
        console.log('Generating HLS stream...');
        const hlsUrl = await convertToHLS(tempVideoPath, videoId);
        updates.hlsUrl = hlsUrl;
        console.log('HLS URL:', hlsUrl);
      }

      // Generate thumbnail if needed
      if (!video.thumbnailUrl) {
        console.log('Generating thumbnail...');
        const thumbnailUrl = await generateThumbnail(tempVideoPath, videoId);
        updates.thumbnailUrl = thumbnailUrl;
        console.log('Thumbnail URL:', thumbnailUrl);
      }

      // Update the document if we have any changes
      if (Object.keys(updates).length > 0) {
        updates.updatedAt = serverTimestamp();
        await updateDoc(videoRef, updates);
        console.log('✓ Updated video metadata:', updates);
      } else {
        console.log('No updates needed for this video.');
      }
    } finally {
      // Cleanup temp video file if it exists
      if (tempVideoPath) {
        try {
          await fs.unlink(tempVideoPath);
        } catch {}
      }
    }
  } catch (error) {
    console.error('Error processing video:', error);
  }
}

// Run the retry if this file is run directly
if (require.main === module) {
  const videoId = 'f52b65e6-d64c-4041-97f7-9b72ddc3b9a9'; // The failed Replicate video
  retryVideo(videoId).then(() => process.exit());
} 