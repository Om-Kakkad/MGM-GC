import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { onSlotWrite } from './tee-times/onSlotWrite';
import { releaseHeldSlots } from './tee-times/releaseHeldSlots';

admin.initializeApp();

// Export the cloud functions
export const onTeeTimeSlotUpdate = functions.firestore
  .document('teeTimes/{dateId}/slots/{slotId}')
  .onWrite(onSlotWrite);

export const scheduledReleaseHeldSlots = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(releaseHeldSlots);
