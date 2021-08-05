import $ from 'jquery'
import 'bootstrap'

$(document.body)
  .on('mouseover', '.tenderly-icon', event => {
    const $btn = $(event.target)

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Open in Tenderly`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })
