import $ from 'jquery'

$(function () {
  if (showAd()) {
    fetchTextAdData()
  }
})

function countImpressions (impressionUrl) {
  $.get(impressionUrl)
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
      $.get('https://request-global.czilladx.com/serve/native.php?z=19260bf627546ab7242', function (data) {
        resolve(data)
      })
    } else {
      resolve(null)
    }
  })
}

function fetchTextAdData () {
  if (showAd()) {
    getTextAdData()
      .then(data => {
        if (data) {
          const { ad: { name, description_short: descriptionShort, thumbnail, url, cta_button: ctaButton, impressionUrl } } = data
          $('.ad').removeClass('d-none')
          $('.ad-name').text(name)
          $('.ad-short-description').text(descriptionShort)
          $('.ad-cta-button').text(ctaButton)
          $('.ad-url').attr('href', url)
          $('.ad-img-url').attr('src', thumbnail)
          countImpressions(impressionUrl)
        } else {
          $('.ad').addClass('d-none')
        }
      })
  }
}

export { showAd, getTextAdData, fetchTextAdData }
