import $ from 'jquery'
import hljs from 'highlight.js'
import hljsDefineSolidity from 'highlightjs-solidity'

// only activate highlighting on pages with this selector
if ($('[data-activate-highlight]').length > 0) {
  hljsDefineSolidity(hljs)
  hljs.initHighlightingOnLoad()
}
