import $ from 'jquery'
import { openModal } from '../../lib/modals'

export function openPoolInfoModal (event, store) {
  const address = $(event.target).closest('[data-address]').data('address')

  store.getState().channel
    .push('render_validator_info', { address })
    .receive('ok', msg => openModal($(msg.html)))
}
