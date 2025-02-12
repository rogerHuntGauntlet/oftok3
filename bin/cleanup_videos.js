const { initializeApp } = require('firebase/app');
const { getFirestore, doc, deleteDoc } = require('firebase/firestore');
const { getStorage, ref, deleteObject } = require('firebase/storage');
const dotenv = require('dotenv');
const path = require('path');

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

// List of video IDs to delete
const videosToDelete = [
  'f52b65e6-d64c-4041-97f7-9b72ddc3b9a9', // Failed Replicate video
  '19b12611-7175-4f6e-92bf-f89ee892c769', // Undefined URL
  '78111a5e-c7b7-488f-9c6c-cb528378f0b7', // Undefined URL
  '7db0d6b8-c3dd-48a5-b00c-b661e26ba5ee'  // Undefined URL
];

async function deleteVideoFiles(videoId) {
  try {
    // Try to delete the original video file
    try {
      const videoRef = ref(storage, `videos/${videoId}.mp4`);
      await deleteObject(videoRef);
      console.log(`Deleted original video file for ${videoId}`);
    } catch (error) {
      console.log(`No original video file found for ${videoId}`);
    }

    // Try to delete the thumbnail
    try {
      const thumbnailRef = ref(storage, `thumbnails/${videoId}.jpg`);
      await deleteObject(thumbnailRef);
      console.log(`Deleted thumbnail for ${videoId}`);
    } catch (error) {
      console.log(`No thumbnail found for ${videoId}`);
    }

    // Try to delete HLS files
    try {
      const hlsRef = ref(storage, `videos/${videoId}/hls/playlist.m3u8`);
      await deleteObject(hlsRef);
      console.log(`Deleted HLS playlist for ${videoId}`);
      
      // Try to delete HLS segments (typically numbered from 0)
      for (let i = 0; i < 10; i++) {
        try {
          const segmentRef = ref(storage, `videos/${videoId}/hls/playlist${i}.ts`);
          await deleteObject(segmentRef);
          console.log(`Deleted HLS segment ${i} for ${videoId}`);
        } catch {
          break; // Stop when we can't find more segments
        }
      }
    } catch (error) {
      console.log(`No HLS files found for ${videoId}`);
    }
  } catch (error) {
    console.error(`Error deleting files for ${videoId}:`, error);
  }
}

async function cleanupVideos() {
  console.log('Starting video cleanup...');
  
  for (const videoId of videosToDelete) {
    try {
      console.log(`\nProcessing video: ${videoId}`);
      
      // Delete all associated files in storage
      await deleteVideoFiles(videoId);
      
      // Delete the document from Firestore
      await deleteDoc(doc(db, 'videos', videoId));
      console.log(`Deleted video document: ${videoId}`);
      
    } catch (error) {
      console.error(`Error processing video ${videoId}:`, error);
    }
  }
  
  console.log('\nCleanup completed!');
}

// Run the cleanup if this file is run directly
if (require.main === module) {
  cleanupVideos().then(() => process.exit());
} 