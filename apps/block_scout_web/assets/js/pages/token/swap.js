import $ from 'jquery'
import 'bootstrap'

$(document.body)
  .on('mouseover', '.btn-swap.honeypot', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol} to WXDAI`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
  .on('mouseover', '.btn-swap.sushi', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol}`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })

