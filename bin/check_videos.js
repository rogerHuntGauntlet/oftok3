const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs } = require('firebase/firestore');
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

async function checkVideos() {
  try {
    const videosRef = collection(db, 'videos');
    const snapshot = await getDocs(videosRef);
    
    console.log(`Found ${snapshot.size} total videos`);
    
    let missingHLS = [];
    let missingThumbnails = [];
    let missingMetadata = [];
    
    snapshot.forEach(doc => {
      const video = doc.data();
      const issues = [];
      
      if (!video.hlsUrl) {
        missingHLS.push({
          id: doc.id,
          title: video.title || 'Untitled',
          url: video.url
        });
      }
      
      if (!video.thumbnailUrl) {
        missingThumbnails.push({
          id: doc.id,
          title: video.title || 'Untitled'
        });
      }
      
      if (!video.description || !video.tags || video.tags.length === 0) {
        missingMetadata.push({
          id: doc.id,
          title: video.title || 'Untitled',
          missing: {
            description: !video.description,
            tags: !video.tags || video.tags.length === 0
          }
        });
      }
    });
    
    console.log('\n=== Video Status Report ===');
    console.log(`Total videos: ${snapshot.size}`);
    console.log(`Videos with HLS: ${snapshot.size - missingHLS.length}`);
    console.log(`Videos with thumbnails: ${snapshot.size - missingThumbnails.length}`);
    console.log(`Videos with complete metadata: ${snapshot.size - missingMetadata.length}`);
    
    if (missingHLS.length > 0) {
      console.log('\nVideos missing HLS:');
      missingHLS.forEach(video => {
        console.log(`- ${video.title} (${video.id})`);
        console.log(`  URL: ${video.url}`);
      });
    }
    
    if (missingThumbnails.length > 0) {
      console.log('\nVideos missing thumbnails:');
      missingThumbnails.forEach(video => {
        console.log(`- ${video.title} (${video.id})`);
      });
    }
    
    if (missingMetadata.length > 0) {
      console.log('\nVideos missing metadata:');
      missingMetadata.forEach(video => {
        console.log(`- ${video.title} (${video.id})`);
        console.log(`  Missing: ${video.missing.description ? 'description ' : ''}${video.missing.tags ? 'tags' : ''}`);
      });
    }
    
    if (missingHLS.length === 0 && missingThumbnails.length === 0 && missingMetadata.length === 0) {
      console.log('\nAll videos are properly configured with HLS, thumbnails, and metadata! 🎉');
    }
    
  } catch (error) {
    console.error('Error checking videos:', error);
  }
}

// Run the check if this file is run directly
if (require.main === module) {
  checkVideos().then(() => process.exit());
} 