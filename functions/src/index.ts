import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const assignFirstUserAsAdmin = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();

  try {
    functions.logger.info('New user created:', user.uid, user.email);

    const userDoc = await db.collection('users').doc(user.uid).get();

    const adminQuery = await db
      .collection('users')
      .where('role', '==', 'admin')
      .limit(1)
      .get();

    if (adminQuery.empty) {
      functions.logger.info('No admin found. Assigning admin role to first user:', user.uid);

      const userData: any = {
        uid: user.uid,
        email: user.email,
        role: 'admin',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      if (!userDoc.exists || !(userDoc.data() as any)?.firstName) {
        userData.firstName = user.displayName ? user.displayName.split(' ')[0] : 'Admin';
      }

      if (!userDoc.exists || !(userDoc.data() as any)?.lastName) {
        userData.lastName =
          user.displayName && user.displayName.split(' ').length > 1
            ? user.displayName.split(' ').slice(1).join(' ')
            : 'User';
      }

      await db.collection('users').doc(user.uid).set(userData, { merge: true });

      functions.logger.info('Successfully assigned admin role to:', user.uid);
      return { success: true, message: 'First user assigned as admin' };
    }

    functions.logger.info('Admin already exists. New user kept as regular user.');
    return { success: true, message: 'Admin already exists' };
  } catch (error: any) {
    functions.logger.error('Error in assignFirstUserAsAdmin:', error);
    return { success: false, error: error.message };
  }
});

export const onSlotWrite = functions.firestore
  .document('teeTimes/{dateId}/slots/{slotId}')
  .onWrite(async (change, context) => {
    const beforeStatus = change.before.exists ? change.before.data()?.status : null;
    const afterData = change.after.data();

    if (afterData && beforeStatus !== 'booked' && afterData.status === 'booked') {
      const uid = afterData.uid;
      if (!uid) {
        functions.logger.warn(`Booked slot ${context.params.slotId} missing uid`);
        return null;
      }

      const bookingData = {
        dateId: context.params.dateId,
        startTime: afterData.startTime,
        endTime: afterData.endTime,
      };

      await admin
        .firestore()
        .collection('users')
        .doc(uid)
        .collection('bookings')
        .doc(context.params.slotId)
        .set(bookingData, { merge: true });
    }

    return null;
  });

export const releaseHeldSlots = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const cutoffDate = new Date(Date.now() - 15 * 60 * 1000);
    const cutoff = admin.firestore.Timestamp.fromDate(cutoffDate);

    const querySnapshot = await admin
      .firestore()
      .collectionGroup('slots')
      .where('status', '==', 'held')
      .where('updatedAt', '<', cutoff)
      .get();

    const batch = admin.firestore().batch();

    querySnapshot.forEach((doc) => {
      batch.update(doc.ref, {
        status: 'open',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    if (!querySnapshot.empty) {
      await batch.commit();
    }

    return null;
  });
