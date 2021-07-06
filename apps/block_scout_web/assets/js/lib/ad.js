import $ from 'jquery'

export function getTextAdData () {
  $.get('https://request-global.czilladx.com/serve/native.php?z=50860d190820e5a2595', function (data) {
    if (data) {
      console.log(data)
      const { ad: { name, description_short: descriptionShort, thumbnail, url, cta_button: ctaButton, impressionUrl } } = data
      $('.ad').removeClass('d-none')
      $('.ad-name').text(name)
      $('.ad-short-description').text(descriptionShort)
      $('.ad-cta-button').text(ctaButton)
      $('.ad-url').attr('href', url)
      $('.ad-img-url').attr('src', thumbnail)
      $('.ad').data('impressionUrl', impressionUrl)
    } else {
      $('.ad').addClass('d-none')
    }
  })
}

$(function () {
  getTextAdData()

  $('.ad-url').on('click', function () {
    $.get($('.ad').data('impressionUrl'))
  })
})
