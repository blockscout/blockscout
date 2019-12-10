import $ from 'jquery'
import { openModal, openWarningModal, lockModal, unlockModal } from '../../lib/modals'
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
    $modal.on('shown.bs.modal', () => {
      const timeout = 15000; // ms
      channel.push('render_claim_reward', { timeout: timeout }, timeout * 2).receive('ok', msg_pools => {
        closeButton.show()
        unlockModal($modal)
        clearInterval(dotCounterInterval)
        modalBody.html(msg_pools.html)
      })
    })

    openModal($modal);
  })
}
