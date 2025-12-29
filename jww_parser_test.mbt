///|
test "simple" {
  let x = 1 + 2
  inspect(x, content="3")
}

///|
test "sum" {
  let array = [1, 2, 3, 4, 5]
  let mut total = 0
  for i in 0..<array.length() {
    total = total + array[i]
  }
  inspect(total, content="15")
}
