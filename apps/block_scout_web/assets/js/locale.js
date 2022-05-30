import moment from 'moment'
import numeral from 'numeral'
import 'numeral/locales'
import $ from 'jquery'

export const locale = 'en'

moment.locale(locale)
numeral.locale(locale)

$('.locale-datetime').each((_, element) => {
  const timestamp = parseInt($(element).attr('data-timestamp'))

  if (typeof timestamp === 'number' && !isNaN(timestamp)) {
    const date = new Date(timestamp * 1000)

    if (typeof date.toLocaleDateString === 'function') {
      $(element).html(date.toLocaleDateString())
    }
  }
})
