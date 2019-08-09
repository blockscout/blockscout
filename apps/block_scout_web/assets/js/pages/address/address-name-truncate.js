var truncateAddr = function (fullStr, strLen, separator) {
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
var aStrCheck = document.getElementById('aStr')
if (document.body.contains(aStrCheck)) {
  var aStr = document.getElementById('aStr').innerHTML
  document.getElementById('aStr').innerHTML = truncateAddr(aStr, 20)
}
