import $ from 'jquery'
import hljs from 'highlight.js'

// only activate highlighting on pages with this selector
if ($('[data-activate-highlight]').length > 0) {
  hljs.initHighlightingOnLoad()
}
