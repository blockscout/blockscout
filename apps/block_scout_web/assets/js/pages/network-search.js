import $ from 'jquery'

var networkSearchInput = $('.network-selector-search-input')
var networkSearchInputVal = ''

$(networkSearchInput).on('input', function () {
  networkSearchInputVal = $(this).val()

  $.expr[':'].Contains = $.expr.createPseudo(function (arg) {
    return function (elem) {
      return $(elem).text().toUpperCase().indexOf(arg.toUpperCase()) >= 0
    }
  })

  if (networkSearchInputVal === '') {
    $('.network-selector-item').show()
  } else {
    $('.network-selector-item').hide()
    $(".network-selector-item:Contains('" + networkSearchInputVal + "')").show()
  }
})
