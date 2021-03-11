import $ from 'jquery'
import 'bootstrap'

$(document.body)
  .on('mouseover', '.btn-swap', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol} to WXDAI`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
