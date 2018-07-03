import {Socket} from 'phoenix'
import router from './router'

const socket = new Socket('/socket', {params: {locale: router.locale}})
socket.connect()

export default socket
