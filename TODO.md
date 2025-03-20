# TODO and Known Issues

## Match Creation Error

### Issue
When creating a match, the app successfully creates the match in Firestore but shows an error message:
```
Error creating match: Null check operator used on a null value
```

### Analysis
- The error occurs after the match is successfully created in Firestore
- The error is likely happening during the update operation to set the `matchID` field or when processing the response
- The match data is correctly stored in the database despite the error
- This appears to be a non-critical error since the core functionality works properly

### Workaround Implemented
1. Modified the match creation flow to detect when a match has been successfully created
2. Added early returns to ensure we capture the match ID before any potential errors
3. Improved error handling to distinguish between critical errors (document not created) and non-critical errors (update issues)
4. Added navigation to return to the admin panel after successful creation, even if minor errors occur

### Future Improvements
- [ ] Investigate the root cause by adding more detailed logging around Firebase operations
- [ ] Consider refactoring the Match model to better handle Firestore serialization/deserialization
- [ ] Add better error types to distinguish between different failure modes
- [ ] Consider using transactions for related operations that need to be atomic
