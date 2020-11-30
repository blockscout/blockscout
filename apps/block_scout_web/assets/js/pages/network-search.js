import $ from 'jquery'

const networkSearchInput = $('.network-selector-search-input')
let networkSearchInputVal = ''

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
