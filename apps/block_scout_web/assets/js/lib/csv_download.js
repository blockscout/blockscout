import * as Pikaday from 'pikaday'
import moment from 'moment'
import $ from 'jquery'
import Cookies from 'js-cookie'

const DATE_FORMAT = 'YYYY-MM-DD'

const $button = $('#export-csv-button')

// eslint-disable-next-line
const _instance1 = new Pikaday({
  field: $('.js-datepicker-from')[0],
  onSelect: (date) => onSelect(date, 'from_period'),
  defaultDate: moment().add(-1, 'months').toDate(),
  setDefaultDate: true,
  maxDate: new Date(),
  format: DATE_FORMAT
})

// eslint-disable-next-line
const _instance2 = new Pikaday({
  field: $('.js-datepicker-to')[0],
  onSelect: (date) => onSelect(date, 'to_period'),
  defaultDate: new Date(),
  setDefaultDate: true,
  maxDate: new Date(),
  format: DATE_FORMAT
})

$button.on('click', () => {
  // eslint-disable-next-line
  const recaptchaResponse = grecaptcha.getResponse()
  if (recaptchaResponse) {
    $button.addClass('spinner')
    $button.prop('disabled', true)
    const downloadUrl = `${$button.data('link')}&recaptcha_response=${recaptchaResponse}`

    $('body').append($('<iframe id="csv-iframe" style="display: none;"></iframe>'))
    $('#csv-iframe').attr('src', downloadUrl)

    const interval = setInterval(handleCSVDownloaded, 1000)
    setTimeout(resetDownload, 60000)

    function handleCSVDownloaded () {
      if (Cookies.get('csv-downloaded') === 'true') {
        resetDownload()
      }
    }

    function resetDownload () {
      $button.removeClass('spinner')
      $button.prop('disabled', false)
      clearInterval(interval)
      Cookies.remove('csv-downloaded')
      // eslint-disable-next-line
      grecaptcha.reset()
    }
  }
})

function onSelect (date, paramToReplace) {
  const formattedDate = moment(date).format(DATE_FORMAT)

  if (date) {
    const csvExportPath = $button.data('link')

    const updatedCsvExportUrl = replaceUrlParam(csvExportPath, paramToReplace, formattedDate)
    $button.data('link', updatedCsvExportUrl)
  }
}

function replaceUrlParam (url, paramName, paramValue) {
  if (paramValue == null) {
    paramValue = ''
  }
  const pattern = new RegExp('\\b(' + paramName + '=).*?(&|#|$)')
  if (url.search(pattern) >= 0) {
    return url.replace(pattern, '$1' + paramValue + '$2')
  }
  url = url.replace(/[?#]$/, '')
  return url + (url.indexOf('?') > 0 ? '&' : '?') + paramName + '=' + paramValue
}
