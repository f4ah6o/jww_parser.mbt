///|
/// JWWドキュメントシリアライザー

///|
/// JWWドキュメントをバイト列にシリアライズする
pub fn serialize(doc~ : Document) -> Bytes {
  let writer = Writer::new()

  // シグネチャ
  writer.write_bytes(data=signature())

  // バージョン
  writer.write_dword(d=doc.version)

  // ヘッダー情報
  write_cstring(writer~, s=doc.memo)
  writer.write_dword(d=doc.paper_size)
  writer.write_dword(d=doc.write_layer_group)

  // レイヤグループ（16グループ）
  for lg in doc.layer_groups {
    writer.write_dword(d=lg.state)
    writer.write_dword(d=lg.write_layer)
    writer.write_double(d=lg.scale)
    writer.write_dword(d=lg.protect)
    for l in lg.layers {
      writer.write_dword(d=l.state)
      writer.write_dword(d=l.protect)
    }
  }

  // エンティティリスト
  write_entity_list(writer~, entities=doc.entities, version=doc.version)
  writer.to_bytes()
}

///|
/// エンティティリストを書き込む
fn write_entity_list(
  writer~ : Writer,
  entities~ : Array[Entity],
  version~ : UInt,
) -> Unit {
  let count = entities.length()
  writer.write_word(w=count.to_uint16())

  // PID トラッキング
  let mut class_map : Array[String] = Array::new()
  for _ in 0..<256 {
    class_map.push("")
  }
  let mut next_pid : UInt = 1U
  for entity in entities {
    let (class_name, updated_map, updated_pid) = track_class(
      entity~,
      class_map~,
      next_pid~,
    )
    write_entity(writer~, entity~, class_name~, version~)
    class_map = updated_map
    next_pid = updated_pid
  }
}

///|
/// クラス名をトラッキングして PID を管理
fn track_class(
  entity~ : Entity,
  class_map~ : Array[String],
  next_pid~ : UInt,
) -> (String, Array[String], UInt) {
  let class_name = entity_class_name(entity~)

  // 既存の PID を検索
  let mut found_pid : UInt = 0U
  let mut i = 1
  while i <= 255 && i <= class_map.length() - 1 {
    if class_map[i] == class_name {
      found_pid = i.reinterpret_as_uint()
      break
    }
    i = i + 1
  }
  let (updated_map, updated_next_pid) = if found_pid != 0U {
    (class_map, next_pid)
  } else {
    // 新しいクラス定義を書き込む必要がある
    let pid = next_pid
    let new_map = class_map
    if pid < 256U {
      new_map[pid.reinterpret_as_int()] = class_name
    }
    (new_map, pid + 1)
  }
  (class_name, updated_map, updated_next_pid)
}
