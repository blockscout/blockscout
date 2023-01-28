import Cookies from 'js-cookie'
const permantDarkModeEl = document.getElementById('permanent-dark-mode')
// @ts-ignore
const permanentDarkModeEnabled = false || (permantDarkModeEl && permantDarkModeEl.textContent === 'true')
// @ts-ignore
const darkModeChangerEl = document.getElementsByClassName('dark-mode-changer')[0]

if (permanentDarkModeEnabled) {
  // @ts-ignore
  darkModeChangerEl.style.display = 'none'
}

darkModeChangerEl && darkModeChangerEl.addEventListener('click', function () {
  if (!permanentDarkModeEnabled) {
    if (Cookies.get('chakra-ui-color-mode') === 'dark') {
      Cookies.set('chakra-ui-color-mode', 'light')
    } else {
      Cookies.set('chakra-ui-color-mode', 'dark')
    }
    document.location.reload()
  }
})
