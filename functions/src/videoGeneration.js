const Replicate = require('replicate');
const functions = require('firebase-functions');
const admin = require('firebase-admin');
require('dotenv').config();

const replicate = new Replicate({
  auth: process.env.REPLICATE_API_TOKEN,
});

const DAILY_LIMIT = 10;

exports.generateVideo = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new Error('Authentication required!');
    }

    const { prompt } = data;
    if (!prompt) {
      throw new Error('Prompt is required!');
    }

    // Get today's date at midnight UTC
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Check daily limit
    const statsRef = admin.firestore().collection('videoGenerationStats').doc(today.toISOString().split('T')[0]);
    
    const statsDoc = await statsRef.get();
    const currentCount = statsDoc.exists ? statsDoc.data().count || 0 : 0;

    if (currentCount >= DAILY_LIMIT) {
      throw new Error('Daily video generation limit reached. Please try again tomorrow.');
    }

    // Generate the video
    const output = await replicate.run("luma/ray", {
      input: {
        prompt: prompt
      }
    });

    // Increment the counter
    await statsRef.set({
      count: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Log the generation
    await admin.firestore().collection('videoGenerations').add({
      userId: context.auth.uid,
      prompt: prompt,
      videoUrl: output,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { 
      success: true, 
      videoUrl: output,
      remainingToday: DAILY_LIMIT - (currentCount + 1)
    };
  } catch (error) {
    console.error('Error generating video:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
}); 