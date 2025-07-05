import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

/**
 * Cloud function to release tee time slots that have been held for too long
 * This runs every 15 minutes via Pub/Sub scheduler
 */
export const releaseHeldSlots = async (context: functions.EventContext) => {
  const firestore = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  // Define the holding period threshold (15 minutes)
  const holdPeriodInMinutes = 15;
  const holdThreshold = new Date(now.toMillis() - (holdPeriodInMinutes * 60 * 1000));
  
  try {
    // Get all tee time date documents
    const teeDates = await firestore.collection('teeTimes').get();
    let totalReleasedSlots = 0;
    
    // Process each date document
    for (const dateDoc of teeDates.docs) {
      const dateId = dateDoc.id;
      
      // Query for held slots that have been held longer than the threshold
      const heldSlots = await firestore
        .collection('teeTimes')
        .doc(dateId)
        .collection('slots')
        .where('status', '==', 'held')
        .get();
      
      if (!heldSlots.empty) {
        const batch = firestore.batch();
        let releasedCount = 0;
        
        // Check each held slot
        for (const slotDoc of heldSlots.docs) {
          const slotData = slotDoc.data();
          const lastUpdated = slotData.lastUpdated || slotData.updatedAt || now;
          
          // If the slot has been held for too long, release it
          if (lastUpdated.toDate() < holdThreshold) {
            batch.update(slotDoc.ref, {
              'status': 'open',
              'bookedByUid': null,
              'updatedAt': now
            });
            releasedCount++;
          }
        }
        
        if (releasedCount > 0) {
          await batch.commit();
          totalReleasedSlots += releasedCount;
          console.log(`Released ${releasedCount} held slots for date ${dateId}`);
        }
      }
    }
    
    console.log(`Total released slots: ${totalReleasedSlots}`);
    return { success: true, releasedSlots: totalReleasedSlots };
  } catch (error) {
    console.error('Error releasing held slots:', error);
    return { success: false, error: error };
  }
};
