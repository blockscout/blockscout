import $ from 'jquery'
import { openModal, openErrorModal, openWarningModal, lockModal, unlockModal } from '../../lib/modals'
import { isSupportedNetwork } from './utils'

export function openClaimRewardModal(store) {
  if (!isSupportedNetwork(store)) return

  const state = store.getState();

  if (!state.account) {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }

  const channel = state.channel

  channel.push('render_claim_reward', { preload: true }).receive('ok', msg => {
    const $modal = $(msg.html)
    const closeButton = $modal.find('.close-modal')
    const modalBody = $('.modal-body', $modal)
    const waitingMessageContainer = modalBody.find('p')

    let dotCounter = 0
    const dotCounterInterval = setInterval(() => {
      let waitingMessage = $.trim(waitingMessageContainer.text())
      if (!waitingMessage.endsWith('.')) {
        waitingMessage = waitingMessage + '.'
      }
      waitingMessage = waitingMessage.replace(/\.+$/g, " " + ".".repeat(dotCounter))
      waitingMessageContainer.text(waitingMessage)
      dotCounter = (dotCounter + 1) % 4
    }, 500)

    closeButton.hide()
    lockModal($modal)
    channel.on('claim_reward_pools', msg_pools => {
      channel.off('claim_reward_pools')
      closeButton.show()
      unlockModal($modal)
      clearInterval(dotCounterInterval)
      modalBody.html(msg_pools.html)
    })
    $modal.on('shown.bs.modal', () => {
      channel.push('render_claim_reward', {}).receive('error', (error) => {
        openErrorModal('Claim Reward', error.reason)
      })
    })
    $modal.on('hidden.bs.modal', () => {
      $(this).remove()
    })

    openModal($modal);
  })
}
