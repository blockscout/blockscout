import hljs from 'highlight.js/lib/core'

// only activate highlighting on pages with this selector
if (document.querySelectorAll('[data-activate-highlight]').length > 0) {
  hljs.highlightAll()
}
