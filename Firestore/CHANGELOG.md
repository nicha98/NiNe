# Unreleased

# v0.9.2
- [changed] Firestore now retries requests more often before considering a client offline.
- [changed] You can now use FieldValue.delete() with SetOptions.merge().

# v0.9.1
- [fixed] Fixed validation of nested arrays to allow indirect nesting.

# v0.9.0
- [fixed] Add an NS_SWIFT_NAME for FIRSnapshotMetadata and FIRListenerRegistration.
- [fixed] Fixed retain cycle in DocumentReference.getDocument(completion:).

# v0.8.0
- Initial public release.
