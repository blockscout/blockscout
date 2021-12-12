import $ from 'jquery'

if (localStorage.getItem('stakes-alert-read') === 'true') {
  $('.js-stakes-welcome-alert').hide()
} else {
  $('.js-stakes-welcome-alert').show()
}

if (localStorage.getItem('stakes-warning-read') === 'true') {
  $('.js-stakes-warning-alert').hide()
} else {
  $('.js-stakes-warning-alert').show()
}

$(document.body)
  .on('click', '.js-btn-close-warning', event => {
    $(event.target).closest('.card').hide()
  })
  .on('click', '.js-stakes-btn-close-warning', event => {
    $(event.target).closest('.card').hide()
    localStorage.setItem('stakes-warning-read', 'true')
  })
  .on('click', '.js-stakes-btn-close-welcome-alert', event => {
    $(event.target).closest('.card').hide()
    localStorage.setItem('stakes-alert-read', 'true')
  })
