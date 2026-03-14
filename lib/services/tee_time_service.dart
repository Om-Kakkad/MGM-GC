import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mgm_gc/models/tee_time_model.dart';
import 'package:mgm_gc/models/booking_model.dart';
import 'package:intl/intl.dart';

class TeeTimeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final StreamSubscription<User?> _authStateSub;

  // Cache for the current user's member status
  bool? _isMember;
  // Cache for admin status
  bool? _isAdmin;
  String? _cachedUserId;

  TeeTimeService() {
    _authStateSub = _auth.authStateChanges().listen((user) {
      if (_cachedUserId != user?.uid) {
        _clearUserCache();
      }
    });
  }

  void _clearUserCache() {
    _isMember = null;
    _isAdmin = null;
    _cachedUserId = _auth.currentUser?.uid;
  }

  void _ensureCacheForCurrentUser(String userId) {
    if (_cachedUserId != userId) {
      _clearUserCache();
      _cachedUserId = userId;
    }
  }

  // Get tee times for a specific date
  Stream<List<TeeTimeModel>> getTeeTimes(String dateId) {
    return _firestore
        .collection('teeTimes')
        .doc(dateId)
        .collection('slots')
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TeeTimeModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get bookings for the current user
  Stream<List<BookingModel>> getUserBookings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc))
              .toList();
        });
  }

  // Check if user is a member
  Future<bool> isUserMember() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _clearUserCache();
      return false;
    }

    _ensureCacheForCurrentUser(userId);
    if (_isMember != null) return _isMember!;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;

    // Check golfDetails.isMember instead of membershipStatus
    final userData = userDoc.data();
    if (userData != null) {
      if (userData['golfDetails'] != null) {
        // Check in golfDetails object
        _isMember = userData['golfDetails']['isMember'] == true;
      } else {
        // Fallback to check at root level if golfDetails is not present
        _isMember = userData['isMember'] == true;
      }
    } else {
      _isMember = false;
    }

    return _isMember ?? false;
  }

  // Check if user is an admin
  Future<bool> isUserAdmin() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _clearUserCache();
      return false;
    }

    _ensureCacheForCurrentUser(userId);
    if (_isAdmin != null) return _isAdmin!;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data();
      _isAdmin = userData?['role'] == 'admin';
      return _isAdmin ?? false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authStateSub.cancel();
    super.dispose();
  }

  // Book a tee time with transaction to ensure atomicity
  Future<bool> bookTeeTime(
    String dateId,
    String slotId,
    List<PlayerInfo> players,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    bool success = false;

    try {
      // Get current user's name for the booker field
      String? bookerName = await _getCurrentUserName();

      await _firestore.runTransaction((transaction) async {
        // Get the current slot
        DocumentReference slotRef = _firestore
            .collection('teeTimes')
            .doc(dateId)
            .collection('slots')
            .doc(slotId);

        DocumentSnapshot slotSnapshot = await transaction.get(slotRef);

        if (!slotSnapshot.exists) {
          throw Exception('Slot does not exist');
        }

        TeeTimeModel slot = TeeTimeModel.fromFirestore(slotSnapshot);

        final isOpen = slot.status == TeeTimeStatus.open;
        final isHeldByCurrentUser =
            slot.status == TeeTimeStatus.held && slot.bookedByUid == userId;

        // Slot can be booked if open, or if this user currently holds it.
        if (!isOpen && !isHeldByCurrentUser) {
          throw Exception('Slot is not available');
        }

        // Get player names for the slot update
        List<String> playerNames = players.map((p) => p.name).toList();

        // Update slot to booked
        transaction.update(slotRef, {
          'status': TeeTimeStatus.booked.toString().split('.').last,
          'bookedByUid': userId,
          'players': playerNames,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create primary booking record
        DocumentReference bookingRef = _firestore.collection('bookings').doc();
        final primaryBookingId = bookingRef.id;

        transaction.set(
          bookingRef,
          BookingModel(
            id: primaryBookingId,
            teeTimeId: slotId,
            dateId: dateId,
            userId: userId,
            bookerName: bookerName,
            bookingDate: DateTime.now(),
            startTime: slot.startTime,
            endTime: slot.endTime,
            players: players,
            isPaid: true,
            isSharedBooking: false,
            primaryBookingId: null,
          ).toFirestore(),
        );

        // Create shared bookings for registered players
        for (final player in players) {
          if (player.isRegistered &&
              player.userId != null &&
              player.userId != userId) {
            DocumentReference sharedBookingRef =
                _firestore.collection('bookings').doc();
            transaction.set(
              sharedBookingRef,
              BookingModel(
                id: sharedBookingRef.id,
                teeTimeId: slotId,
                dateId: dateId,
                userId: player.userId!,
                bookerName:
                    bookerName, // Include booker name in shared bookings
                bookingDate: DateTime.now(),
                startTime: slot.startTime,
                endTime: slot.endTime,
                players: players,
                isPaid: true,
                isSharedBooking: true,
                primaryBookingId: primaryBookingId,
              ).toFirestore(),
            );
          }
        }
      });

      success = true;
    } catch (e) {
      print('Error booking tee time: $e');
      success = false;
    }

    return success;
  }

  // Helper method to get current user's name
  Future<String?> _getCurrentUserName() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data();
      if (userData == null) return null;

      String firstName = userData['firstName'] ?? '';
      String lastName = userData['lastName'] ?? '';

      if (firstName.isEmpty && lastName.isEmpty) {
        return userData['email'] ?? 'Unknown User';
      }

      return '$firstName $lastName'.trim();
    } catch (e) {
      print('Error getting user name: $e');
      return null;
    }
  }

  // Hold a slot temporarily (for guests during payment)
  Future<bool> holdTeeTime(String dateId, String slotId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference slotRef = _firestore
            .collection('teeTimes')
            .doc(dateId)
            .collection('slots')
            .doc(slotId);

        DocumentSnapshot slotSnapshot = await transaction.get(slotRef);

        if (!slotSnapshot.exists) {
          throw Exception('Slot does not exist');
        }

        TeeTimeModel slot = TeeTimeModel.fromFirestore(slotSnapshot);

        if (slot.status != TeeTimeStatus.open) {
          throw Exception('Slot is not available');
        }

        transaction.update(slotRef, {
          'status': TeeTimeStatus.held.toString().split('.').last,
          'bookedByUid': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Error holding tee time: $e');
      return false;
    }
  }

  // Admin function to block a slot
  Future<bool> blockSlot(String dateId, String slotId, String reason) async {
    try {
      await _firestore
          .collection('teeTimes')
          .doc(dateId)
          .collection('slots')
          .doc(slotId)
          .update({
            'status': TeeTimeStatus.blocked.toString().split('.').last,
            'reason': reason,
          });

      return true;
    } catch (e) {
      print('Error blocking slot: $e');
      return false;
    }
  }

  // Admin function to unblock a slot
  Future<bool> unblockSlot(String dateId, String slotId) async {
    try {
      await _firestore
          .collection('teeTimes')
          .doc(dateId)
          .collection('slots')
          .doc(slotId)
          .update({
            'status': TeeTimeStatus.open.toString().split('.').last,
            'reason': null,
          });

      return true;
    } catch (e) {
      print('Error unblocking slot: $e');
      return false;
    }
  }

  // Auto-generate slots for a date if they don't exist
  Future<bool> ensureSlotsExistForDate(DateTime date) async {
    final dateId = DateFormat('yyyy-MM-dd').format(date);

    try {
      // Check if slots already exist for this date
      final existingSlots =
          await _firestore
              .collection('teeTimes')
              .doc(dateId)
              .collection('slots')
              .limit(1)
              .get();

      // If no slots exist, generate them for any authenticated user
      if (existingSlots.docs.isEmpty) {
        // Make sure user is authenticated
        if (_auth.currentUser != null) {
          await _generateSlotsForDate(date);
          return true;
        } else {
          print('Cannot create slots: User is not authenticated');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error ensuring slots exist: $e');
      return false;
    }
  }

  // Generate slots for a specific date (06:00 - 17:45)
  Future<void> _generateSlotsForDate(DateTime date) async {
    try {
      final dateId = DateFormat('yyyy-MM-dd').format(date);

      // Set start and end times
      final startTime = DateTime(
        date.year,
        date.month,
        date.day,
        6,
        0,
      ); // 6:00 AM
      final endTime = DateTime(
        date.year,
        date.month,
        date.day,
        17,
        45,
      ); // 5:45 PM

      // Calculate number of 15-minute slots
      final slotDuration = const Duration(minutes: 15);
      final totalMinutes = endTime.difference(startTime).inMinutes;
      final numberOfSlots = (totalMinutes / slotDuration.inMinutes).floor();

      // Create batch for efficient writes
      final batch = _firestore.batch();

      // Create slots
      for (int i = 0; i < numberOfSlots; i++) {
        final slotStartTime = startTime.add(slotDuration * i);
        final slotEndTime = slotStartTime.add(slotDuration);

        final slotId = DateFormat('HHmm').format(slotStartTime);
        final slotRef = _firestore
            .collection('teeTimes')
            .doc(dateId)
            .collection('slots')
            .doc(slotId);

        batch.set(slotRef, {
          'startTime': Timestamp.fromDate(slotStartTime),
          'endTime': Timestamp.fromDate(slotEndTime),
          'status': TeeTimeStatus.open.toString().split('.').last,
          'bookedByUid': null,
          'players': [],
          'reason': null,
        });
      }

      // Commit the batch
      await batch.commit();
      print('Successfully generated $numberOfSlots slots for $dateId');
    } catch (e) {
      print('Error generating slots: $e');
      rethrow; // Re-throw to allow caller to handle
    }
  }

  // Admin function to delete a specific slot
  Future<bool> deleteSlot(String dateId, String slotId) async {
    try {
      await _firestore
          .collection('teeTimes')
          .doc(dateId)
          .collection('slots')
          .doc(slotId)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting slot: $e');
      return false;
    }
  }

  // Admin function to delete all slots for a date
  Future<bool> deleteAllSlotsForDate(String dateId) async {
    try {
      // Get all slots for the date
      final slotsSnapshot =
          await _firestore
              .collection('teeTimes')
              .doc(dateId)
              .collection('slots')
              .get();

      // If no slots exist, return success
      if (slotsSnapshot.docs.isEmpty) return true;

      // Create batch for efficient deletes
      final batch = _firestore.batch();

      // Add delete operations to batch
      for (var doc in slotsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      return true;
    } catch (e) {
      print('Error deleting slots for date: $e');
      return false;
    }
  }

  // Search for users by email or name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty || query.length < 3) {
      return [];
    }

    try {
      // Search by email
      final emailResults =
          await _firestore
              .collection('users')
              .where('email', isGreaterThanOrEqualTo: query)
              .where('email', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(5)
              .get();

      // Search by first name
      final firstNameResults =
          await _firestore
              .collection('users')
              .where('firstName', isGreaterThanOrEqualTo: query)
              .where('firstName', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(5)
              .get();

      // Search by last name
      final lastNameResults =
          await _firestore
              .collection('users')
              .where('lastName', isGreaterThanOrEqualTo: query)
              .where('lastName', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(5)
              .get();

      // Combine results, removing duplicates
      Set<String> addedIds = {};
      List<Map<String, dynamic>> results = [];

      void addResults(QuerySnapshot snapshot) {
        for (var doc in snapshot.docs) {
          if (!addedIds.contains(doc.id)) {
            addedIds.add(doc.id);

            final data = doc.data() as Map<String, dynamic>;
            String displayName =
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
            if (displayName.isEmpty) {
              displayName = data['email'] ?? 'Unknown User';
            }

            results.add({
              'id': doc.id,
              'name': displayName,
              'email': data['email'] ?? '',
            });
          }
        }
      }

      addResults(emailResults);
      addResults(firstNameResults);
      addResults(lastNameResults);

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
}
