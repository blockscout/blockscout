import Cookies from 'js-cookie'

function isDarkMode () {
  const permanentDarkModeEnabled = isPermanentDarkModeEnabled()
  const permanentLightModeEnabled = isPermanentLightModeEnabled()
  if (permanentLightModeEnabled) {
    return false
  } else if (permanentDarkModeEnabled) {
    return true
  } else {
    return Cookies.get('chakra-ui-color-mode') === 'dark'
  }
}

function getThemeMode () {
  const permanentDarkModeEnabled = isPermanentDarkModeEnabled()
  const permanentLightModeEnabled = isPermanentLightModeEnabled()
  if (permanentLightModeEnabled) {
    return 'light'
  } else if (permanentDarkModeEnabled) {
    return 'dark'
  } else {
    return Cookies.get('chakra-ui-color-mode')
  }
}

function isPermanentDarkModeEnabled () {
  // @ts-ignore
  return document.getElementById('permanent-dark-mode').textContent === 'true'
}

function isPermanentLightModeEnabled () {
  // @ts-ignore
  return document.getElementById('permanent-light-mode').textContent === 'true'
}

export { isDarkMode, getThemeMode }
