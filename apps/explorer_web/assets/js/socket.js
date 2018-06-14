import {Socket} from 'phoenix'
import $ from 'jquery'

let socket = new Socket('/socket', {params: {locale: window.locale}})
socket.connect()





// addresses channel
let channel = socket.channel(`addresses:${window.addressHash}`, {})
channel.join()
  .receive('ok', resp => { console.log('Joined successfully', resp) })
  .receive('error', resp => { console.log('Unable to join', resp) })

channel.on('transaction', (msg) => {
  $('[data-selector="transactions-list"]').prepend(msg.transaction)
})

export default socket
