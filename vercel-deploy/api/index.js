import Replicate from 'replicate';
import { Storage } from '@google-cloud/storage';
import ffmpeg from 'fluent-ffmpeg';
import { v4 as uuidv4 } from 'uuid';
import os from 'os';
import path from 'path';
import fs from 'fs';
import fetch from 'node-fetch';

// List of moderation keywords
const MODERATION_KEYWORDS = [
  'nsfw',
  'nude',
  'explicit',
  'porn',
  'sex',
  'adult',
  'xxx',
  'violence',
  'gore',
  'blood',
  'death',
  'kill',
  'murder',
  'terrorist',
  'hate',
  'racist',
  'discrimination',
  'offensive',
];

// Function to check if content should be moderated
function shouldModerateContent(prompt) {
  const lowerPrompt = prompt.toLowerCase();
  return MODERATION_KEYWORDS.some(keyword => lowerPrompt.includes(keyword));
}

// Function to download video to temp file
async function downloadVideo(url) {
  const response = await fetch(url);
  const buffer = await response.buffer();
  const tempPath = path.join(os.tmpdir(), `${uuidv4()}.mp4`);
  await fs.promises.writeFile(tempPath, buffer);
  return tempPath;
}

// Function to generate thumbnail
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
          // Upload to Firebase Storage
          await bucket.upload(thumbnailPath, {
            destination: `thumbnails/${videoId}.jpg`,
            metadata: { contentType: 'image/jpeg' }
          });
          
          // Get public URL
          const [url] = await bucket
            .file(`thumbnails/${videoId}.jpg`)
            .getSignedUrl({ action: 'read', expires: '03-01-2500' });
          
          // Cleanup
          await fs.promises.unlink(thumbnailPath);
          return resolve(url);
        } catch (error) {
          reject(error);
        }
      })
      .on('error', reject);
  });
}

// Function to generate preview GIF
async function generatePreviewGif(videoPath, videoId) {
  const gifPath = path.join(os.tmpdir(), `${videoId}_preview.gif`);
  
  return new Promise((resolve, reject) => {
    ffmpeg(videoPath)
      .output(gifPath)
      .outputOptions([
        '-vf', 'scale=480:-1:flags=lanczos,fps=15',
        '-t', '3'
      ])
      .on('end', async () => {
        try {
          // Upload to Firebase Storage
          await bucket.upload(gifPath, {
            destination: `previews/${videoId}.gif`,
            metadata: { contentType: 'image/gif' }
          });
          
          // Get public URL
          const [url] = await bucket
            .file(`previews/${videoId}.gif`)
            .getSignedUrl({ action: 'read', expires: '03-01-2500' });
          
          // Cleanup
          await fs.promises.unlink(gifPath);
          return resolve(url);
        } catch (error) {
          reject(error);
        }
      })
      .on('error', reject);
  });
}

// Function to convert to HLS
async function convertToHLS(videoPath, videoId) {
  const hlsDir = path.join(os.tmpdir(), `hls_${videoId}`);
  await fs.promises.mkdir(hlsDir, { recursive: true });
  
  return new Promise((resolve, reject) => {
    ffmpeg(videoPath)
      .outputOptions([
        '-profile:v', 'baseline',
        '-level', '3.0',
        '-start_number', '0',
        '-hls_time', '10',
        '-hls_list_size', '0',
        '-f', 'hls'
      ])
      .output(path.join(hlsDir, 'playlist.m3u8'))
      .on('end', async () => {
        try {
          // Upload all HLS files
          const files = await fs.promises.readdir(hlsDir);
          for (const file of files) {
            const filePath = path.join(hlsDir, file);
            const contentType = file.endsWith('.m3u8') ? 
              'application/x-mpegURL' : 'video/MP2T';
            
            await bucket.upload(filePath, {
              destination: `videos/${videoId}/hls/${file}`,
              metadata: { contentType }
            });
          }
          
          // Get playlist URL
          const [url] = await bucket
            .file(`videos/${videoId}/hls/playlist.m3u8`)
            .getSignedUrl({ action: 'read', expires: '03-01-2500' });
          
          // Cleanup
          await fs.promises.rm(hlsDir, { recursive: true });
          return resolve(url);
        } catch (error) {
          reject(error);
        }
      })
      .on('error', reject);
  });
}

export default async (req, res) => {
  console.log('Request received:', {
    method: req.method,
    url: req.url,
    headers: req.headers,
    body: req.body
  });

  // Initialize Firebase Storage
  const storage = new Storage({
    projectId: process.env.FIREBASE_PROJECT_ID,
    credentials: JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  });
  const bucket = storage.bucket(process.env.FIREBASE_STORAGE_BUCKET);

  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    // Verify authentication
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ') || 
        authHeader.split(' ')[1] !== process.env.API_SECRET_KEY) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    // Initialize Replicate client
    const replicate = new Replicate({
      auth: process.env.REPLICATE_API_TOKEN,
    });

    // Check if this is a status check request
    const statusMatch = req.url?.match(/\/api\/status\/([^\/]+)/) || 
                       req.url?.match(/\/api\?id=([^&]+)/);
    if (req.method === 'GET' && statusMatch) {
      const id = statusMatch[1];
      console.log('Checking prediction status:', id);
      
      const prediction = await replicate.predictions.get(id);
      console.log('Prediction status:', prediction.status);

      // If generation is complete, process the video
      if (prediction.status === 'succeeded' && prediction.output) {
        try {
          console.log('Processing completed video...');
          const videoPath = await downloadVideo(prediction.output);
          
          // Generate all assets in parallel
          const [thumbnailUrl, previewUrl, hlsUrl] = await Promise.all([
            generateThumbnail(videoPath, id),
            generatePreviewGif(videoPath, id),
            convertToHLS(videoPath, id)
          ]);

          // Cleanup downloaded video
          await fs.promises.unlink(videoPath);

          return res.json({
            success: true,
            status: 'succeeded',
            videoUrl: prediction.output,
            thumbnailUrl,
            previewUrl,
            hlsUrl,
            progress: 1.0
          });
        } catch (error) {
          console.error('Error processing video:', error);
          return res.json({
            success: true,
            status: 'failed',
            error: 'Video processing failed: ' + error.message
          });
        }
      }

      // Calculate progress based on prediction status
      let progress = 0;
      switch (prediction.status) {
        case 'starting':
          progress = 0.1;
          break;
        case 'processing':
          progress = 0.5;
          break;
        case 'succeeded':
          progress = 1.0;
          break;
        case 'failed':
          progress = 0;
          break;
      }

      return res.json({
        success: true,
        status: prediction.status,
        progress,
        error: prediction.error
      });
    }

    // Handle initial video generation request
    if (req.method === 'POST' && (req.url === '/api/generate' || req.url === '/api')) {
      const { prompt, userId, requireHLS = true, generateGif = true } = req.body;
      
      if (!prompt) {
        return res.status(400).json({ error: 'Prompt is required' });
      }

      // Check content moderation
      if (shouldModerateContent(prompt)) {
        console.log('Content moderation triggered for prompt:', prompt);
        return res.json({
          success: true,
          isModeratedContent: true
        });
      }

      console.log('Starting video generation:', {
        prompt,
        userId,
        requireHLS,
        generateGif
      });

      const prediction = await replicate.predictions.create({
        version: "luma/ray",
        input: { 
          prompt,
          width: 1080,
          height: 1920,
          num_frames: 150,
          fps: 30
        }
      });

      console.log('Prediction created:', prediction.id);
      return res.json({
        success: true,
        id: prediction.id,
        status: prediction.status
      });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}; 