import ClipboardJS from 'clipboard'
import $ from 'jquery'

const clipboard = new ClipboardJS('[data-clipboard-text]')

clipboard.on('success', ({ trigger }) => {
  const copyButton = $(trigger)
  copyButton.tooltip('dispose')

  copyButton.tooltip({
    title: copyButton.data('token-hash') ? `${copyButton.data('token-address')} copied!` : 'Copied!',
    trigger: 'click',
    placement: 'top'
  }).tooltip('show')

  setTimeout(() => {
    copyButton.tooltip('dispose')
  }, 3000)
})
