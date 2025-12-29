///|
/// DXF変換の Property-Based Testing

///|
/// pi_value が正しい値を持つ
test "pi value" {
  let pi = pi_value()
  let expected = 3.141592653589793
  let diff = if pi < expected { expected - pi } else { pi - expected }
  inspect(diff < 0.0000000001, content="true")
}

///|
/// ラジアンから度への変換の既知値
test "rad to deg known values" {
  let pi = pi_value()
  // 0度 = 0ラジアン
  inspect(rad_to_deg(rad=0.0) < 0.001, content="true")
  // 180度 = πラジアン
  let deg180 = rad_to_deg(rad=pi)
  inspect((deg180 - 180.0).abs() < 0.001, content="true")
}

///|
/// map_color の既知値チェック
test "map color known values" {
  inspect(map_color(jww_color=1), content="4")
  inspect(map_color(jww_color=2), content="7")
  inspect(map_color(jww_color=3), content="3")
  inspect(map_color(jww_color=4), content="2")
  inspect(map_color(jww_color=5), content="6")
}

///|
/// map_line_type の既知値チェック
test "map line type known values" {
  inspect(map_line_type(pen_style=0), content="CONTINUOUS")
  inspect(map_line_type(pen_style=2), content="DASHED")
  inspect(map_line_type(pen_style=3), content="DASHDOT")
  inspect(map_line_type(pen_style=4), content="CENTER")
  inspect(map_line_type(pen_style=5), content="DOT")
}

///|
/// レイヤー数が常に256であることを確認
test "layer count is 256" {
  let doc = @core.Document::default()
  let dxf = convert_document(jww_doc=doc)
  inspect(dxf.layers.length(), content="256")
}
