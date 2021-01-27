import * as Pikaday from 'pikaday'
import moment from 'moment'
import $ from 'jquery'

const DATE_FORMAT = 'YYYY-MM-DD'

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

function onSelect (date, paramToReplace) {
  const formattedDate = moment(date).format(DATE_FORMAT)

  const $button = $('#export-csv-button')

  if (date) {
    var csvExportPath = $button.prop('href')

    var updatedCsvExportUrl = replaceUrlParam(csvExportPath, paramToReplace, formattedDate)
    $button.attr('href', updatedCsvExportUrl)
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
