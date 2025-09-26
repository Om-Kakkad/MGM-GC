# MGM Golf Club App: Copilot Instructions

## Project Overview
MGM Golf Club (MGM GC) is a Flutter application for golf club management with features for user authentication, team management, leagues, events, tee time booking, scorecards, and live scoring.

## Architecture

### Tech Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Authentication, Firestore, Cloud Functions)
- **Testing**: Integration tests with Firebase emulators

### Key Components
1. **Authentication & User Management**
   - Firebase Auth with custom roles (admin, user)
   - User profiles with golf details including handicaps

2. **Core Features**
   - Team management and league play
   - Event scheduling and participation
   - Tee time booking system
   - Scorecard management
   - Live scoring during matches

3. **Admin Features**
   - User, team, and event management
   - Match creation and management
   - Sponsor management

## Development Workflow

### Local Development Setup
```bash
# Start Firebase emulators for local development
firebase emulators:start

# Run the app in debug mode with hot reload
flutter run
```

### Testing
```bash
# Run integration tests using Firebase emulators
flutter test integration_test/full_flow_test.dart
```

### Firebase Emulators
The app automatically connects to local emulators in debug mode:
- Firestore: localhost:8080
- Auth: localhost:9099
- Functions: localhost:5001

## Data Models & Patterns

### Firestore Collections
- `users`: User profiles with golf details
- `teams`: Team configurations and memberships
- `matches`: Match details and results
- `events`: Golf events and tournaments
- `teeTimes`: Tee time booking slots
- `scorecards`: Player scorecard data

### Service Pattern
Services handle Firebase interactions and are organized by domain:
- `AuthService`: User authentication and profile management
- `TeamService`: Team creation and membership
- `EventService`: Event management
- `TeeTimeService`: Booking system using ChangeNotifier for state
- `ScorecardService`: Score tracking and submission

### Cloud Functions
- Scheduled tasks for handicap calculations
- Tee time slot management and cleanup
- Match scoring and statistics calculations

## Conventions

### State Management
- Provider pattern for services requiring state (TeeTimeService, ScorecardService)
- Stateless widgets with service injection for Firebase operations

### Error Handling
- Firebase operations wrapped in try/catch blocks
- User-facing errors shown with Fluttertoast
- Errors logged to console in debug mode

### Navigation
- Named routes defined in main.dart
- Arguments passed through route settings

## Tips for AI Coding Assistance
- When modifying Firebase queries, maintain security rules compliance
- Match models have specific score calculation logic for golf handicaps
- Integration tests require Firebase emulators to be running
- Many operations have role-based access control (admin vs regular users)
- UI follows Material Design with custom theming