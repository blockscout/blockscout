import {Socket} from 'phoenix'
import {locale} from './locale'

const socket = new Socket('/socket', {params: {locale: locale}})
socket.connect()

export default socket
