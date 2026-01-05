///|
/// メタデータプレフィックスかどうかを判定する
fn is_metadata_text(content~ : String) -> Bool {
  content.has_prefix("Printer_") ||
  content.has_prefix("Draw_") ||
  content.has_prefix("View_")
}
