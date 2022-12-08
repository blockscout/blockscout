import '../../lib/ace/src-min/ace'
import '../../lib/ace/src-min/mode-csharp'
import '../../lib/ace/src-min/theme-chrome'

/* eslint-disable-next-line */
const Mode = ace.require('ace/mode/csharp').Mode

const codeMain = document.getElementById('code_viewer_main')
const code = codeMain.textContent
/* eslint-disable-next-line */
const editor = codeMain && ace.edit('code_viewer_main')
if (editor) {
  editor.session.setMode(new Mode())
  editor.setTheme('ace/theme/chrome')
  editor.setValue(code, -1)
  editor.setOptions({ maxLines: 40, readOnly: true, printMargin: false })

  const len = codeMain.dataset.additionalSourcesLength
  for (let i = 0; i < len; i++) {
    const tag = 'code_viewer_' + i
    const code = document.getElementById(tag).textContent
    /* eslint-disable-next-line */
    const editor = ace.edit(tag)
    editor.session.setMode(new Mode())
    editor.setTheme('ace/theme/chrome')
    editor.setValue(code, -1)
    editor.setOptions({ maxLines: 40, readOnly: true })
  }
}
