import $ from 'jquery'

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

function getTextAdData (customAds) {
  return new Promise((resolve) => {
    if (showAd()) {
      $.get('https://request-global.czilladx.com/serve/native.php?z=19260bf627546ab7242', function (data) {
        if (!data) {
          if (customAds) {
            try {
              data = JSON.parse(customAds)
              const ind = getRandomInt(0, data.length)
              resolve(data[ind])
            } catch (_e) {
              resolve(null)
            }
          } else {
            resolve(null)
          }
        } else {
          resolve(data)
        }
      })
    } else {
      resolve(null)
    }
  })
}

function fetchTextAdData (customAds) {
  if (showAd()) {
    getTextAdData(customAds)
      .then(data => {
        if (data) {
          const { ad: { name, description_short: descriptionShort, thumbnail, url, cta_button: ctaButton, impressionUrl } } = data
          $('.ad-name').text(name)
          $('.ad-short-description').text(descriptionShort)
          $('.ad-cta-button').text(ctaButton)
          $('.ad-url').attr('href', url)
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
