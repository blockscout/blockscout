import * as Pikaday from 'pikaday'
import moment from 'moment'
import $ from 'jquery'

const DATE_FORMAT = 'YYYY-MM-DD'

const $button = $('#export-csv-button')

// eslint-disable-next-line
const _instance1 = new Pikaday({
  field: $('.js-datepicker-from')[0],
  onSelect: (date) => onSelect(date, 'from_period'),
  defaultDate: moment().add(-3, 'months').toDate(),
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
  $button.addClass('spinner')
  // eslint-disable-next-line
  const resp = grecaptcha.getResponse()
  if (resp) {
    $.ajax({
      url: './captcha?type=JSON',
      type: 'POST',
      headers: {
        'x-csrf-token': $('[name=_csrf_token]').val()
      },
      data: {
        type: 'JSON',
        captchaResponse: resp
      }
    })
      .done(function (data) {
        const dataJson = JSON.parse(data)
        if (dataJson.success) {
          $button.removeClass('spinner')
          location.href = $button.data('link')
        } else {
          $button.removeClass('spinner')
          return false
        }
      })
      .fail(function (_jqXHR, textStatus) {
        $button.removeClass('spinner')
      })
  } else {
    $button.removeClass('spinner')
  }
})

function onSelect (date, paramToReplace) {
  const formattedDate = moment(date).format(DATE_FORMAT)

  if (date) {
    var csvExportPath = $button.data('link')

    var updatedCsvExportUrl = replaceUrlParam(csvExportPath, paramToReplace, formattedDate)
    $button.data('link', updatedCsvExportUrl)
  }
}

function replaceUrlParam (url, paramName, paramValue) {
  if (paramValue == null) {
    paramValue = ''
  }
  var pattern = new RegExp('\\b(' + paramName + '=).*?(&|#|$)')
  if (url.search(pattern) >= 0) {
    return url.replace(pattern, '$1' + paramValue + '$2')
  }
  url = url.replace(/[?#]$/, '')
  return url + (url.indexOf('?') > 0 ? '&' : '?') + paramName + '=' + paramValue
}
