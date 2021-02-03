import $ from 'jquery'
import Swal from 'sweetalert2'

$(function () {
  var loader = $('.loading-container')
  $('#faucetForm').submit(function (e) {
    e.preventDefault()
    loader.removeClass('hidden')
    var receiver = $('#receiver').val()
    $.ajax({
      url: './faucet',
      type: 'POST',
      headers: {
        'x-csrf-token': $('[name=_csrf_token]').val()
      },
      data: {
        receiver: receiver
      }
    }).done(function (data) {
      if (!data.success) {
        loader.addClass('hidden')
        console.log(data)
        console.log(data.message)
        Swal.fire({
          title: 'Error',
          text: data.message,
          icon: 'error'
        })
        return
      }

      $('#receiver').val('')
      loader.addClass('hidden')
      Swal.fire({
        title: 'Success',
        html: `${process.env.FAUCET_VALUE} ${process.env.COIN} have been successfully transferred to <a href="./tx/${data.transactionHash}" target="blank">${receiver}</a>`,
        icon: 'success'
      })
    }).fail(function (err) {
      console.log(err)
      loader.addClass('hidden')
    })
  })
})
