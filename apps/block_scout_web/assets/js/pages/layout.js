import $ from 'jquery'

$(document).click(function (event) {
  var clickover = $(event.target)
  var _opened = $('.navbar-collapse').hasClass('show')
  if (_opened === true && $('.navbar').find(clickover).length < 1) {
    $('.navbar-toggler').click()
  }
})
