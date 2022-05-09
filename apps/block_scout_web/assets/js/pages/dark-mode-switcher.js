import $ from 'jquery'

$('.dark-mode-changer').click(function () {
  if (localStorage.getItem('next-color-mode') === 'dark') {
    localStorage.setItem('next-color-mode', 'light')
  } else {
    localStorage.setItem('next-color-mode', 'dark')
  }
  // reload each theme switch
  document.location.reload(true)
})
