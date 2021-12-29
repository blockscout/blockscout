import { Socket } from 'phoenix'
import { locale } from './locale'

const socket = new Socket('/etc/kotti/socket', { params: { locale: locale } })
socket.connect()

export default socket

/**
 * Subscribes the client in the channel given the topic.
 *
 * This function will check if already exist a channel before creating one. This is useful because
 * when the client is attempting to create a duplicated subscription, the server will close the
 * existing subscription and create a new one.
 *
 * See more about it in https://hexdocs.pm/phoenix/js/#phoenix.
 *
 * Returns a Channel instance.
 */
export function subscribeChannel (topic) {
  const channel = socket.channels.find(channel => channel.topic === topic)

  if (channel) {
    return channel
  } else {
    const channel = socket.channel(topic, {})
    channel.join()
    return channel
  }
}
