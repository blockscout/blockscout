var truncate = function (fullStr, strLen, separator) {
  if (fullStr.length <= strLen) {
    return fullStr
  }
  separator = separator || '...'
  var sepLen = separator.length
  var charsToShow = strLen - sepLen
  var frontChars = Math.ceil(charsToShow / 2)
  var backChars = Math.floor(charsToShow / 2)
  return fullStr.substr(0, frontChars) + separator + fullStr.substr(fullStr.length - backChars)
}
// apply truncation
var tStrCheck = document.getElementById('tStr')
if (document.body.contains(tStrCheck)) {
  var tStr = document.getElementById('tStr').innerHTML
  document.getElementById('tStr').innerHTML = truncate(tStr, 25)
}
