import hljs from 'highlight.js/lib/core'
import json from 'highlight.js/lib/languages/json'

hljs.registerLanguage('json', json)

// only activate highlighting on pages with this selector
if (document.querySelectorAll('[data-activate-highlight]').length > 0) {
  hljs.highlightAll()
}
