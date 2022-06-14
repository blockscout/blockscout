import $ from 'jquery'

$(function () {
  $('body').tooltip({ selector: '[data-toggle="tooltip"]' })

  $('.tooltip-with-link-container').tooltip({
    selector: '[data-toggle="tooltip-with-link"]',
    html: true,
    delay: {
      show: 0,
      hide: 3000 // to allow user to be able to click the link before tooltip disappears
    }
  })

  $('[data-toggle="tooltip-with-link"]').on('show.bs.tooltip', () => {
    $('[data-toggle="tooltip-with-link"]').each((_, element) => {
      // becauase of the options.delay.hide we don't want to keep previous tooltips shown
      $(element).tooltip('hide')
    })
  })
})
