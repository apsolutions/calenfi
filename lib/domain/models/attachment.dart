/// Вложение события (RFC 5545 `ATTACH`, Google `attachments`, Graph
/// `attachments`).
///
/// Храним только ссылку и подпись: файл лежит в облаке провайдера, качать его
/// в базу незачем. Встроенные (`VALUE=BINARY`) вложения не поддерживаем —
/// такие приходят редко и раздувают локальную базу.
class Attachment {
  const Attachment({
    required this.uri,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  /// Ссылка на файл у провайдера.
  final String uri;

  /// Имя файла, если провайдер его прислал (`FILENAME`, `X-FILENAME`,
  /// `title`). Иначе в карточке показываем последний сегмент ссылки.
  final String? fileName;

  /// MIME-тип (`FMTTYPE`, `mimeType`) — по нему выбирается иконка.
  final String? mimeType;

  /// Размер в байтах, если известен.
  final int? sizeBytes;

  /// Что писать в карточке: имя файла, иначе хвост ссылки, иначе сама ссылка.
  String get displayName {
    final name = fileName?.trim();
    if (name != null && name.isNotEmpty) return name;
    // pathSegments уже раскодирован: повторный decodeComponent падал на
    // ссылках с одиночным «%».
    final path = Uri.tryParse(uri)?.pathSegments;
    if (path != null && path.isNotEmpty && path.last.isNotEmpty) {
      return path.last;
    }
    return uri;
  }

  @override
  bool operator ==(Object other) =>
      other is Attachment &&
      other.uri == uri &&
      other.fileName == fileName &&
      other.mimeType == mimeType &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(uri, fileName, mimeType, sizeBytes);
}
