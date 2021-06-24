// We need to import the CSS so that webpack will load it.
// The ExtractTextPlugin is used to separate it out into
// its own CSS file.
import '../css/app.scss'

import './main_page'

import './pages/stakes'
import './lib/clipboard_buttons'
import './lib/currency'
import './lib/pending_transactions_toggle'
import './lib/pretty_json'
import './lib/reload_button'
import './lib/stop_propagation'
import './lib/modals'
import './lib/card_tabs'
import './lib/sentry'
