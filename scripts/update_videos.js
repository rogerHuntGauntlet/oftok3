const admin = require('firebase-admin');
const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');
const path = require('path');
const os = require('os');
const fetch = require('node-fetch');

// Set FFmpeg path
const ffmpegPath = path.join(__dirname, '../tools/ffmpeg/ffmpeg-6.1.1-essentials_build/bin/ffmpeg.exe');
ffmpeg.setFfmpegPath(ffmpegPath);

// Initialize Firebase Admin
const serviceAccount = require('../firebase-service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET
});

const db = admin.firestore();
const storage = admin.storage();

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
      .on('end', () => resolve(thumbnailPath))
      .on('error', reject);
  });
}

async function convertToHLS(videoPath, videoId) {
  const hlsDir = path.join(os.tmpdir(), `hls_${videoId}`);
  fs.mkdirSync(hlsDir, { recursive: true });
  
  return new Promise((resolve, reject) => {
    ffmpeg(videoPath)
      .addOption('-profile:v', 'baseline')
      .addOption('-level', '3.0')
      .addOption('-start_number', '0')
      .addOption('-hls_time', '10')
      .addOption('-hls_list_size', '0')
      .addOption('-f', 'hls')
      .output(path.join(hlsDir, 'playlist.m3u8'))
      .on('end', () => resolve(hlsDir))
      .on('error', reject);
  });
}

async function processVideo(video) {
  try {
    console.log(`Processing video: ${video.id}`);
    
    // Download video to temp file
    const videoPath = path.join(os.tmpdir(), `${video.id}.mp4`);
    const videoFile = await fetch(video.url);
    await fs.promises.writeFile(videoPath, await videoFile.buffer());
    
    const updates = {};
    
    // Generate thumbnail if needed
    if (!video.thumbnailUrl) {
      console.log('Generating thumbnail...');
      const thumbnailPath = await generateThumbnail(videoPath, video.id);
      const thumbnailFile = storage.bucket().file(`thumbnails/${video.id}.jpg`);
      await thumbnailFile.save(await fs.promises.readFile(thumbnailPath), {
        metadata: { contentType: 'image/jpeg' }
      });
      updates.thumbnailUrl = await thumbnailFile.getSignedUrl({ action: 'read', expires: '03-01-2500' });
    }
    
    // Convert to HLS if needed
    if (!video.hlsUrl) {
      console.log('Converting to HLS...');
      const hlsDir = await convertToHLS(videoPath, video.id);
      
      // Upload HLS files
      const files = await fs.promises.readdir(hlsDir);
      for (const file of files) {
        const filePath = path.join(hlsDir, file);
        const contentType = file.endsWith('.m3u8') ? 'application/x-mpegURL' : 'video/MP2T';
        const destination = `videos/${video.id}/hls/${file}`;
        
        await storage.bucket().upload(filePath, {
          destination,
          metadata: { contentType }
        });
      }
      
      // Get HLS URL
      const hlsFile = storage.bucket().file(`videos/${video.id}/hls/playlist.m3u8`);
      updates.hlsUrl = await hlsFile.getSignedUrl({ action: 'read', expires: '03-01-2500' });
    }
    
    // Update video document if needed
    if (Object.keys(updates).length > 0) {
      await db.collection('videos').doc(video.id).update(updates);
      console.log('Updated video with:', updates);
    }
    
    // Cleanup
    await fs.promises.unlink(videoPath);
    
    console.log(`Completed processing video: ${video.id}`);
  } catch (error) {
    console.error(`Error processing video ${video.id}:`, error);
  }
}

async function batchUpdateVideos() {
  try {
    const snapshot = await db.collection('videos').get();
    const total = snapshot.size;
    console.log(`Found ${total} videos to process`);
    
    // Process videos in batches of 3
    const batchSize = 3;
    for (let i = 0; i < snapshot.docs.length; i += batchSize) {
      const batch = snapshot.docs.slice(i, i + batchSize);
      await Promise.all(batch.map(doc => processVideo({ id: doc.id, ...doc.data() })));
      console.log(`Processed ${Math.min(i + batchSize, total)}/${total} videos`);
      
      // Add delay between batches
      if (i + batchSize < total) {
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    }
    
    console.log('Batch update completed successfully');
  } catch (error) {
    console.error('Error in batch update:', error);
  }
}

// Run the batch update
batchUpdateVideos().then(() => process.exit()); 