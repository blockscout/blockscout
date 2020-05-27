import $ from 'jquery'
import {
  currentModal,
  lockModal,
  openErrorModal,
  openModal,
  openSuccessModal,
  openWarningModal,
  unlockModal
} from '../../lib/modals'
import { displayInputError, hideInputError } from '../../lib/validation'
import { isSupportedNetwork } from './utils'

let status = 'modalClosed'

export function openClaimRewardModal (event, store) {
  const state = store.getState()

  if (!state.account) {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }

  if (!isSupportedNetwork(store)) {
    return
  }

  const channel = state.channel

  $(event.currentTarget).prop('disabled', true)
  channel.push('render_claim_reward', { preload: true }).receive('ok', msg => {
    $(event.currentTarget).prop('disabled', false)

    const $modal = $(msg.html)
    const $closeButton = $modal.find('.close-modal')
    const $modalBody = $('.modal-body', $modal)

    const dotCounterInterval = poolsSearchingStarted()

    const ref = channel.on('claim_reward_pools', msgPools => {
      $modalBody.html(msgPools.html)
      poolsSearchingFinished()
    })
    $modal.on('shown.bs.modal', () => {
      status = 'modalOpened'
      channel.push('render_claim_reward', {
      }).receive('error', (error) => {
        poolsSearchingFinished(error.reason)
      }).receive('timeout', () => {
        poolsSearchingFinished('Connection timeout')
      })
    })
    $modal.on('hidden.bs.modal', () => {
      status = 'modalClosed'
      $modal.remove()
    })
    function poolsSearchingStarted () {
      const $waitingMessageContainer = $modalBody.find('p')
      let dotCounter = 0

      return setInterval(() => {
        let waitingMessage = $.trim($waitingMessageContainer.text())
        if (!waitingMessage.endsWith('.')) {
          waitingMessage = waitingMessage + '.'
        }
        waitingMessage = waitingMessage.replace(/\.+$/g, ' ' + '.'.repeat(dotCounter))
        $waitingMessageContainer.text(waitingMessage)
        dotCounter = (dotCounter + 1) % 4
      }, 500)
    }
    function poolsSearchingFinished (error) {
      channel.off('claim_reward_pools', ref)
      $closeButton.removeClass('hidden')
      unlockModal($modal)
      clearInterval(dotCounterInterval)
      if (error) {
        openErrorModal('Claim Reward', error)
      } else {
        onPoolsFound($modal, $modalBody, channel, store)
      }
    }

    openModal($modal, true)
  }).receive('error', (error) => {
    $(event.currentTarget).prop('disabled', false)
    openErrorModal('Claim Reward', error.reason)
  }).receive('timeout', () => {
    $(event.currentTarget).prop('disabled', false)
    openErrorModal('Claim Reward', 'Connection timeout')
  })
}

export function connectionLost () {
  const errorMsg = 'Connection with server is lost. Please, reload the page.'
  if (status === 'modalOpened') {
    status = 'modalClosed'
    openErrorModal('Claim Reward', errorMsg, true)
  } else if (status === 'recalculation') {
    const $recalculateButton = $('button.recalculate', currentModal())
    displayInputError($recalculateButton, errorMsg)
  }
}

function onPoolsFound ($modal, $modalBody, channel, store) {
  const $poolsDropdown = $('select', $modalBody)
  const $epochChoiceRadio = $('input[name="epoch_choice"]', $modalBody)
  const $specifiedEpochsText = $('input.specified-epochs', $modalBody)
  const $recalculateButton = $('button.recalculate', $modalBody)
  const $submitButton = $('button.submit', $modalBody)
  let allowedEpochs = []

  $poolsDropdown.on('change', () => {
    if (status === 'recalculation' || status === 'claiming') return false

    const data = $('option:selected', $poolsDropdown).data()
    const tokenRewardSum = data.tokenRewardSum ? data.tokenRewardSum : '0'
    const nativeRewardSum = data.nativeRewardSum ? data.nativeRewardSum : '0'
    const gasLimit = data.gasLimit ? data.gasLimit : '0'
    const $poolInfo = $('.selected-pool-info', $modalBody)
    const epochs = data.epochs ? data.epochs.toString() : ''

    allowedEpochs = expandEpochsToArray(epochs)

    $poolsDropdown.blur()
    $('textarea', $poolInfo).val(epochs)
    $('#token-reward-sum', $poolInfo).text(tokenRewardSum).data('default', tokenRewardSum)
    $('#native-reward-sum', $poolInfo).text(nativeRewardSum).data('default', nativeRewardSum)
    $('#tx-gas-limit', $poolInfo).text('~' + gasLimit).data('default', gasLimit)
    $('#epoch-choice-all', $poolInfo).click()
    $specifiedEpochsText.val('')
    $poolInfo.removeClass('hidden')
    $('.modal-bottom-disclaimer', $modal).removeClass('hidden')
    hideInputError($recalculateButton)
  })

  $epochChoiceRadio.on('change', () => {
    if (status === 'recalculation' || status === 'claiming') return false
    if ($('#epoch-choice-all', $modalBody).is(':checked')) {
      $specifiedEpochsText.addClass('hidden')
      showButton('submit', $modalBody)
      hideInputError($recalculateButton)
    } else {
      $specifiedEpochsText.removeClass('hidden')
      $specifiedEpochsText.trigger('input')
    }
  })

  $specifiedEpochsText.on('input', () => {
    if (status === 'recalculation' || status === 'claiming') return false

    const filtered = filterSpecifiedEpochs($specifiedEpochsText.val()).toString()
    $specifiedEpochsText.val(filtered)

    const pointedEpochs = expandEpochsToArray(filtered)
    const pointedEpochsAllowed = pointedEpochs.filter(item => allowedEpochs.indexOf(item) !== -1)

    const needsRecalc = pointedEpochs.length > 0 && pointedEpochsAllowed.length !== allowedEpochs.length
    showButton(needsRecalc ? 'recalculate' : 'submit', $modalBody)

    if (needsRecalc && pointedEpochsAllowed.length === 0) {
      $recalculateButton.prop('disabled', true)
      displayInputError($recalculateButton, 'The specified staking epochs are not in the allowed range')
    } else {
      $recalculateButton.prop('disabled', false)
      hideInputError($recalculateButton)
    }
  })

  $recalculateButton.on('click', (e) => {
    if (status === 'recalculation' || status === 'claiming') return false
    e.preventDefault()
    recalcStarted()

    const specifiedEpochs = $specifiedEpochsText.val().toString().replace(/[-|,]$/g, '').trim()
    $specifiedEpochsText.val(specifiedEpochs)

    const epochs = expandEpochsToArray(specifiedEpochs).filter(item => allowedEpochs.indexOf(item) !== -1)
    const poolStakingAddress = $poolsDropdown.val()
    const ref = channel.on('claim_reward_recalculations', result => {
      recalcFinished(result)
    })
    channel.push('recalc_claim_reward', {
      epochs,
      pool_staking_address: poolStakingAddress
    }).receive('error', (error) => {
      recalcFinished({error: error.reason})
    }).receive('timeout', () => {
      recalcFinished({error: 'Connection timeout'})
    })
    function recalcStarted () {
      status = 'recalculation'
      hideInputError($recalculateButton)
      lockUI(true, $modal, $recalculateButton, $poolsDropdown, $epochChoiceRadio, $specifiedEpochsText)
    }
    function recalcFinished (result) {
      channel.off('claim_reward_recalculations', ref)
      status = 'modalOpened'
      if (result.error) {
        displayInputError($recalculateButton, result.error)
      } else {
        showButton('submit', $modalBody, result)
      }
      lockUI(false, $modal, $recalculateButton, $poolsDropdown, $epochChoiceRadio, $specifiedEpochsText)
    }
  })

  $submitButton.on('click', async (e) => {
    if (status === 'recalculation' || status === 'claiming') return false
    e.preventDefault()

    const specifiedEpochs = $specifiedEpochsText.val().toString().replace(/[-|,]$/g, '').trim()
    const epochs = expandEpochsToArray(specifiedEpochs).filter(item => allowedEpochs.indexOf(item) !== -1)
    const poolStakingAddress = $poolsDropdown.val()

    claimStarted()

    function claimStarted () {
      status = 'claiming'
      hideInputError($submitButton)
      lockUI(
        true,
        $modal,
        $submitButton,
        $poolsDropdown,
        $epochChoiceRadio,
        $specifiedEpochsText,
        'Please, sign transaction in MetaMask'
      )

      const gasLimit = parseInt($('#tx-gas-limit', $modalBody).text().replace(/~/g, '').trim(), 10)
      const state = store.getState()
      const stakingContract = state.stakingContract
      const from = state.account
      const web3 = state.web3

      if (isNaN(gasLimit)) {
        claimFinished('Invalid gas limit. Please, contact support.')
      } else if (!stakingContract) {
        claimFinished('Staking contract is undefined. Please, contact support.')
      } else if (!from) {
        claimFinished('Your MetaMask account is undefined. Please, contact support.')
      } else if (!web3) {
        claimFinished('Web3 is undefined. Please, contact support.')
      } else if (!poolStakingAddress) {
        claimFinished('Pool staking address is undefined. Please, contact support.')
      } else {
        stakingContract.methods.claimReward(epochs, poolStakingAddress).send({
          from,
          gasPrice: web3.utils.toWei('1', 'gwei'),
          gas: Math.ceil(gasLimit * 1.2) // +20% reserve to ensure enough gas
        }, async function (error, txHash) {
          if (error) {
            claimFinished(error.message)
          } else {
            try {
              let tx
              let currentBlockNumber
              const maxWaitBlocks = 6
              const startBlockNumber = (await web3.eth.getBlockNumber()) - 0
              const finishBlockNumber = startBlockNumber + maxWaitBlocks
              do {
                await sleep(5) // seconds
                tx = await web3.eth.getTransactionReceipt(txHash)
                currentBlockNumber = await web3.eth.getBlockNumber()
              } while (tx === null && currentBlockNumber <= finishBlockNumber)
              if (tx) {
                if (tx.status === true || tx.status === '0x1') {
                  claimFinished()
                } else {
                  claimFinished('Transaction reverted')
                }
              } else {
                claimFinished(`Your transaction was not mined in ${maxWaitBlocks} blocks. Please, try again with the increased gas price or fixed nonce (use Reset Account feature of MetaMask).`)
              }
            } catch (e) {
              claimFinished(e.message)
            }
          }
        })
      }
    }
    function claimFinished (error) {
      lockUI(false, $modal, $submitButton, $poolsDropdown, $epochChoiceRadio, $specifiedEpochsText)
      if (error) {
        status = 'modalOpened'
        displayInputError($submitButton, error)
      } else {
        status = 'modalClosed'
        openSuccessModal('Success', 'Transaction is confirmed.')
      }
    }
  })
}

function lockUI (lock, $modal, $button, $poolsDropdown, $epochChoiceRadio, $specifiedEpochsText, spinnerText) {
  if (lock) {
    lockModal($modal, $button, spinnerText)
  } else {
    unlockModal($modal, $button)
  }
  $poolsDropdown.prop('disabled', lock)
  $epochChoiceRadio.prop('disabled', lock)
  $specifiedEpochsText.prop('disabled', lock)
}

function sleep (seconds) {
  return new Promise(resolve => setTimeout(resolve, seconds * 1000))
}

function showButton (type, $modalBody, calculations) {
  const $recalculateButton = $('button.recalculate', $modalBody)
  const $submitButton = $('button.submit', $modalBody)

  const $tokenRewardSum = $('#token-reward-sum', $modalBody)
  const $nativeRewardSum = $('#native-reward-sum', $modalBody)
  const $gasLimit = $('#tx-gas-limit', $modalBody)

  if (type === 'submit') {
    $recalculateButton.addClass('hidden')
    $submitButton.removeClass('hidden')

    const tokenRewardSum = !calculations ? $tokenRewardSum.data('default') : calculations.token_reward_sum
    const nativeRewardSum = !calculations ? $nativeRewardSum.data('default') : calculations.native_reward_sum
    const gasLimit = !calculations ? $gasLimit.data('default') : calculations.gas_limit

    $tokenRewardSum.text(tokenRewardSum).css('text-decoration', '')
    $nativeRewardSum.text(nativeRewardSum).css('text-decoration', '')
    $gasLimit.text('~' + gasLimit).css('text-decoration', '')
  } else {
    $recalculateButton.removeClass('hidden')
    $submitButton.addClass('hidden');
    [$tokenRewardSum, $nativeRewardSum, $gasLimit].forEach(
      $item => $item.css('text-decoration', 'line-through')
    )
  }
}

function expandEpochsToArray (epochs) {
  let filtered = epochs.toString().replace(/[-|,]$/g, '').trim()
  if (filtered === '') return []
  let ranges = filtered.split(',')
  ranges = ranges.map((v) => {
    if (v.indexOf('-') > -1) {
      v = v.split('-')
      v[0] = parseInt(v[0], 10)
      v[1] = parseInt(v[1], 10)
      v.sort((a, b) => a - b)
      const min = v[0]
      const max = v[1]
      let expanded = []
      for (let i = min; i <= max; i++) {
        expanded.push(i)
      }
      return expanded
    } else {
      return parseInt(v, 10)
    }
  })
  ranges = ranges.reduce((acc, val) => acc.concat(val), []) // similar to ranges.flat()
  ranges.sort((a, b) => a - b)
  ranges = [...new Set(ranges)] // make unique
  ranges = ranges.filter(epoch => epoch !== 0)
  return ranges
}

function filterSpecifiedEpochs (epochs) {
  let filtered = epochs.toString()
  filtered = filtered.replace(/[^0-9,-]+/g, '')
  filtered = filtered.replace(/-{2,}/g, '-')
  filtered = filtered.replace(/,{2,}/g, ',')
  filtered = filtered.replace(/,-/g, ',')
  filtered = filtered.replace(/-,/g, '-')
  filtered = filtered.replace(/(-[0-9]+)-/g, '$1,')
  filtered = filtered.replace(/^[,|-|0]/g, '')
  return filtered
}
