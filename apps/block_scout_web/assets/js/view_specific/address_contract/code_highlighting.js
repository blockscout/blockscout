import '../../lib/ace/src-min/ace'
import '../../lib/ace/src-min/mode-csharp'
import '../../lib/ace/src-min/theme-chrome'
import $ from 'jquery'

/* eslint-disable-next-line */
const Mode = ace.require('ace/mode/csharp').Mode

const codeMain = $('#code_viewer_main')
const code = codeMain.text()
/* eslint-disable-next-line */
const editor = ace.edit('code_viewer_main')
editor.session.setMode(new Mode())
editor.setTheme('ace/theme/chrome')
editor.setValue(code, -1)
editor.setOptions({ maxLines: 40, readOnly: true, printMargin: false })

const len = codeMain.data('additional-sources-length')
for (let i = 0; i < len; i++) {
  const tag = 'code_viewer_' + i
  const code = $('#' + tag).text()
  /* eslint-disable-next-line */
  const editor = ace.edit(tag)
  editor.session.setMode(new Mode())
  editor.setTheme('ace/theme/chrome')
  editor.setValue(code, -1)
  editor.setOptions({ maxLines: 40, readOnly: true })
}
