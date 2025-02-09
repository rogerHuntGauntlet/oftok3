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
  // Check if user is authenticated
  if (!context.auth) {
    console.error('Unauthenticated request to listUsers');
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to list users'
    );
  }

  try {
    console.log('listUsers called by user:', context.auth.uid);
    console.log('Search query:', data.query);
    
    const { query = '' } = data;
    console.log('Fetching users from Firebase Auth...');
    const listUsersResult = await admin.auth().listUsers();
    console.log('Found total users:', listUsersResult.users.length);
    
    // Filter and map users
    const users = listUsersResult.users
      .filter(user => {
        const searchLower = query.toLowerCase();
        const displayName = (user.displayName || '').toLowerCase();
        const email = (user.email || '').toLowerCase();
        
        // Don't include the requesting user
        if (user.uid === context.auth?.uid) {
          console.log('Excluding requesting user:', user.uid);
          return false;
        }
        
        // If no query, include all users
        if (!query) return true;
        
        // Search by display name or email
        const matches = displayName.includes(searchLower) || 
                       email.includes(searchLower);
        if (matches) {
          console.log('User matches search:', user.uid);
        }
        return matches;
      })
      .map(user => ({
        id: user.uid,
        displayName: user.displayName || 'User',
        email: user.email || '',
        photoUrl: user.photoURL,
        isAuthenticated: true
      }))
      .sort((a, b) => a.displayName.localeCompare(b.displayName));

    console.log('Returning filtered users:', users.length);
    return { users };
  } catch (error) {
    console.error('Error in listUsers:', error);
    console.error('Error stack:', error.stack);
    throw new functions.https.HttpsError(
      'internal',
      'Error listing users: ' + error.message
    );
  }
});
