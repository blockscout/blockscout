import * as Sentry from '@sentry/browser'
import { Integrations } from '@sentry/tracing'

Sentry.init({
  dsn: 'https://237fc5bce6664c09b19ac13ec832c398@o170146.ingest.sentry.io/5566783',
  integrations: [
    new Integrations.BrowserTracing()
  ],

  tracesSampleRate: 1.0
})
