const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.setUserRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  const callerUid = context.auth.uid;
  const caller = await admin.auth().getUser(callerUid);
  if (!caller.customClaims || caller.customClaims.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Admin privileges required.');
  }

  const { uid, role } = data;
  if (!uid || !role) {
    throw new functions.https.HttpsError('invalid-argument', 'uid and role are required');
  }

  await admin.firestore().collection('users').doc(uid).update({ role });

  const claims = role === 'admin' ? { admin: true } : { admin: false };
  await admin.auth().setCustomUserClaims(uid, claims);

  return { success: true };
});
