#!/usr/bin/env node
'use strict';

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'mgm-golf';
const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';

process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();
const auth = admin.auth();

const DAY_MS = 24 * 60 * 60 * 1000;

const IDS = {
  events: {
    league: 'mgm-league-2025',
    testLeague: 'test-league',
  },
  teams: {
    eagles: 'eagles',
    falcons: 'falcons',
    hawks: 'hawks',
    lions: 'lions',
    testA: 'test-team-a',
    testB: 'test-team-b',
  },
  matches: {
    match1: 'match-1',
    match2: 'match-2',
    testMatch: 'test-match',
  },
  docs: {
    course: 'mgm-main-course',
    bobPastBooking: 'bob-past-booking',
    bobPastScorecard: 'bob-past-scorecard',
    bobHandicapRecord: 'bob-handicap-record',
  },
};

const SEEDED_USERS = {
  admin: {
    uid: 'admin-mgmgc',
    email: 'admin@mgmgc.com',
    password: 'AdminPass1',
    role: 'admin',
    firstName: 'Admin',
    lastName: 'MGM',
    handicap: 6.0,
    isMember: true,
  },
  joeGuest: {
    uid: 'joe-guest',
    email: 'joe.guest@example.com',
    password: 'GuestPass1',
    role: 'user',
    firstName: 'Joe',
    lastName: 'Guest',
    handicap: 20.0,
    isMember: false,
  },
  joePlayer: {
    uid: 'joe-player',
    email: 'joe.player@example.com',
    password: 'PlayerPass1',
    role: 'user',
    firstName: 'Joe',
    lastName: 'Player',
    handicap: 14.0,
    isMember: true,
  },
  eveRequester: {
    uid: 'eve-requester',
    email: 'eve.requester@example.com',
    password: 'RequestPass1',
    role: 'user',
    firstName: 'Eve',
    lastName: 'Requester',
    handicap: 16.5,
    isMember: true,
  },
  eaglesPlayer: {
    uid: 'eagles-player',
    email: 'eagles.player@example.com',
    password: 'EaglesPass1',
    role: 'league_player',
    firstName: 'Ethan',
    lastName: 'Eagle',
    handicap: 9.0,
    isMember: true,
  },
  falconsPlayer: {
    uid: 'falcons-player',
    email: 'falcons.player@example.com',
    password: 'FalconsPass1',
    role: 'league_player',
    firstName: 'Frank',
    lastName: 'Falcon',
    handicap: 10.0,
    isMember: true,
  },
  hawksPlayer: {
    uid: 'hawks-player',
    email: 'hawks.player@example.com',
    password: 'HawksPass1',
    role: 'league_player',
    firstName: 'Hannah',
    lastName: 'Hawk',
    handicap: 12.0,
    isMember: true,
  },
  lionsPlayer: {
    uid: 'lions-player',
    email: 'lions.player@example.com',
    password: 'LionsPass1',
    role: 'league_player',
    firstName: 'Leo',
    lastName: 'Lion',
    handicap: 11.5,
    isMember: true,
  },
  unrelated: {
    uid: 'sam-unrelated',
    email: 'sam.unrelated@example.com',
    password: 'UnrelatedPass1',
    role: 'user',
    firstName: 'Sam',
    lastName: 'Unrelated',
    handicap: 19.0,
    isMember: true,
  },
};

function toDateId(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function atLocal(date, hour, minute) {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    hour,
    minute,
    0,
    0,
  );
}

function midnightLocal(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

async function emulatorDelete(url) {
  const response = await fetch(url, { method: 'DELETE' });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`DELETE ${url} failed: ${response.status} ${body}`);
  }
}

async function resetEmulatorData() {
  const firestoreUrl = `http://${FIRESTORE_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const authUrl = `http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`;

  await emulatorDelete(firestoreUrl);
  await emulatorDelete(authUrl);
}

async function ensureAuthUser(user) {
  try {
    await auth.getUser(user.uid);
    await auth.updateUser(user.uid, {
      email: user.email,
      password: user.password,
      displayName: `${user.firstName} ${user.lastName}`,
    });
  } catch (_) {
    await auth.createUser({
      uid: user.uid,
      email: user.email,
      password: user.password,
      displayName: `${user.firstName} ${user.lastName}`,
    });
  }
}

async function upsertUserDoc(user, overrides = {}) {
  const now = new Date();
  const base = {
    uid: user.uid,
    email: user.email,
    role: user.role,
    firstName: user.firstName,
    lastName: user.lastName,
    dateOfBirth: new Date(1990, 0, 1),
    gender: 'Prefer not to say',
    phoneNumber: '9999999999',
    golfDetails: {
      handicap: user.handicap,
      isMember: user.isMember,
      membershipId: user.isMember ? `MEM-${user.uid}` : null,
      playingInLeague: user.role === 'league_player',
      teamId: null,
      teamName: null,
      eventId: null,
      bracket: null,
    },
    createdAt: now,
    updatedAt: now,
  };

  await db.collection('users').doc(user.uid).set({ ...base, ...overrides }, { merge: true });
}

async function seedCourse() {
  await db.collection('courses').doc(IDS.docs.course).set({
    name: 'MGM GC',
    par: 69,
    courseRating: 69.0,
    slopeRating: 155.0,
    holePars: [3, 3, 4, 4, 5, 3, 5, 4, 3, 4, 5, 3, 5, 3, 4, 3, 4, 4],
    holeIndexes: [18, 8, 2, 10, 4, 14, 6, 16, 12, 9, 1, 13, 3, 15, 11, 17, 7, 5],
  });
}

async function seedTeeTimeSlotsForDate(date) {
  const dateId = toDateId(date);
  const start = atLocal(date, 6, 0);
  const end = atLocal(date, 17, 45);
  const slotMinutes = 15;
  const totalMinutes = Math.floor((end.getTime() - start.getTime()) / 60000);
  const slots = Math.floor(totalMinutes / slotMinutes);

  const batch = db.batch();

  for (let i = 0; i < slots; i += 1) {
    const slotStart = new Date(start.getTime() + i * slotMinutes * 60000);
    const slotEnd = new Date(slotStart.getTime() + slotMinutes * 60000);
    const slotId = `${String(slotStart.getHours()).padStart(2, '0')}${String(slotStart.getMinutes()).padStart(2, '0')}`;
    const ref = db.collection('teeTimes').doc(dateId).collection('slots').doc(slotId);
    batch.set(ref, {
      startTime: slotStart,
      endTime: slotEnd,
      status: 'open',
      bookedByUid: null,
      players: [],
      reason: null,
      updatedAt: new Date(),
    });
  }

  await batch.commit();
}

async function seedEventsAndTeams(today) {
  const plus7 = new Date(today.getTime() + 7 * DAY_MS);

  await db.collection('events').doc(IDS.events.league).set({
    eventID: IDS.events.league,
    eventName: 'MGM League 2025',
    eventDescription: 'Seeded league event for manual QA',
    eventType: 'League',
    eventDates: [today, plus7],
    date: today,
    createdAt: new Date(),
    brackets: {
      gold: { name: 'Gold Bracket', minHandicap: 0, maxHandicap: 10 },
      silver: { name: 'Silver Bracket', minHandicap: 11, maxHandicap: 16 },
      bronze: { name: 'Bronze Bracket', minHandicap: 17, maxHandicap: 24 },
    },
  });

  const leagueTeams = [
    {
      id: IDS.teams.eagles,
      name: 'Eagles',
      password: 'Eagles123',
      players: [SEEDED_USERS.eaglesPlayer.uid],
      matches: [IDS.matches.match1, IDS.matches.match2],
    },
    {
      id: IDS.teams.falcons,
      name: 'Falcons',
      password: 'Falcons123',
      players: [SEEDED_USERS.falconsPlayer.uid],
      matches: [IDS.matches.match1, IDS.matches.match2],
    },
    {
      id: IDS.teams.hawks,
      name: 'Hawks',
      password: 'Hawks123',
      players: [SEEDED_USERS.hawksPlayer.uid],
      matches: [],
    },
    {
      id: IDS.teams.lions,
      name: 'Lions',
      password: 'Lions123',
      players: [SEEDED_USERS.lionsPlayer.uid],
      matches: [],
    },
  ];

  for (const team of leagueTeams) {
    await db
      .collection('events')
      .doc(IDS.events.league)
      .collection('teams')
      .doc(team.id)
      .set({
        teamID: team.id,
        eventID: IDS.events.league,
        teamName: team.name,
        teamPassword: team.password,
        players: team.players,
        matches: team.matches,
        createdAt: new Date(),
      });
  }

  const match1Time = atLocal(today, 9, 0);
  const match2Time = atLocal(today, 10, 0);

  await db
    .collection('events')
    .doc(IDS.events.league)
    .collection('matches')
    .doc(IDS.matches.match1)
    .set({
      matchID: IDS.matches.match1,
      teams: [IDS.teams.eagles, IDS.teams.falcons],
      players: {
        teamA: [SEEDED_USERS.eaglesPlayer.uid],
        teamB: [SEEDED_USERS.falconsPlayer.uid],
      },
      participantUids: [SEEDED_USERS.eaglesPlayer.uid, SEEDED_USERS.falconsPlayer.uid],
      matchType: '2-ball',
      matchPlayType: 'match play',
      matchDateTime: match1Time,
      matchStatus: 'active',
      holeResults: {},
      strokeMap: {},
      bonusPoint: false,
      matchOver: false,
      teamARegularPoints: 0,
      teamABonusPoints: 0,
      teamBRegularPoints: 0,
      teamBBonusPoints: 0,
      createdAt: new Date(),
    });

  await db
    .collection('events')
    .doc(IDS.events.league)
    .collection('matches')
    .doc(IDS.matches.match2)
    .set({
      matchID: IDS.matches.match2,
      teams: [IDS.teams.eagles, IDS.teams.falcons],
      players: {
        teamA: [SEEDED_USERS.eaglesPlayer.uid],
        teamB: [SEEDED_USERS.falconsPlayer.uid],
      },
      participantUids: [SEEDED_USERS.eaglesPlayer.uid, SEEDED_USERS.falconsPlayer.uid],
      matchType: '2-ball',
      matchPlayType: 'match play',
      matchDateTime: match2Time,
      matchStatus: 'active',
      holeResults: {},
      strokeMap: {},
      bonusPoint: false,
      matchOver: false,
      teamARegularPoints: 0,
      teamABonusPoints: 0,
      teamBRegularPoints: 0,
      teamBBonusPoints: 0,
      createdAt: new Date(),
    });

  await db.collection('events').doc(IDS.events.testLeague).set({
    eventID: IDS.events.testLeague,
    eventName: 'Test League',
    eventDescription: 'Seeded event for delete-event test',
    eventType: 'League',
    eventDates: [today],
    date: today,
    createdAt: new Date(),
  });

  await db
    .collection('events')
    .doc(IDS.events.testLeague)
    .collection('teams')
    .doc(IDS.teams.testA)
    .set({
      teamID: IDS.teams.testA,
      eventID: IDS.events.testLeague,
      teamName: 'Test Team A',
      teamPassword: 'TestA123',
      players: [SEEDED_USERS.hawksPlayer.uid],
      matches: [IDS.matches.testMatch],
      createdAt: new Date(),
    });

  await db
    .collection('events')
    .doc(IDS.events.testLeague)
    .collection('teams')
    .doc(IDS.teams.testB)
    .set({
      teamID: IDS.teams.testB,
      eventID: IDS.events.testLeague,
      teamName: 'Test Team B',
      teamPassword: 'TestB123',
      players: [SEEDED_USERS.lionsPlayer.uid],
      matches: [IDS.matches.testMatch],
      createdAt: new Date(),
    });

  await db
    .collection('events')
    .doc(IDS.events.testLeague)
    .collection('matches')
    .doc(IDS.matches.testMatch)
    .set({
      matchID: IDS.matches.testMatch,
      teams: [IDS.teams.testA, IDS.teams.testB],
      players: {
        teamA: [SEEDED_USERS.hawksPlayer.uid],
        teamB: [SEEDED_USERS.lionsPlayer.uid],
      },
      participantUids: [SEEDED_USERS.hawksPlayer.uid, SEEDED_USERS.lionsPlayer.uid],
      matchType: '2-ball',
      matchPlayType: 'match play',
      matchDateTime: atLocal(today, 11, 0),
      matchStatus: 'active',
      holeResults: {},
      bonusPoint: false,
      matchOver: false,
      createdAt: new Date(),
    });
}

async function applyLeagueMembershipToSeededPlayers() {
  const updates = [
    {
      user: SEEDED_USERS.eaglesPlayer,
      teamId: IDS.teams.eagles,
      teamName: 'Eagles',
    },
    {
      user: SEEDED_USERS.falconsPlayer,
      teamId: IDS.teams.falcons,
      teamName: 'Falcons',
    },
    {
      user: SEEDED_USERS.hawksPlayer,
      teamId: IDS.teams.hawks,
      teamName: 'Hawks',
    },
    {
      user: SEEDED_USERS.lionsPlayer,
      teamId: IDS.teams.lions,
      teamName: 'Lions',
    },
  ];

  for (const item of updates) {
    await db.collection('users').doc(item.user.uid).set(
      {
        role: 'league_player',
        matches: [IDS.matches.match1, IDS.matches.match2],
        golfDetails: {
          handicap: item.user.handicap,
          isMember: true,
          membershipId: `MEM-${item.user.uid}`,
          playingInLeague: true,
          teamId: item.teamId,
          teamName: item.teamName,
          eventId: IDS.events.league,
          bracket: 'Gold',
        },
        updatedAt: new Date(),
      },
      { merge: true },
    );
  }
}

async function seedBase() {
  const now = new Date();
  const today = midnightLocal(now);
  const bookingDate = new Date(today.getTime() + DAY_MS);

  for (const user of Object.values(SEEDED_USERS)) {
    await ensureAuthUser(user);
    await upsertUserDoc(user);
  }

  await seedCourse();
  await seedEventsAndTeams(today);
  await applyLeagueMembershipToSeededPlayers();
  await seedTeeTimeSlotsForDate(bookingDate);

  console.log('Seed complete.');
  console.log(`PROJECT_ID=${PROJECT_ID}`);
  console.log(`BOOKING_TEST_DATE=${toDateId(bookingDate)}`);
  console.log('ADMIN_EMAIL=admin@mgmgc.com ADMIN_PASSWORD=AdminPass1');
  console.log('JOE_GUEST_EMAIL=joe.guest@example.com JOE_GUEST_PASSWORD=GuestPass1');
  console.log('JOE_PLAYER_EMAIL=joe.player@example.com JOE_PLAYER_PASSWORD=PlayerPass1');
  console.log('EVE_REQUESTER_EMAIL=eve.requester@example.com EVE_REQUESTER_PASSWORD=RequestPass1');
  console.log('EAGLES_PLAYER_EMAIL=eagles.player@example.com EAGLES_PLAYER_PASSWORD=EaglesPass1');
  console.log('FALCONS_PLAYER_EMAIL=falcons.player@example.com FALCONS_PLAYER_PASSWORD=FalconsPass1');
  console.log('UNRELATED_EMAIL=sam.unrelated@example.com UNRELATED_PASSWORD=UnrelatedPass1');
}

function buildPlayerMap(name, uid) {
  return {
    player_0: {
      name,
      userId: uid,
      isRegistered: true,
    },
  };
}

function seededDifferentials(baseDate) {
  return [
    {
      scorecardId: 'seed-diff-1',
      playDate: new Date(baseDate.getTime() - 5 * DAY_MS),
      value: 13.4,
      courseName: 'MGM GC',
    },
    {
      scorecardId: 'seed-diff-2',
      playDate: new Date(baseDate.getTime() - 4 * DAY_MS),
      value: 12.9,
      courseName: 'MGM GC',
    },
    {
      scorecardId: 'seed-diff-3',
      playDate: new Date(baseDate.getTime() - 3 * DAY_MS),
      value: 13.1,
      courseName: 'MGM GC',
    },
  ];
}

function seededHoleScores() {
  const values = [5, 5, 4, 5, 6, 4, 6, 5, 4, 5, 6, 4, 6, 5, 4, 5, 5, 4];
  const result = {};
  for (let i = 0; i < values.length; i += 1) {
    result[String(i + 1)] = values[i];
  }
  return result;
}

async function seedBobArtifacts() {
  const now = new Date();
  const today = midnightLocal(now);
  const pastDate = new Date(today.getTime() - DAY_MS);
  const pastDateId = toDateId(pastDate);

  const bob = await auth.getUserByEmail('bob.member@example.com');
  const bobUid = bob.uid;

  const bobDoc = await db.collection('users').doc(bobUid).get();
  const bobData = bobDoc.exists ? bobDoc.data() : null;
  const bobFirstName = bobData && bobData.firstName ? bobData.firstName : 'Bob';
  const bobLastName = bobData && bobData.lastName ? bobData.lastName : 'Member';
  const bobName = `${bobFirstName} ${bobLastName}`.trim();
  const bobHandicap =
    bobData && bobData.golfDetails && typeof bobData.golfDetails.handicap === 'number'
      ? bobData.golfDetails.handicap
      : 12.0;

  await seedTeeTimeSlotsForDate(pastDate);

  const pastStart = atLocal(pastDate, 7, 30);
  const pastEnd = atLocal(pastDate, 7, 45);

  await db.collection('teeTimes').doc(pastDateId).collection('slots').doc('0730').set(
    {
      startTime: pastStart,
      endTime: pastEnd,
      status: 'booked',
      bookedByUid: bobUid,
      players: [bobName],
      reason: null,
      updatedAt: new Date(),
    },
    { merge: true },
  );

  await db.collection('bookings').doc(IDS.docs.bobPastBooking).set({
    teeTimeId: '0730',
    dateId: pastDateId,
    userId: bobUid,
    bookerName: bobName,
    bookingDate: new Date(),
    startTime: pastStart,
    endTime: pastEnd,
    players: buildPlayerMap(bobName, bobUid),
    isPaid: true,
    amountPaid: 0,
    isSharedBooking: false,
    primaryBookingId: null,
  });

  await db.collection('scorecards').doc(IDS.docs.bobPastScorecard).set({
    bookingId: IDS.docs.bobPastBooking,
    userId: bobUid,
    playDate: pastStart,
    playerScores: {
      [bobUid]: {
        userId: bobUid,
        playerName: bobName,
        holeScores: seededHoleScores(),
        handicapIndex: bobHandicap,
        courseHandicap: 0,
        adjustedGrossScore: 88,
        scoreDifferential: 13.4,
      },
    },
    isCompleted: true,
    completedAt: new Date(),
    courseName: 'MGM GC',
    coursePar: 69,
    courseRating: 69.0,
    slopeRating: 155.0,
    pcc: 0,
  });

  await db.collection('handicapRecords').doc(IDS.docs.bobHandicapRecord).set({
    userId: bobUid,
    scoreDifferentials: seededDifferentials(today),
    handicapIndex: 13.1,
    lastUpdated: new Date(),
  });

  console.log('Bob artifacts seeded.');
}

function calculateHandicapIndex(differentials) {
  const count = differentials.length;
  if (count < 3) {
    return null;
  }

  const sorted = differentials
    .map((item) => item.value)
    .sort((a, b) => a - b);

  let scoresUsed;
  if (count <= 4) {
    scoresUsed = 1;
  } else if (count <= 8) {
    scoresUsed = 2;
  } else if (count <= 10) {
    scoresUsed = 3;
  } else if (count <= 12) {
    scoresUsed = 4;
  } else if (count <= 14) {
    scoresUsed = 5;
  } else if (count <= 16) {
    scoresUsed = 6;
  } else if (count <= 18) {
    scoresUsed = 7;
  } else {
    scoresUsed = 8;
  }

  const total = sorted.slice(0, scoresUsed).reduce((sum, value) => sum + value, 0);
  return Math.round((total / scoresUsed) * 10) / 10;
}

async function recalcHandicaps() {
  const snapshot = await db.collection('handicapRecords').get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const differentials = Array.isArray(data.scoreDifferentials) ? data.scoreDifferentials : [];
    const nextIndex = calculateHandicapIndex(differentials);

    await doc.ref.update({
      handicapIndex: nextIndex,
      lastUpdated: new Date(),
    });

    if (nextIndex !== null && data.userId) {
      await db.collection('users').doc(data.userId).set(
        {
          golfDetails: {
            handicap: nextIndex,
          },
          updatedAt: new Date(),
        },
        { merge: true },
      );
    }
  }

  console.log('Handicap recalculation complete.');
}

function printUsage() {
  console.log('Usage: node scripts/manual_test_data.js <command>');
  console.log('Commands:');
  console.log('  reset           Reset Auth + Firestore emulator data');
  console.log('  seed            Reset + seed base manual test data');
  console.log('  seed-bob        Seed Bob-dependent booking/scorecard/handicap data');
  console.log('  recalc-handicaps Recalculate handicapRecords into users.golfDetails.handicap');
}

async function main() {
  const command = process.argv[2];

  if (!command) {
    printUsage();
    process.exit(1);
  }

  if (command === 'reset') {
    await resetEmulatorData();
    console.log('Emulator data reset complete.');
    return;
  }

  if (command === 'seed') {
    await resetEmulatorData();
    await seedBase();
    return;
  }

  if (command === 'seed-bob') {
    await seedBobArtifacts();
    return;
  }

  if (command === 'recalc-handicaps') {
    await recalcHandicaps();
    return;
  }

  printUsage();
  process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
