import $ from 'jquery'

$('.stats-link').on('click', function () {
  $('ul#topnav .selected').removeClass('selected')
  $(this).addClass('selected')
})

$(window).on('load resize', function () {
  const width = $(window).width()
  if (width < 768) {
    $('.pt').removeClass('pt-5')
    $('.menu-wrap').removeClass('container')
  } else {
    $('.pt').addClass('pt-5')
    $('.menu-wrap').addClass('container')
  }
})
