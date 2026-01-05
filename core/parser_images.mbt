///|
/// 文字列内の ^@BM マーカーの位置を見つける
fn find_bm_marker(content~ : String) -> Int? {
  let chars = content.to_array()
  let len = chars.length()

  // "^@BM" (4文字: ^ @ B M) の位置を探す
  if len < 4 {
    return None
  }
  let mut i = 0
  while i < len - 3 {
    if chars[i] == '^' &&
      chars[i + 1] == '@' &&
      chars[i + 2] == 'B' &&
      chars[i + 3] == 'M' {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// @BM形式の文字列から画像情報をパースする
fn parse_image_from_bm_string(
  content~ : String,
  base~ : EntityBase,
  start_x~ : Double,
  start_y~ : Double,
  angle~ : Double,
  size_x~ : Double,
  size_y~ : Double,
) -> Image? {
  // ^@BM の位置を見つける
  let bm_offset = match find_bm_marker(content~) {
    Some(offset) => offset
    None => return None
  }
  // "^@BM" (4文字) を除去
  let chars = content.to_array()
  if chars.length() <= bm_offset + 4 {
    return None
  }
  let path_and_params = String::from_array(chars[bm_offset + 4:])
  // カンマで分割
  let parts = split_by_comma(path_and_params~)
  if parts.length() < 1 {
    return None
  }
  // 最初の部分がファイルパス
  let raw_path = parts[0]
  let image_path = normalize_image_path(raw_path~)
  // 幅と高さ: JWWはsize_x, size_yを使用（または後続パラメータ）
  let width = if parts.length() >= 2 {
    parse_double_or_default(parts[1], size_x)
  } else {
    size_x
  }
  let height = if parts.length() >= 3 {
    parse_double_or_default(parts[2], size_y)
  } else {
    size_y
  }
  Some({
    base,
    image_path,
    x: start_x,
    y: start_y,
    width,
    height,
    rotation: angle,
  })
}

///|
/// 文字列をカンマで分割する
fn split_by_comma(path_and_params~ : String) -> Array[String] {
  let result = Array::new()
  let mut current = ""
  for c in path_and_params {
    if c == ',' {
      result.push(current)
      current = ""
    } else {
      current = current + c.to_string()
    }
  }
  if current != "" {
    result.push(current)
  }
  result
}

///|
/// 画像パスを正規化する（%temp%などの環境変数プレフィックスを処理）
fn normalize_image_path(raw_path~ : String) -> String {
  let all_chars = raw_path.to_array()
  // %temp%プレフィックスを除去
  let chars = if raw_path.has_prefix("%temp%") && all_chars.length() > 6 {
    Array::from_iter(all_chars[6:].iter())
  } else {
    all_chars
  }
  // アンダースコアをスラッシュに変換（JWW特有のパス変換）
  // 例: C_Users_... -> C:/Users/...
  let mut normalized = ""
  let mut prev_was_letter = false
  for c in chars {
    if c == '_' && prev_was_letter {
      normalized = normalized + "/"
      prev_was_letter = false
    } else {
      normalized = normalized + c.to_string()
      prev_was_letter = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
    }
  }
  normalized
}

///|
/// 文字列をDoubleにパースする（失敗時はデフォルト値を返す）
fn parse_double_or_default(s : String, default : Double) -> Double {
  @strconv.parse_double(s) catch {
    _ => default
  }
}

///|
/// 画像データのフォーマットをマジックバイトから検出する
fn detect_image_format(data~ : Bytes) -> ImageFormat {
  if data.length() < 4 {
    return ImageFormat::Unknown
  }
  let b0 = data[0].to_int()
  let b1 = data[1].to_int()
  let b2 = data[2].to_int()
  let b3 = data[3].to_int()

  // JPEG: FF D8 FF
  if b0 == 0xFF && b1 == 0xD8 && b2 == 0xFF {
    return ImageFormat::Jpeg
  }

  // PNG: 89 50 4E 47 (...PNG)
  if b0 == 0x89 && b1 == 0x50 && b2 == 0x4E && b3 == 0x47 {
    return ImageFormat::Png
  }

  // BMP: 42 4D (BM)
  if b0 == 0x42 && b1 == 0x4D {
    return ImageFormat::Bmp
  }

  // GIF: 47 49 46 38 (GIF8)
  if b0 == 0x47 && b1 == 0x49 && b2 == 0x46 && b3 == 0x38 {
    return ImageFormat::Gif
  }
  ImageFormat::Unknown
}

///|
/// 単一の同梱画像をパースする
fn parse_single_embedded_image(
  reader~ : Reader,
  index~ : UInt,
) -> EmbeddedImage? {
  // ファイルサイズを読み取り (DWORD = 4バイト)
  if reader.remaining() < 4 {
    return None
  }
  let file_size = reader.read_dword()

  // ファイルサイズの妥当性チェック
  // 0バイトまたは過度に大きい場合はエラー
  if file_size == 0U || file_size > 100_000_000U {
    // 100MB上限
    return None
  }
  let file_size_int = file_size.reinterpret_as_int()

  // 残りデータが不足している場合はNoneを返す
  if reader.remaining() < file_size_int {
    return None
  }

  // 画像データを読み取り
  let image_data = reader.read_bytes(n=file_size_int)

  // データが空の場合はNoneを返す
  if image_data.length() == 0 {
    return None
  }

  // 画像フォーマットを検出
  let format = detect_image_format(data=image_data)
  Some({ index, file_size, data: image_data, format })
}

///|
/// 同梱画像リストをパースする (Ver.7.00+)
fn parse_embedded_images(
  data~ : Bytes,
  offset~ : Int,
  version~ : UInt,
) -> Array[EmbeddedImage] {
  // Version 7.00未満では空配列を返す
  if version < 700 {
    return Array::new()
  }

  // offsetがデータ範囲外の場合は空配列を返す
  if offset >= data.length() {
    return Array::new()
  }
  let image_data = Bytes::from_array(data.to_array()[offset:data.length()])
  let reader = Reader::new(data=image_data)

  // データが4バイト未満の場合は空配列を返す
  if reader.remaining() < 4 {
    return Array::new()
  }

  // 画像数を読み取り
  let count = reader.read_dword()

  // カウントが異常な値の場合は空配列を返す（保護）
  // 同梱画像は通常数個程度
  if count > 1000U {
    return Array::new()
  }
  let embedded_images = Array::new()

  // 各画像をパース
  for i in 0..<count.reinterpret_as_int() {
    let result = parse_single_embedded_image(
      reader~,
      index=i.reinterpret_as_uint(),
    )
    match result {
      Some(img) => embedded_images.push(img)
      None => () // エラー時はスキップして継続
    }
  }
  embedded_images
}
