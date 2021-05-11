import $ from 'jquery'

$(document).click(function (event) {
  const clickover = $(event.target)
  const _opened = $('.navbar-collapse').hasClass('show')
  if (_opened === true && $('.navbar').find(clickover).length < 1) {
    $('.navbar-toggler').click()
  }
})

$(document).on('keyup', function (event) {
  if (event.key === '/') {
    $('#q').trigger('focus')
  }
})

$('#q').on('focus', function (_event) {
  $('#slash-icon').hide()
  $(this).addClass('focused-field')
})

$('#q').on('focusout', function (_event) {
  $('#slash-icon').show()
  $(this).removeClass('focused-field')
})
