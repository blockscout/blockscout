import mixpanel from 'mixpanel-browser'
import { init as amplitudeInit, track as amplitudeTrack } from '@amplitude/analytics-browser'

// @ts-ignore
const mixpanelToken = process.env.MIXPANEL_TOKEN
// @ts-ignore
const amplitudeApiKey = process.env.AMPLITUDE_API_KEY
let initialized = false
export let mixpanelInitialized = false
export let amplitudeInitialized = false

export function init () {
  // @ts-ignore
  const mixpanelUrl = process.env.MIXPANEL_URL
  // @ts-ignore
  const amplitudeUrl = process.env.AMPLITUDE_URL

  if (mixpanelToken) {
    if (mixpanelUrl) {
      mixpanel.init(mixpanelToken, { api_host: mixpanelUrl })
    } else {
      mixpanel.init(mixpanelToken)
    }
    mixpanelInitialized = true
  }

  if (amplitudeApiKey) {
    if (amplitudeUrl) {
      amplitudeInit(amplitudeApiKey, undefined, { serverUrl: amplitudeUrl })
    } else {
      amplitudeInit(amplitudeApiKey)
    }
    amplitudeInitialized = true
  }
  initialized = true
}

export function trackEvent (eventName, eventProperties = {}) {
  if (!initialized) {
    init()
  }

  if (mixpanelInitialized) {
    mixpanel.track(eventName, eventProperties)
  }

  if (amplitudeInitialized) {
    amplitudeTrack(eventName, eventProperties)
  }
}
