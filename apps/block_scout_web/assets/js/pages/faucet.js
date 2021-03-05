import $ from 'jquery'
import Swal from 'sweetalert2'
import { walletEnabled, connectToWallet, getCurrentAccount, shouldHideConnectButton } from '../lib/smart_contract/write.js'

const $csrfToken = $('[name=_csrf_token]')
const $requestCoinsBtn = $('#requestCoins')
const $donateBtn = $('#donate')

const $connect = $('[connect-metamask]')
const $connectTo = $('[connect-to]')
const $connectedTo = $('[connected-to]')
const $reconnect = $('[re-connect-metamask]')

const faucetAddress = $('#faucetAddress').val()

getFaucetBalance()

window.ethereum && window.ethereum.on('accountsChanged', function (accounts) {
  if (accounts.length === 0) {
    showConnectElements($connect, $connectTo, $connectedTo)
  } else {
    showConnectedToElements($connect, $connectTo, $connectedTo, accounts[0])
  }
})

shouldHideConnectButton()
  .then(({ shouldHide, account }) => {
    if (shouldHide && account) {
      showConnectedToElements($connect, $connectTo, $connectedTo, account)
    } else if (shouldHide) {
      hideConnectButton($connect, $connectTo, $connectedTo)
    } else {
      showConnectElements($connect, $connectTo, $connectedTo)
    }
  })

$connect.on('click', () => {
  connectToWallet()
})

$reconnect.on('click', () => {
  connectToWallet()
})

async function getFaucetBalance () {
  const balance = await window.ethereum.request({
    method: 'eth_getBalance',
    params: [faucetAddress, 'latest']
  })
  const faucetBalance = (parseInt(Number(balance, 10)) / Math.pow(10, 18)).toString()
  $('#faucetBalance').text(faucetBalance)
}

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
    })
  } else {
    $requestCoinsBtn.attr('disabled', false)
  }
})

$donateBtn.on('click', function (e) {
  donateCoins()
})

function showConnectedToElements ($connect, $connectTo, $connectedTo, account) {
  $connectTo.addClass('hidden')
  $connect.removeClass('hidden')
  $connectedTo.removeClass('hidden')
  setConnectToAddress(account)
}

function setConnectToAddress (account) {
  const $connectedToAddress = $('[connected-to-address]')
  $connectedToAddress.html(`<a href='/address/${account}'>${account}</a>`)
}

function showConnectElements ($connect, $connectTo, $connectedTo) {
  $connectTo.removeClass('hidden')
  $connect.removeClass('hidden')
  $connectedTo.addClass('hidden')
}

function hideConnectButton ($connect, $connectTo, $connectedTo) {
  $connectTo.removeClass('hidden')
  $connect.addClass('hidden')
  $connectedTo.addClass('hidden')
}

async function donateCoins () {
  await walletEnabled()
  const currentAccount = await getCurrentAccount()
  const faucetDonateValue = $('#faucetDonateValue').val() || "100"
  const txParams = {
    from: currentAccount,
    to: faucetAddress,
    value: (parseFloat(faucetDonateValue) * Math.pow(10, 18)).toString(16)
  }
  window.ethereum.request({
    method: 'eth_sendTransaction',
    params: [txParams]
  })
    .then(function (txHash) {
      onTransactionHash(txHash)
    })
    .catch(function (error) {
      Swal.fire({
        title: 'Error in sending coins to faucet',
        text: formatError(error),
        icon: 'error'
      })
    })
}

function onTransactionHash (txHash) {
  const getTxReceipt = (txHash) => {
    window.ethereum.request({
      method: 'eth_getTransactionReceipt',
      params: [txHash]
    })
      .then(txReceipt => {
        if (txReceipt) {
          const successMsg = `Successfully <a href="/tx/${txHash}">sent coins</a> to faucet`
          Swal.fire({
            title: 'Success',
            html: successMsg,
            icon: 'success'
          })
          clearInterval(txReceiptPollingIntervalId)
        }
      })
  }
  const txReceiptPollingIntervalId = setInterval(() => { getTxReceipt(txHash) }, 5 * 1000)
}

const formatError = (error) => {
  let { message } = error
  message = message && message.split('Error: ').length > 1 ? message.split('Error: ')[1] : message
  return message
}
