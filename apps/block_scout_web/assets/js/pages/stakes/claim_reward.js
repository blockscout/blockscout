import $ from 'jquery'
import { openModal, openErrorModal, openWarningModal, lockModal, unlockModal } from '../../lib/modals'
import { isSupportedNetwork } from './utils'

export function openClaimRewardModal(store) {
  if (!isSupportedNetwork(store)) return

  const state = store.getState()
  const channel = state.channel

  channel.push('render_claim_reward', { preload: true }).receive('ok', msg => {
    const $modal = $(msg.html)
    const $closeButton = $modal.find('.close-modal')
    const $modalBody = $('.modal-body', $modal)
    const $waitingMessageContainer = $modalBody.find('p')

    let dotCounter = 0
    const dotCounterInterval = setInterval(() => {
      let waitingMessage = $.trim($waitingMessageContainer.text())
      if (!waitingMessage.endsWith('.')) {
        waitingMessage = waitingMessage + '.'
      }
      waitingMessage = waitingMessage.replace(/\.+$/g, " " + ".".repeat(dotCounter))
      $waitingMessageContainer.text(waitingMessage)
      dotCounter = (dotCounter + 1) % 4
    }, 500)

    $closeButton.hide()
    lockModal($modal)
    channel.on('claim_reward_pools', msg_pools => {
      channel.off('claim_reward_pools')
      $closeButton.show()
      unlockModal($modal)
      clearInterval(dotCounterInterval)
      $modalBody.html(msg_pools.html)
      onPoolsFound($modal, $modalBody)
    })
    $modal.on('shown.bs.modal', () => {
      channel.push('render_claim_reward', {}).receive('error', (error) => {
        openErrorModal('Claim Reward', error.reason)
      })
    })
    $modal.on('hidden.bs.modal', () => {
      $modal.remove()
    })

    openModal($modal);
  }).receive('error', (error) => {
    openErrorModal('Claim Reward', error.reason)
  })
}

function onPoolsFound($modal, $modalBody) {
  const $poolsDropdown = $('[pool-select]', $modalBody)
  const $epochChoiceRadio = $('input[name="epoch_choice"]', $modalBody)
  const $specifiedEpochsText = $('.specified-epochs', $modalBody)
  let allowedEpochs = []

  $poolsDropdown.on('change', () => {
    const data = $('option:selected', this).data()
    const $poolInfo = $('.selected-pool-info', $modalBody)
    const epochs = data.epochs ? data.epochs : ''

    allowedEpochs = expandEpochsToArray(epochs)

    $poolsDropdown.blur()
    $('textarea', $poolInfo).val(epochs)
    $('#token-reward-sum', $poolInfo).html(data.tokenRewardSum ? data.tokenRewardSum : '0')
    $('#native-reward-sum', $poolInfo).html(data.nativeRewardSum ? data.nativeRewardSum : '0')
    $('#tx-gas-limit', $poolInfo).html(data.gasLimit ? '~' + data.gasLimit : '0')
    $('#epoch-choice-all', $poolInfo).click()
    $specifiedEpochsText.val('')
    $poolInfo.removeClass('hidden')
    $('.modal-bottom-disclaimer', $modal).removeClass('hidden')
  })

  $epochChoiceRadio.on('change', () => {
    if ($('#epoch-choice-all', $modalBody).is(':checked')) {
      $specifiedEpochsText.addClass('hidden')
      showRecalcButton(false, $modalBody)
    } else {
      $specifiedEpochsText.removeClass('hidden')
      $specifiedEpochsText.trigger('input')
    }
  })

  $specifiedEpochsText.on('input', () => {
    const filtered = filterSpecifiedEpochs($specifiedEpochsText.val())
    const pointedEpochs = expandEpochsToArray(filtered)
    const needsRecalc = pointedEpochs.length > 0 && !isArrayIncludedToArray(allowedEpochs, pointedEpochs)
    showRecalcButton(needsRecalc, $modalBody)
    $specifiedEpochsText.val(filtered)
  })
}

function showRecalcButton(show, $modalBody) {
  const $itemsToStrikeOut = $('#token-reward-sum, #native-reward-sum, #tx-gas-limit', $modalBody)
  const $recalculateButton = $('button.recalculate', $modalBody)
  const $submitButton = $('button.submit', $modalBody)
  if (show) {
    $itemsToStrikeOut.css('text-decoration', 'line-through')
    $recalculateButton.removeClass('hidden')
    $submitButton.addClass('hidden')
  } else {
    $itemsToStrikeOut.css('text-decoration', '')
    $recalculateButton.addClass('hidden')
    $submitButton.removeClass('hidden')
  }
}

function expandEpochsToArray(epochs) {
  let filtered = epochs.replace(/[-|,]$/g, '').trim()
  if (filtered == '') return []
  let ranges = filtered.split(',')
  ranges = ranges.map((v) => {
    if (v.indexOf('-') > -1) {
      v = v.split('-')
      v[0] = parseInt(v[0])
      v[1] = parseInt(v[1])
      v.sort((a, b) => a - b)
      const min = v[0]
      const max = v[1]
      let expanded = []
      for (let i = min; i <= max; i++) {
        expanded.push(i)
      }
      return expanded
    } else {
      return parseInt(v)
    }
  })
  ranges = ranges.reduce((acc, val) => acc.concat(val), []) // similar to ranges.flat()
  ranges.sort((a, b) => a - b)
  ranges = [...new Set(ranges)] // make unique
  ranges = ranges.filter(epoch => epoch != 0)
  return ranges
}

function filterSpecifiedEpochs(epochs) {
  let filtered = epochs
  filtered = filtered.replace(/[^0-9,-]+/g, '')
  filtered = filtered.replace(/-{2,}/g, '-')
  filtered = filtered.replace(/,{2,}/g, ',')
  filtered = filtered.replace(/,-/g, ',')
  filtered = filtered.replace(/-,/g, '-')
  filtered = filtered.replace(/(-[0-9]+)-/g, '$1,')
  filtered = filtered.replace(/^[,|-|0]/g, '')
  return filtered
}

function isArrayIncludedToArray(source, target) {
  const filtered = target.filter(item => source.indexOf(item) != -1)
  return filtered.length == source.length
}
