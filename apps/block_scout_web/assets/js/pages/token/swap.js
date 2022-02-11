import $ from 'jquery'
import 'bootstrap'

$(document.body)
  .on('mouseover', '.btn-swap.honeypot', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol} to WXDAI through HoneySwap`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
  .on('mouseover', '.btn-swap.sushi', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol} to WXDAI through Sushi`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
  .on('mouseover', '.btn-swap.swapr', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol} to WXDAI through Swapr`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
  .on('mouseover', '.btn-swap.curve', event => {
    const $btn = $(event.target)

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: 'Swap token through Curve',
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
  .on('mouseover', '.btn-swap.component', event => {
    const $btn = $(event.target)

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: 'Swap token through Component',
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
  .on('mouseover', '.btn-swap.oneinch', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol} to WXDAI through 1inch`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
  .on('mouseover', '.btn-swap.cowswap', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Swap ${tokenSymbol} to WXDAI through CowSwap`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
