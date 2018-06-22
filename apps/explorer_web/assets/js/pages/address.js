import $ from 'jquery'
import URI from 'urijs'
import socket from '../socket'

if (window.page === 'address') {
  const channel = socket.channel(`addresses:${window.addressHash}`, {})
  channel.join()
    .receive('ok', resp => { console.log('Joined successfully', `addresses:${window.addressHash}`, resp) })
    .receive('error', resp => { console.log('Unable to join', `addresses:${window.addressHash}`, resp) })

  const currentLocation = URI(window.location)
  if(!currentLocation.hasQuery('block_number')) {
    const $emptyTransactionsList = $('[data-selector="empty-transactions-list"]')
    if ($emptyTransactionsList) {
      channel.on('transaction', () => {
        window.location.reload()
      })
    }

    const $transactionsList = $('[data-selector="transactions-list"]')
    if ($transactionsList) {
      channel.on('transaction', (msg) => {
        $transactionsList.prepend(msg.transaction)
      })
    }
  }
}
