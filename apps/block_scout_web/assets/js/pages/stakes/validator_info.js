import $ from 'jquery'
import { openModal, openErrorModal } from '../../lib/modals'
import { makeContractCall, isSupportedNetwork } from './utils'

export function openPoolInfoModal (event, store) {
  const address = $(event.target).closest('[data-address]').data('address')

  store.getState().channel.push('render_validator_info', { address }).receive('ok', msg => {
    const $modal = $(msg.html)
    $modal.on('click', '#save_pool_metadata', event => {
      event.preventDefault()
      if (!isSupportedNetwork(store)) return

      const validatorSetContract = store.getState().validatorSetContract
      const nameField = $('#pool_name', $modal)
      const name = nameField.val()
      const descriptionField = $('#pool_description', $modal)
      const description = descriptionField.val()

      nameField.attr('disabled', true)
      descriptionField.attr('disabled', true)
      $('#save_pool_metadata_container', $modal).hide()
      $('#waiting_message', $modal).show()

      makeContractCall(validatorSetContract.methods.changeMetadata(name, description), store, null, (errorMessage) => {
        nameField.attr('disabled', false)
        descriptionField.attr('disabled', false)
        $('#waiting_message', $modal).hide()
        $('#save_pool_metadata_container', $modal).show()
        if (errorMessage) {
          openErrorModal('Error', errorMessage)
        }
      })
    })
    openModal($modal)
  })
}
