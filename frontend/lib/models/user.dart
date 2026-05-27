class User {
  final String id;
  final String phone;
  final String nickname;
  final String avatar;

  const User({required this.id, required this.phone, this.nickname = '', this.avatar = ''});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    phone: json['phone'] as String,
    nickname: json['nickname'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
  );
}
