///|
/// JWWファイルパーサー

///|
/// JWWシグネチャ
pub fn signature() -> Bytes {
  b"JwwData."
}

///|
/// JWWファイルをパースする
pub fn parse(data~ : Bytes) -> Document {
  // シグネチャ検証
  if data.length() < 8 {
    return Document::default()
  }
  let sig = Bytes::from_array(data.to_array()[0:8])
  if sig != signature() {
    return Document::default()
  }
  let reader = Reader::new(
    data=Bytes::from_array(data.to_array()[8:data.length()]),
  )

  // バージョン読み取り
  let version = reader.read_dword()

  // ヘッダー情報読み取り
  let memo = read_cstring(reader~)
  let paper_size = reader.read_dword()
  let write_layer_group = reader.read_dword()

  // レイヤグループ読み取り (16グループ)
  let layer_groups = Array::new()
  for _g_idx in 0..<16 {
    let state = reader.read_dword()
    let write_layer = reader.read_dword()
    let scale = reader.read_double()
    let protect = reader.read_dword()
    let layers = Array::new()
    for _l_idx in 0..<16 {
      let lay_state = reader.read_dword()
      let lay_protect = reader.read_dword()
      layers.push({ state: lay_state, protect: lay_protect, name: "" })
    }
    layer_groups.push({ state, write_layer, scale, protect, layers, name: "" })
  }

  // 印刷設定を読み取り
  let print_settings = parse_print_settings(reader~)

  // 日光設定を読み取り
  let sunpou_settings = parse_sunpou_settings(reader~)

  // レイヤ名を読み取り
  let layer_groups = parse_layer_names(reader~, layer_groups~)

  // エンティティリスト開始位置を探索
  let entity_offset = find_entity_list_offset(data~, version~)
  let (entities, block_defs, block_end_offset) = match entity_offset {
    Some(offset) => {
      let entity_result = parse_entity_list(data~, offset~, version~)
      // エンティティリストの直後にブロック定義リストがある
      let block_offset = offset + entity_result.bytes_consumed
      let block_result = parse_block_def_list(
        data~,
        offset=block_offset,
        version~,
      )
      (entity_result.entities, block_result.block_defs, block_result.end_offset)
    }
    None => (Array::new(), Array::new(), 0)
  }

  // Ver.7.00以上の場合、同梱画像をパース
  let embedded_images = if version >= 700 {
    parse_embedded_images(data~, offset=block_end_offset, version~)
  } else {
    Array::new()
  }

  // レイヤー名を設定
  let named_layer_groups = set_layer_names(layer_groups~)
  {
    version,
    memo,
    paper_size,
    write_layer_group,
    layer_groups: named_layer_groups,
    entities,
    block_defs,
    embedded_images,
    print_settings,
    sunpou_settings,
    metadata_settings: MetadataSettings::default(),
  }
}
