import $ from 'jquery'
import Swal from 'sweetalert2'
import * as Sentry from '@sentry/browser'

const $csrfToken = $('[name=_csrf_token]')
const $requestCoinsBtn = $('#requestCoins')

$(function () {
  $('#faucetForm').submit(function (e) {
    $requestCoinsBtn.attr('disabled', true)
    e.preventDefault()
    // eslint-disable-next-line
    const resp = hcaptcha.getResponse()
    if (resp) {
      var receiver = $('#receiver').val()
      $.ajax({
        url: './faucet',
        type: 'POST',
        headers: {
          'x-csrf-token': $csrfToken.val()
        },
        data: {
          receiver: receiver,
          captchaResponse: resp
        }
      }).done(function (data) {
        // eslint-disable-next-line
        hcaptcha.reset()
        if (!data.success) {
          Swal.fire({
            title: 'Error',
            text: data.message,
            icon: 'error'
          })
          Sentry.captureException(data)
        } else {
          $('#receiver').val('')
          const faucetValue = $('#faucetValue').val()
          const faucetCoin = $('#faucetCoin').val()
          Swal.fire({
            title: 'Success',
            html: `${faucetValue} ${faucetCoin} have been successfully transferred to <a href="./tx/${data.transactionHash}" target="blank">${receiver}</a>`,
            icon: 'success'
          })
        }
        $requestCoinsBtn.attr('disabled', false)
      }).fail(function (err) {
        // eslint-disable-next-line
        hcaptcha.reset()
        console.error(err)
        Swal.fire({
          title: 'Error',
          text: 'Sending coins failed. Please try again later.',
          icon: 'error'
        })
        $requestCoinsBtn.attr('disabled', false)
        Sentry.captureException(err)
      })
    } else {
      $requestCoinsBtn.attr('disabled', false)
    }
  })
})
