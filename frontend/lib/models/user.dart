class User {
  final String id;
  final String phone;
  final String nickname;
  final String avatar;
  final String persona;

  const User({required this.id, required this.phone, this.nickname = '', this.avatar = '', this.persona = '默认'});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    phone: json['phone'] as String,
    nickname: json['nickname'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
    persona: json['persona'] as String? ?? '默认',
  );
}
