import * as Pikaday from 'pikaday'
import moment from 'moment'
import $ from 'jquery'
import Cookies from 'js-cookie'
import Swal from 'sweetalert2'
import { getThemeMode } from './dark_mode'

const DATE_FORMAT = 'YYYY-MM-DD'

const $button = $('#export-csv-button')

// eslint-disable-next-line
const _instance1 = generateDatePicker('.js-datepicker-from', moment().add(-1, 'months').toDate())
// eslint-disable-next-line
const _instance2 = generateDatePicker('.js-datepicker-to', new Date())

function generateDatePicker (classSelector, defaultDate) {
  return new Pikaday({
    field: $(classSelector)[0],
    defaultDate,
    setDefaultDate: true,
    maxDate: new Date(),
    format: DATE_FORMAT
  })
}

$button.on('click', () => {
  // @ts-ignore
   
  const reCaptchaV2ClientKey = document.getElementById('js-re-captcha-client-key').value
  // @ts-ignore
   
  const reCaptchaV3ClientKey = document.getElementById('js-re-captcha-v3-client-key').value
  // @ts-ignore
   
  const reCaptchaDisabledRaw = document.getElementById('js-re-captcha-disabled').value
  const reCaptchaDisabled = reCaptchaDisabledRaw && reCaptchaDisabledRaw.toLowerCase() === 'true'
  const addressHash = $button.data('address-hash')
  const from = $('.js-datepicker-from').val()
  const to = $('.js-datepicker-to').val()
  const urlParams = new URLSearchParams(window.location.search)
  const filterType = urlParams.get('filter_type')
  const filterValue = urlParams.get('filter_value')
  const baseURL = `${$button.data('link')}?address_id=${addressHash}&from_period=${from}&to_period=${to}&filter_type=${filterType}&filter_value=${filterValue}`
  if (reCaptchaDisabled) {
    download(baseURL)
  } else if (reCaptchaV3ClientKey) {
    disableBtnWithSpinner()
    // @ts-ignore
    // eslint-disable-next-line
    grecaptcha.ready(function () {
      // @ts-ignore
      // eslint-disable-next-line
      grecaptcha.execute(reCaptchaV3ClientKey, { action: 'login' })
        .then(function (token) {
          const url = `${baseURL}&recaptcha_v3_response=${token}`

          download(url)
        })
    })
  } else if (reCaptchaV2ClientKey) {
  // @ts-ignore
  // eslint-disable-next-line
  const recaptchaResponse = grecaptcha.getResponse()
    if (recaptchaResponse) {
      disableBtnWithSpinner()
      const url = `${baseURL}&recaptcha_response=${recaptchaResponse}`

      download(url, true, true)
    }
  } else {
    alertWhenRecaptchaNotConfigured()
  }

  function download (url, resetRecaptcha, disable) {
    fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json; charset=utf-8'
      }
    })
      .then(response => {
        if (response.status === 200) {
          return response.blob()
        }
      })
      .then(response => {
        if (response) {
          const blob = new Blob([response], { type: 'application/csv' })
          const downloadUrl = URL.createObjectURL(blob)
          const a = document.createElement('a')
          a.href = downloadUrl
          let fileName = `${$button.data('type')}_for_${addressHash}_from_${from}_to_${to}`
          if (filterType && filterValue) {
            fileName = `${fileName}_with_filter_type_${filterType}_value_${filterValue}.csv`
          } else {
            fileName = `${fileName}.csv`
          }
          a.download = fileName
          document.body.appendChild(a)
          a.click()

          resetBtn(resetRecaptcha, disable)
        } else {
          alertWhenRequestFailed()
          resetBtn(resetRecaptcha, disable)
        }
      })
  }

  function resetBtn (resetRecaptcha, disable) {
    $button.removeClass('spinner')
    if (!disable) {
      $button.prop('disabled', false)
    }
    Cookies.remove('csv-downloaded')
    if (resetRecaptcha) {
      // @ts-ignore
      // eslint-disable-next-line
      grecaptcha.reset()
    }
  }

  function disableBtnWithSpinner () {
    $button.addClass('spinner')
    disableBtn()
  }

  function disableBtn () {
    $button.prop('disabled', true)
  }
})

const onloadCallback = function () {
  // @ts-ignore
   
  const reCaptchaClientKey = document.getElementById('js-re-captcha-client-key').value
  // @ts-ignore
  // eslint-disable-next-line
  grecaptcha.render('recaptcha', {
    sitekey: reCaptchaClientKey,
    theme: getThemeMode(),
    callback: function () {
      // @ts-ignore
      document.getElementById('export-csv-button').disabled = false
    }
  })
}

function alertWhenRecaptchaNotConfigured () {
  Swal.fire({
    title: 'Warning',
    html: 'CSV download is disabled since reCAPTCHA is not configured on server side. Please advise server maintainer to configure RE_CAPTCHA_CLIENT_KEY and RE_CAPTCHA_SECRET_KEY environment variables in case of reCAPTCHAv2 or RE_CAPTCHA_V3_CLIENT_KEY and RE_CAPTCHA_V3_SECRET_KEY environment variables in case of reCAPTCHAv3.',
    icon: 'warning'
  })
}

function alertWhenRequestFailed () {
  Swal.fire({
    title: 'Warning',
    html: 'Request failed, please try again later or decrease time range for exporting data.',
    icon: 'warning'
  })
}

// @ts-ignore
window.onloadCallback = onloadCallback
