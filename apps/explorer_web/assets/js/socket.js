import {Socket} from 'phoenix'

const socket = new Socket('/socket', {params: {locale: window.locale}})
socket.connect()

export default socket
