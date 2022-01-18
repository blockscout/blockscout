import $ from 'jquery'

$(document).click(function (event) {
  const clickover = $(event.target)
  const _opened = $('.navbar-collapse').hasClass('show')
  if (_opened === true && $('.navbar').find(clickover).length < 1) {
    $('.navbar-toggler').click()
  }
})

const search = (value) => {
  if (value) {
    window.location.href = `${process.env.NETWORK_PATH}/search?q=${value}`
  }
}

$(document).on('keyup', function (event) {
  if (event.key === '/') {
    $('.main-search-autocomplete').trigger('focus')
  }
})

$('.main-search-autocomplete').on('keyup', function (event) {
  if (event.key === 'Enter') {
    let selected = false
    $('li[id^="autoComplete_result_"]').each(function () {
      if ($(this).attr('aria-selected')) {
        selected = true
      }
    })
    if (!selected) {
      search(event.target.value)
    }
  }
})

$('#search-icon').on('click', function (event) {
  const value = $('.main-search-autocomplete').val() || $('.main-search-autocomplete-mobile').val()
  search(value)
})

$('.main-search-autocomplete').on('focus', function (_event) {
  $('#slash-icon').hide()
  $('.search-control').addClass('focused-field')
})

$('.main-search-autocomplete').on('focusout', function (_event) {
  $('#slash-icon').show()
  $('.search-control').removeClass('focused-field')
})
