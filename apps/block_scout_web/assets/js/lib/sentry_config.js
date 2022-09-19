import * as Sentry from '@sentry/browser'
import { Integrations } from '@sentry/tracing'

Sentry.init({
  dsn: process.env.SENTRY_DSN_CLIENT_GNOSIS,
  integrations: [
    new Integrations.BrowserTracing()
  ],

  tracesSampleRate: 1.0
})
