import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Schedule to run at 00:05 on the 1st day of every month
export const monthlyHandicapRecalculation = functions.pubsub
  .schedule('5 0 1 * *')
  .timeZone('America/New_York') // Set to your local timezone
  .onRun(async (context) => {
    console.log('Starting monthly handicap recalculation job');
    
    try {
      // Get all handicap records
      const recordsSnapshot = await db.collection('handicapRecords').get();
      
      for (const doc of recordsSnapshot.docs) {
        const record = doc.data();
        const userId = record.userId;
        
        // Only recalculate if player has enough rounds (3 or more)
        if (record.scoreDifferentials && record.scoreDifferentials.length >= 3) {
          const newIndex = calculateHandicapIndex(record.scoreDifferentials);
          
          // Update handicap record
          await doc.ref.update({
            handicapIndex: newIndex,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          // Update user record if handicap index changed
          if (newIndex !== null && newIndex !== record.handicapIndex) {
            console.log(`Updating user ${userId} handicap to ${newIndex}`);
            await db.collection('users').doc(userId).update({
              'golfDetails.handicap': newIndex,
            });
          }
        }
      }
      
      console.log('Monthly handicap recalculation completed');
      return null;
    } catch (error) {
      console.error('Error in handicap recalculation job:', error);
      return null;
    }
  });

// Calculate handicap index from score differentials using WHS rules
function calculateHandicapIndex(differentials: any[]): number | null {
  const count = differentials.length;
  
  // Need at least 3 rounds to calculate handicap
  if (count < 3) {
    return null;
  }
  
  // Sort differentials by value (lowest to highest)
  const sortedDiffs = differentials
    .map(sd => sd.value)
    .sort((a, b) => a - b);
  
  // Determine number of scores to use based on WHS table
  let scoresUsed = 0;
  
  if (count <= 3) {
    scoresUsed = 1; // Lowest 1
  } else if (count <= 4) {
    scoresUsed = 1; // Lowest 1
  } else if (count <= 6) {
    scoresUsed = 2; // Lowest 2
  } else if (count <= 8) {
    scoresUsed = 2; // Lowest 2
  } else if (count <= 10) {
    scoresUsed = 3; // Lowest 3
  } else if (count <= 12) {
    scoresUsed = 4; // Lowest 4
  } else if (count <= 14) {
    scoresUsed = 5; // Lowest 5
  } else if (count <= 16) {
    scoresUsed = 6; // Lowest 6
  } else if (count <= 18) {
    scoresUsed = 7; // Lowest 7
  } else {
    scoresUsed = 8; // Lowest 8 out of 20
  }
  
  // Calculate average of lowest N scores
  let sum = 0;
  for (let i = 0; i < scoresUsed; i++) {
    sum += sortedDiffs[i];
  }
  
  const average = sum / scoresUsed;
  
  // Round to 1 decimal place
  return Math.round(average * 10) / 10;
}
