import $ from 'jquery'

if (localStorage.getItem('main-page-alert-read') === 'true') {
  $('.js-warning-alert').hide()
} else {
  $('.js-warning-alert').show()
}

$('.js-address-warning-alert').each((i, el) => {
  if (localStorage.getItem(`address-${$(el).data('address')}-alert-read`) === 'true') {
    $(el).hide()
  } else {
    $(el).show()
  }
})

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
    localStorage.setItem('main-page-alert-read', 'true')
  })
  .on('click', '.js-address-btn-close-warning', event => {
    console.log($(event.target).closest('.card'))
    const targetAddress = $(event.target).closest('.card').data('address')
    console.log(targetAddress)
    $(event.target).closest('.card').hide()
    localStorage.setItem(`address-${targetAddress}-alert-read`, 'true')
  })
  .on('click', '.js-stakes-btn-close-warning', event => {
    $(event.target).closest('.card').hide()
    localStorage.setItem('stakes-warning-read', 'true')
  })
  .on('click', '.js-stakes-btn-close-welcome-alert', event => {
    $(event.target).closest('.card').hide()
    localStorage.setItem('stakes-alert-read', 'true')
  })
