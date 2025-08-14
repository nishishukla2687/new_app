class UserData {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  UserData({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  // Convert UserData to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Create UserData from Firestore document
  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  // Create UserData from Firebase Auth User
  factory UserData.fromFirebaseUser(dynamic user) {
    return UserData(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserData{uid: $uid, email: $email, displayName: $displayName, createdAt: $createdAt}';
  }
}