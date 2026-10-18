import 'package:cloud_firestore/cloud_firestore.dart';

class Profile {
  const Profile({required this.uid, required this.name, required this.email});

  final String uid;
  final String name;
  final String email;

  Map<String, dynamic> toMap() => {'name': name, 'email': email};

  factory Profile.fromMap(String uid, Map<String, dynamic> map) => Profile(
        uid: uid,
        name: (map['name'] as String?)?.trim().isNotEmpty == true
            ? map['name'] as String
            : (map['email'] as String? ?? ''),
        email: map['email'] as String? ?? '',
      );
}

/// Wspólna przestrzeń dwóch osób. W dokumencie są oboje członkowie i aktualny kod zaproszenia.
class Space {
  const Space({
    required this.id,
    required this.memberIds,
    required this.profiles,
    this.inviteCode,
  });

  final String id;
  final List<String> memberIds;
  final Map<String, Profile> profiles;
  final String? inviteCode;

  bool get isFull => memberIds.length >= 2;

  Profile? partnerOf(String myUid) {
    for (final id in memberIds) {
      if (id != myUid) return profiles[id];
    }
    return null;
  }

  factory Space.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    final rawProfiles =
        (data['profiles'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return Space(
      id: snap.id,
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      profiles: {
        for (final e in rawProfiles.entries)
          e.key: Profile.fromMap(e.key, Map<String, dynamic>.from(e.value as Map)),
      },
      inviteCode: data['inviteCode'] as String?,
    );
  }
}
