import $ from 'jquery'
import { openModal } from '../../lib/modals'

export function openDelegatorsListModal (event, store) {
  const address = $(event.target).closest('[data-address]').data('address')

  store.getState().channel
    .push('render_delegators_list', { address })
    .receive('ok', msg => openModal($(msg.html)))
}
