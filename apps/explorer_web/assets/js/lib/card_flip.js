import $ from 'jquery'

$('.rotatecard').click(function () {
  $(this).parents('.front').toggleClass('flipped')
  $(this).parentsUntil('.theme__ribbon').next('.back').toggleClass('backflip')
})

$('.rotatecardback').click(function () {
  $(this).parentsUntil('.panel').prev('.front').toggleClass('flipped')
  $(this).parents('.back').toggleClass('backflip')
})
