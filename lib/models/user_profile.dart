class UserProfile {
  String userId;
  String name;
  String email;
  String password;

  UserProfile({
    this.userId = '',
    this.name = '',
    this.email = '',
    this.password = '',
  });

  Map<String, dynamic> toJson() => {
    "userId": userId,
    "name": name,
    "email": email,
  };
}
