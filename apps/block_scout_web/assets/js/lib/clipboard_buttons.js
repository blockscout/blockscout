import ClipboardJS from 'clipboard'
import $ from 'jquery'

const clipboard = new ClipboardJS('[data-clipboard-text]')

clipboard.on('success', ({ trigger }) => {
  const copyButton = $(trigger)
  copyButton.tooltip('dispose')

  copyButton.tooltip({
    title: 'Copied!',
    trigger: 'click',
    placement: 'top'
  }).tooltip('show')

  setTimeout(() => {
    copyButton.tooltip('dispose')
  }, 1000)
})
