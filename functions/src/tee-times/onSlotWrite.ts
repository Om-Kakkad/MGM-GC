import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onSlotWrite = async (
  change: functions.Change<functions.firestore.DocumentSnapshot>,
  context: functions.EventContext
) => {
  const { dateId, slotId } = context.params;
  
  // If the document was deleted, no action needed
  if (!change.after.exists) {
    return null;
  }
  
  const beforeData = change.before.exists ? change.before.data() : null;
  const afterData = change.after.data();
  
  if (!afterData) {
    return null;
  }
  
  // Check if the status changed to 'booked'
  const statusChanged = !beforeData || beforeData.status !== afterData.status;
  
  if (statusChanged && afterData.status === 'booked' && afterData.bookedByUid) {
    try {
      // Create a booking record in the user's bookings collection
      const bookingRef = admin.firestore().collection('bookings').doc();
      
      await bookingRef.set({
        teeTimeId: slotId,
        dateId: dateId,
        userId: afterData.bookedByUid,
        bookingDate: admin.firestore.FieldValue.serverTimestamp(),
        startTime: afterData.startTime,
        endTime: afterData.endTime,
        players: afterData.players || [],
        isPaid: true, // Assuming payment is handled in the app
      });
      
      functions.logger.info(
        `Created booking ${bookingRef.id} for user ${afterData.bookedByUid}, tee time ${dateId}/${slotId}`
      );
      
      return null;
    } catch (error) {
      functions.logger.error('Error creating booking:', error);
      throw error;
    }
  }
  
  return null;
};
