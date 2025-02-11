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
const Replicate = require('replicate');
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

exports.generateVideo = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      console.error('Authentication failed: No auth context');
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    // Skip App Check verification in development
    if (process.env.NODE_ENV !== 'production') {
      console.log('Skipping App Check verification in development mode');
    } else if (!context.app) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'App Check verification failed'
      );
    }

    const uid = context.auth.uid;
    const prompt = data.prompt;

    if (!prompt) {
      throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
    }

    // Check user's token balance
    const userRef = admin.firestore().collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const tokens = userDoc.data().tokens || 0;
    if (tokens < TOKENS_PER_GENERATION) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient tokens. You need ${TOKENS_PER_GENERATION} tokens to generate a video.`
      );
    }

    // Initialize Replicate client
    const replicate = new Replicate({
      auth: process.env.REPLICATE_API_TOKEN,
    });

    // Start the prediction
    const prediction = await replicate.predictions.create({
      version: MODEL_VERSION,
      input: {
        prompt: prompt
      },
    });

    // Wait for the prediction to complete
    const result = await replicate.predictions.wait(prediction.id);

    if (result.error) {
      throw new functions.https.HttpsError('aborted', `Video generation failed: ${result.error}`);
    }

    if (!result.output) {
      throw new functions.https.HttpsError('internal', 'No output URL was provided');
    }

    // Deduct tokens after successful generation
    await userRef.update({
      tokens: admin.firestore.FieldValue.increment(-TOKENS_PER_GENERATION)
    });

    // Return the result
    return {
      success: true,
      videoUrl: result.output,
      tokensDeducted: TOKENS_PER_GENERATION,
      remainingTokens: tokens - TOKENS_PER_GENERATION
    };

  } catch (error) {
    console.error('Video generation error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
