import ClipboardJS from 'clipboard'
import $ from 'jquery'

const clipboard = new ClipboardJS('[data-clipboard-text]')

clipboard.on('success', ({ trigger }) => {
  const copyButton = $(trigger)
  copyButton.tooltip('dispose')
  copyButton.children().tooltip('dispose')

  const originalTitle = copyButton.attr('data-original-title')

  copyButton
    .attr('data-original-title', copyButton.data('token-hash') ? `${copyButton.data('token-address')} copied!` : 'Copied!')
    .tooltip('show')

  if (originalTitle) {
    copyButton.attr('data-original-title', originalTitle)
  }

  setTimeout(() => {
    copyButton.tooltip('dispose')
  }, 3000)
})
