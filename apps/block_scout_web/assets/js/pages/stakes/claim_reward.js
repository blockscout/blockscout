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

  $poolsDropdown.on('change', () => {
    const data = $('option:selected', this).data()
    const $poolInfo = $('.selected-pool-info', $modalBody)

    $poolsDropdown.blur()
    $('textarea', $poolInfo).val(data.epochs ? data.epochs : '')
    $('#token-reward-sum', $poolInfo).html(data.tokenRewardSum ? data.tokenRewardSum : '0')
    $('#native-reward-sum', $poolInfo).html(data.nativeRewardSum ? data.nativeRewardSum : '0')
    $('#tx-gas-limit', $poolInfo).html(data.gasLimit ? '~' + data.gasLimit : '0')
    $('#epoch-choice-all', $poolInfo).click()
    $specifiedEpochsText.val('')
    $poolInfo.removeClass('hidden')
    $('.modal-bottom-disclaimer', $modal).removeClass('hidden')
  })

  $epochChoiceRadio.on('change', () => {
    $specifiedEpochsText.toggleClass('hidden')
  })
}
