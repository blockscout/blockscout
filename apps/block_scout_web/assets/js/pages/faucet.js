import $ from 'jquery'
import Swal from 'sweetalert2'
import { walletEnabled, connectToWallet, shouldHideConnectButton } from '../lib/smart_contract/write.js'
import { getCurrentAccount, compareChainIDs, formatError } from '../lib/smart_contract/common_helpers'
import { uuidv4 } from '../lib/keys_helpers'
import { getCookie, setCookie } from '../lib/cookies_helpers'
import { utils } from 'web3'

const $csrfToken = $('[name=_csrf_token]')
const $sendSMSBtn = $('#sendSMS')
const $requestCoinsBtn = $('#requestCoins')
const $donateBtn = $('#donate')

const $receiverInput = $('#receiver')
const $phoneNumberInput = $('#phoneNumber')
const $verificationCodeInput = $('#verificationCode')

const $connect = $('[connect-metamask]')
const $connectTo = $('[connect-to]')
const $connectedTo = $('[connected-to]')
const $reconnect = $('[re-connect-metamask]')

const faucetAddress = $('#faucetAddress').val()

getFaucetBalance()

var deviceKey = getCookie('faucet-device-key')
const sessionKey = uuidv4()
setCookie('faucet-session-key', sessionKey)
if (!deviceKey) {
  deviceKey = uuidv4()
  setCookie('faucet-device-key', deviceKey)
}

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

$connect.on('click', connectToWallet)
$reconnect.on('click', connectToWallet)

$receiverInput.on('keyup', validateInput)
$phoneNumberInput.on('keyup', validateInput)
$verificationCodeInput.on('keyup', validateInput)

$sendSMSBtn.on('click', onSMSButtonClick)

async function getFaucetBalance () {
  const balance = await window.ethereum.request({
    method: 'eth_getBalance',
    params: [faucetAddress, 'latest']
  })
  const faucetBalance = (parseInt(balance, 16) / Math.pow(10, 18)).toString()
  $('#faucetBalance').text(faucetBalance)
}

function validateInput (event) {
  const btn = $(event.target)
  if (!btn.val()) {
    btn.addClass('invalid')
  } else {
    btn.removeClass('invalid')
  }
}

function onSMSButtonClick (event) {
  var receiver = $receiverInput.val()
  if (!receiver) {
    $receiverInput.addClass('invalid')
    return
  }
  var phoneNumber = $phoneNumberInput.val()
  if (!phoneNumber) {
    $phoneNumberInput.addClass('invalid')
    return
  }
  const saltedSessionKey = deviceKey.concat(sessionKey)
  const sessionKeyHash = utils.keccak256(saltedSessionKey)

  // eslint-disable-next-line
  const captchaResp = hcaptcha.getResponse()
  if (!captchaResp) return

  const $btn = $(event.target)

  $btn.attr('disabled', true)

  if (receiver && phoneNumber && captchaResp) {
    $.ajax({
      url: './faucet',
      type: 'POST',
      headers: {
        'x-csrf-token': $csrfToken.val()
      },
      data: {
        receiver: receiver,
        phoneNumber: phoneNumber,
        sessionKeyHash: sessionKeyHash,
        captchaResponse: captchaResp
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
        $receiverInput.hide()
        $phoneNumberInput.hide()
        $verificationCodeInput.removeClass('d-none')

        $btn.hide()
        $requestCoinsBtn.removeClass('d-none')
      }
      $btn.attr('disabled', false)
    }).fail(function (err) {
      // eslint-disable-next-line
      hcaptcha.reset()
      console.error(err)
      Swal.fire({
        title: 'Error',
        text: 'Sending SMS for verification failed. Please try again later.',
        icon: 'error'
      })
      $btn.attr('disabled', false)
    })
  }
}

$('#faucetForm').submit(function (event) {
  event.preventDefault()
  var receiver = $receiverInput.val()
  if (!receiver) {
    $receiverInput.addClass('invalid')
    return
  }
  var phoneNumber = $phoneNumberInput.val()
  if (!phoneNumber) {
    $phoneNumberInput.addClass('invalid')
    return
  }
  var verificationCode = $verificationCodeInput.val()
  if (!verificationCode) {
    $verificationCodeInput.addClass('invalid')
    return
  }

  const saltedSessionKey = deviceKey.concat(sessionKey)
  const sessionKeyHash = utils.keccak256(saltedSessionKey)

  const verificationCodeHash = utils.keccak256(verificationCode)

  // eslint-disable-next-line
  const captchaResp = hcaptcha.getResponse()
  if (!captchaResp) return

  const $btn = $(event.target)

  $btn.attr('disabled', true)

  if (receiver && phoneNumber && verificationCode && captchaResp) {
    $.ajax({
      url: './faucet',
      type: 'POST',
      headers: {
        'x-csrf-token': $csrfToken.val()
      },
      data: {
        receiver: receiver,
        phoneNumber: phoneNumber,
        sessionKeyHash: sessionKeyHash,
        verificationCodeHash: verificationCodeHash,
        captchaResponse: captchaResp
      }
    }).done(function (data) {
      // eslint-disable-next-line
      hcaptcha.reset()
      if (!data.success) {
        $verificationCodeInput.val('')
        Swal.fire({
          title: 'Error',
          text: data.message,
          icon: 'error'
        })
      } else {
        $receiverInput.val('')
        $phoneNumberInput.val('')
        $verificationCodeInput.val('')
        const faucetValue = $('#faucetValue').val()
        const faucetCoin = $('#faucetCoin').val()
        Swal.fire({
          title: 'Success',
          html: `${faucetValue} ${faucetCoin} have been successfully transferred to <a href="./tx/${data.transactionHash}" target="blank">${receiver}</a>`,
          icon: 'success'
        })
          .then(() => {
            window.location.reload()
          })
      }
      $btn.attr('disabled', false)
    }).fail(function (err) {
      // eslint-disable-next-line
      hcaptcha.reset()
      console.error(err)
      Swal.fire({
        title: 'Error',
        text: 'Sending coins failed. Please try again later.',
        icon: 'error'
      })
      $btn.attr('disabled', false)
    })
  } else {
    $btn.attr('disabled', false)
  }
})

$donateBtn.on('click', donateCoins)

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

async function donateCoins (event) {
  const btn = $(event.target)
  await walletEnabled()
  const { chainId: walletChainIdHex } = window.ethereum
  compareChainIDs(btn.data('chainId'), walletChainIdHex)
    .then(async () => {
      const currentAccount = await getCurrentAccount()
      const faucetDonateValue = $('#faucetDonateValue').val() || '100'
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
    })
    .catch((error) => {
      Swal.fire({
        title: 'Warning',
        html: formatError(error),
        icon: 'warning'
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
