import $ from 'jquery'

$('.stats-link').on('click', function () {
  $('ul#topnav .selected').removeClass('selected')
  $(this).addClass('selected')
})

$(window).on('load resize', function () {
  var width = $(window).width()
  if (width < 768) {
    $('.js-ad-dependant-pt').removeClass('pt-5')
    $('.menu-wrap').removeClass('container')
  } else {
    $('.js-ad-dependant-pt').addClass('pt-5')
    $('.menu-wrap').addClass('container')
  }
})
