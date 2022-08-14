import $ from 'jquery'

$('.dark-mode-changer').click(function () {
  if (localStorage.getItem('current-color-mode') === 'dark') {
    localStorage.setItem('current-color-mode', 'light')
  } else {
    localStorage.setItem('current-color-mode', 'dark')
  }
  // reload each theme switch
  document.location.reload(true)
})
