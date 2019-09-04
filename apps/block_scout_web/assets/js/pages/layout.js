import $ from 'jquery'

$(document).click(function (event) {
  var clickover = $(event.target)
  var _opened = $('.navbar-collapse').hasClass('show')
  if (_opened === true && $('.navbar').find(clickover).length < 1) {
    $('.navbar-toggler').click()
  }
})
$(document).ready(function () {
  if (matchMedia) {
    var mq = window.matchMedia('(max-width: 900px)')
    mq.addListener(WidthChange)
    WidthChange(mq)
  }

  function WidthChange (mq) {
    if (mq.matches) {
      $('#checkIfSmall').removeClass('dropdown-menu')
      $('.dropdown-item').removeClass('active')
      $('#checkIfSmall1').removeClass('dropdown-menu')
      $('#checkIfSmall2').removeClass('dropdown-menu')
    } else {
      $('#checkIfSmall').addClass('dropdown-menu')
      $('#checkIfSmall1').addClass('dropdown-menu')
      $('#checkIfSmall2').addClass('dropdown-menu')
    }
  }
})

var div1 = document.getElementById('toggleImage1')
var div2 = document.getElementById('toggleImage2')

function switchVisible () {
  if (!div1) return
  if (getComputedStyle(div1).display === 'inline-block') {
    div1.style.display = 'none'
    div2.style.display = 'block'
  } else {
    div1.style.display = 'inline-block'
    div2.style.display = 'none'
  }
}
document
  .getElementById('toggleButton')
  .addEventListener('click', switchVisible)
