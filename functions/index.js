/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { generateVideo } = require('./src/videoGeneration');
const cors = require('cors')({ origin: true });
require('dotenv').config();

// Initialize with service account
const serviceAccount = require('./service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Export the video generation function
exports.generateVideo = generateVideo;

// User listing functions
exports.listUsers = functions.https.onCall(async (data, context) => {
  try {
    console.log('Fetching users from Firebase Auth...');
    const listUsersResult = await admin.auth().listUsers();
    console.log('Found total users:', listUsersResult.users.length);
    
    // Map users to simpler format
    const users = listUsersResult.users
      .map(user => ({
        uid: user.uid,
        displayName: user.displayName || 'User',
        email: user.email || '',
        photoUrl: user.photoURL
      }))
      .sort((a, b) => a.displayName.localeCompare(b.displayName));

    console.log('Returning users:', users.length);
    return { users };
  } catch (error) {
    console.error('Error in listUsers:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error listing users: ' + error.message
    );
  }
});

exports.listAllUsers = functions.https.onRequest(async (req, res) => {
  try {
    console.log('Fetching all users from Firebase Auth...');
    const listUsersResult = await admin.auth().listUsers();
    
    // Map users to simpler format
    const users = listUsersResult.users.map(user => ({
      uid: user.uid,
      displayName: user.displayName || 'User',
      email: user.email || '',
      photoUrl: user.photoURL
    }));

    console.log('Found users:', users.length);
    res.json({ users });
  } catch (error) {
    console.error('Error listing users:', error);
    res.status(500).json({ error: 'Failed to list users' });
  }
});

// Verify App Check token with enhanced error handling
const verifyAppCheck = async (context) => {
  if (!context.app) {
    console.error('App Check verification failed: No app context');
    throw new functions.https.HttpsError(
      'failed-precondition',
      'This app is not authorized to access Firebase services. ' +
      'Please ensure you are using an official version of the app.'
    );
  }
  
  // Log successful verification
  console.log('App Check verification successful for app:', context.app.appId);
};

const TOKENS_PER_GENERATION = 250;
const MODEL_VERSION = "luma/ray";
