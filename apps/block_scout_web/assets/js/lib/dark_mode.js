import Cookies from 'js-cookie'

function isDarkMode () {
  // @ts-ignore
  const permanentDarkModeEnabled = document.getElementById('permanent-dark-mode').textContent === 'true'
  // @ts-ignore
  const permanentLightModeEnabled = document.getElementById('permanent-light-mode').textContent === 'true'
  if (permanentLightModeEnabled) {
    return false
  } else if (permanentDarkModeEnabled) {
    return true
  } else {
    return Cookies.get('chakra-ui-color-mode') === 'dark'
  }
}

export { isDarkMode }
