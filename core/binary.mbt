///|
/// MFC CString形式で文字列を読み込む
fn read_cstring(reader~ : Reader) -> String {
  let len_byte = reader.read_byte().to_int()
  let length = if len_byte < 0xFF {
    len_byte
  } else {
    let len_word = reader.read_word().to_int()
    if len_word < 0xFFFF {
      len_word
    } else {
      let len_dword = reader.read_dword().reinterpret_as_int()
      // 過度に大きな値は保護
      if len_dword < 0 || len_dword > 1000000 {
        0
      } else {
        len_dword
      }
    }
  }

  // 長さが負または過度に大きい場合は空文字列を返す
  if length <= 0 || length > 1000000 {
    return ""
  }

  // 残りデータが不足している場合は可能な範囲で読み取る
  let actual_length = if reader.remaining() < length {
    reader.remaining()
  } else {
    length
  }
  let bytes = reader.read_bytes(n=actual_length)
  @encoding_sjis.shift_jis_to_utf8(data=bytes)
}

///|
/// MFC CString形式で文字列を書き込む
fn write_cstring(writer~ : Writer, s~ : String) -> Unit {
  // 簡易実装: ASCIIのみ対応
  let bytes = string_to_ascii(s~)
  let len = bytes.length()
  if len < 255 {
    writer.write_byte(b=len.to_byte())
  } else if len < 65535 {
    let b255 : Int = 255
    writer.write_byte(b=b255.to_byte())
    writer.write_word(w=len.to_uint16())
  } else {
    let b255 : Int = 255
    let w65535 : Int = 65535
    writer.write_byte(b=b255.to_byte())
    writer.write_word(w=w65535.to_uint16())
    writer.write_dword(d=len.reinterpret_as_uint())
  }
  if len > 0 {
    writer.write_bytes(data=bytes)
  }
}

///|
/// 文字列を ASCII バイト列に変換
fn string_to_ascii(s~ : String) -> Bytes {
  let bytes = Array::new()
  for c in s.to_array() {
    bytes.push(c.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}
