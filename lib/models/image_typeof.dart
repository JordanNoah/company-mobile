enum ImageTypeof {
  avatar,
  banner,
  thumbnail
}

extension ImageTypeofX on ImageTypeof {
  String get value => switch (this) {
        ImageTypeof.avatar => 'avatar',
        ImageTypeof.banner => 'banner',
        ImageTypeof.thumbnail => 'thumbnail',
      };
}