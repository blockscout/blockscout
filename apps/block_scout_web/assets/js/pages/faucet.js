import $ from 'jquery'
import Swal from 'sweetalert2'

const $csrfToken = $('[name=_csrf_token]')
const $requestCoinsBtn = $('#requestCoins')

$(function () {
  $('#faucetForm').submit(function (e) {
    $requestCoinsBtn.attr('disabled', true)
    e.preventDefault()
    // eslint-disable-next-line
    const resp = hcaptcha.getResponse()
    if (resp) {
      $.ajax({
        url: './hcaptcha?type=JSON',
        type: 'POST',
        headers: {
          'x-csrf-token': $csrfToken.val()
        },
        data: {
          type: 'JSON',
          captchaResponse: resp
        }
      })
        .done(function (data) {
          const dataJson = JSON.parse(data)
          if (dataJson.success) {
            var receiver = $('#receiver').val()
            $.ajax({
              url: './faucet',
              type: 'POST',
              headers: {
                'x-csrf-token': $csrfToken.val()
              },
              data: {
                receiver: receiver
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
              Swal.fire({
                title: 'Error',
                text: err,
                icon: 'error'
              })
              $requestCoinsBtn.attr('disabled', false)
            })
          } else {
            // eslint-disable-next-line
            hcaptcha.reset()
            Swal.fire({
              title: 'Error',
              text: 'Incorrect response from hCaptcha. Try again later.',
              icon: 'error'
            })
            $requestCoinsBtn.attr('disabled', false)
          }
        })
        .fail(function (_jqXHR, _textStatus) {
          Swal.fire({
            title: 'Error',
            text: 'There is no hCaptcha response. Try again later.',
            icon: 'error'
          })
          $requestCoinsBtn.attr('disabled', false)
        })
    } else {
      $requestCoinsBtn.attr('disabled', false)
    }
  })
})
