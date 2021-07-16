import $ from 'jquery'

function countImpressions (impressionUrl) {
  $.get(impressionUrl)
}

$(function () {
  fetchTextAdData()
})

function getTextAdData () {
  return new Promise((resolve) => {
    $.get('https://request-global.czilladx.com/serve/native.php?z=19260bf627546ab7242', function (data) {
      resolve(data)
    })
  })
}

function fetchTextAdData () {
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

export { getTextAdData, fetchTextAdData }
