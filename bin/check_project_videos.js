const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs, doc, updateDoc } = require('firebase/firestore');
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

async function checkProjectVideos() {
  try {
    // First, get all videos to create a lookup set
    console.log('Fetching all videos...');
    const videosRef = collection(db, 'videos');
    const videoSnapshot = await getDocs(videosRef);
    const validVideoIds = new Set();
    videoSnapshot.forEach(doc => validVideoIds.add(doc.id));
    console.log(`Found ${validVideoIds.size} valid videos`);

    // Now check all projects
    console.log('\nFetching all projects...');
    const projectsRef = collection(db, 'projects');
    const projectSnapshot = await getDocs(projectsRef);
    console.log(`Found ${projectSnapshot.size} projects`);

    const projectsWithInvalidVideos = [];
    let totalInvalidVideos = 0;

    projectSnapshot.forEach(projectDoc => {
      const project = projectDoc.data();
      const invalidVideos = [];

      // Check videos array if it exists
      if (Array.isArray(project.videos)) {
        project.videos.forEach(videoId => {
          if (!validVideoIds.has(videoId)) {
            invalidVideos.push(videoId);
            totalInvalidVideos++;
          }
        });
      }

      if (invalidVideos.length > 0) {
        projectsWithInvalidVideos.push({
          projectId: projectDoc.id,
          projectName: project.name || 'Unnamed Project',
          invalidVideos,
          totalVideos: project.videos ? project.videos.length : 0
        });
      }
    });

    // Print report
    console.log('\n=== Project Videos Status Report ===');
    console.log(`Total projects checked: ${projectSnapshot.size}`);
    console.log(`Projects with invalid videos: ${projectsWithInvalidVideos.length}`);
    console.log(`Total invalid video references: ${totalInvalidVideos}`);

    if (projectsWithInvalidVideos.length > 0) {
      console.log('\nProjects with invalid videos:');
      projectsWithInvalidVideos.forEach(project => {
        console.log(`\nProject: ${project.projectName} (${project.projectId})`);
        console.log(`Total videos: ${project.totalVideos}`);
        console.log('Invalid video IDs:');
        project.invalidVideos.forEach(videoId => {
          console.log(`- ${videoId}`);
        });
      });

      // Ask if we should fix the issues
      console.log('\nWould you like to remove these invalid video references? (Run with --fix flag)');
      if (process.argv.includes('--fix')) {
        console.log('\nFixing invalid video references...');
        for (const project of projectsWithInvalidVideos) {
          const projectRef = doc(db, 'projects', project.projectId);
          const projectDoc = await getDocs(projectRef);
          const projectData = projectDoc.data();
          
          // Filter out invalid videos
          const validVideos = projectData.videos.filter(videoId => validVideoIds.has(videoId));
          
          // Update the project
          await updateDoc(projectRef, {
            videos: validVideos
          });
          
          console.log(`✓ Updated project ${project.projectName}: Removed ${project.invalidVideos.length} invalid videos`);
        }
        console.log('\nAll invalid video references have been removed.');
      }
    } else {
      console.log('\nAll project video references are valid! 🎉');
    }
  } catch (error) {
    console.error('Error checking project videos:', error);
  }
}

// Run the check if this file is run directly
if (require.main === module) {
  checkProjectVideos().then(() => process.exit());
} 