const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin with application default credentials
admin.initializeApp();

/**
 * Cloud Function that assigns the admin role to the first user if no admin exists yet
 * Triggers when a new user is created in Firebase Authentication
 */
exports.assignFirstUserAsAdmin = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();
  
  try {
    // Log the creation of a new user
    functions.logger.info('New user created:', user.uid, user.email);
    
    // First check if this user already has a document in Firestore
    const userDoc = await db.collection('users').doc(user.uid).get();
    
    // Check if any admin users exist in the database
    const adminQuery = await db.collection('users')
      .where('role', '==', 'admin')
      .limit(1)
      .get();
      
    // If no admin exists, make this user an admin
    if (adminQuery.empty) {
      functions.logger.info('No admin found. Assigning admin role to first user:', user.uid);
      
      // Create a basic user document with admin role
      // This will be merged with any additional profile info when they complete registration
      const userData = {
        uid: user.uid,
        email: user.email,
        role: 'admin', // Set role to admin
        createdAt: new Date(),
        updatedAt: new Date()
      };
      
      // Only set name fields if not already populated
      if (!userDoc.exists || !userDoc.data()?.firstName) {
        userData.firstName = user.displayName ? user.displayName.split(' ')[0] : 'Admin';
      }
      
      if (!userDoc.exists || !userDoc.data()?.lastName) {
        userData.lastName = user.displayName && user.displayName.split(' ').length > 1 
          ? user.displayName.split(' ').slice(1).join(' ') 
          : 'User';
      }
      
      // Use merge to avoid overriding any existing data
      await db.collection('users').doc(user.uid).set(userData, { merge: true });
      
      functions.logger.info('Successfully assigned admin role to:', user.uid);
      return { success: true, message: 'First user assigned as admin' };
    }
    
    functions.logger.info('Admin already exists. New user kept as regular user.');
    return { success: true, message: 'Admin already exists' };
  } catch (error) {
    functions.logger.error('Error in assignFirstUserAsAdmin:', error);
    return { success: false, error: error.message };
  }
});
