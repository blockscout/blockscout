import $ from 'jquery'
import customAds from './custom_ad'

function countImpressions (impressionUrl) {
  if (impressionUrl) {
    $.get(impressionUrl)
  }
}

function showAd () {
  const domainName = window.location.hostname
  if (domainName === 'blockscout.com') {
    $('.js-ad-dependant-mb-2').addClass('mb-2')
    $('.js-ad-dependant-mb-3').addClass('mb-3')
    $('.js-ad-dependant-pt').addClass('pt-4')
    $('.js-ad-dependant-pt').removeClass('pt-5')
    return true
  } else {
    $('.js-ad-dependant-mb-2').removeClass('mb-2')
    $('.js-ad-dependant-mb-3').removeClass('mb-3')
    $('.js-ad-dependant-pt').addClass('pt-5')
    $('.js-ad-dependant-pt').removeClass('pt-4')
    return false
  }
}

function getTextAdData () {
  return new Promise((resolve) => {
    if (showAd()) {
      $.get('https://request-global.czilladx.com/serve/native.php?z=50860d190820e5a2595', function (data) {
        if (!data) {
          if (customAds) {
            try {
              const ind = getRandomInt(0, customAds.length)
              const inHouse = true
              resolve({ data: customAds[ind], inHouse: inHouse })
            } catch (_e) {
              resolve({ data: null, inHouse: null })
            }
          } else {
            resolve({ data: null, inHouse: null })
          }
        } else {
          const inHouse = false
          resolve({ data: data, inHouse: inHouse })
        }
      })
    } else {
      resolve({ data: null, inHouse: null })
    }
  })
}

function fetchTextAdData () {
  if (showAd()) {
    getTextAdData()
      .then(({ data, inHouse }) => {
        if (data) {
          const prefix = inHouse ? 'Featured' : 'Sponsored'
          const { ad: { name, description_short: descriptionShort, thumbnail, url, cta_button: ctaButton, impressionUrl } } = data
          $('.ad-name').text(name)
          $('.ad-short-description').text(descriptionShort)
          $('.ad-cta-button').text(ctaButton)
          $('.ad-url').attr('href', url)
          $('.ad-prefix').text(prefix)
          $('.ad').css('visibility', 'visible')
          const urlObject = new URL(url)
          if (urlObject.hostname === 'nifty.ink') {
            $('.ad-img-url').replaceWith('🎨')
          } else {
            $('.ad-img-url').attr('src', thumbnail)
          }
          countImpressions(impressionUrl)
        }
      })
  }
}

function getRandomInt (min, max) {
  min = Math.ceil(min)
  max = Math.floor(max)
  return Math.floor(Math.random() * (max - min)) + min
}

export { showAd, getTextAdData, fetchTextAdData }
