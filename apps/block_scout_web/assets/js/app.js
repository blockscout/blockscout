// We need to import the CSS so that webpack will load it.
// The ExtractTextPlugin is used to separate it out into
// its own CSS file.
import '../css/app.scss'

import './main_page'

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import './locale'

import './pages/layout'
import './pages/dark-mode-switcher'

import './lib/clipboard_buttons'
import './lib/currency'
import './lib/pending_transactions_toggle'
import './lib/pretty_json'
import './lib/reload_button'
import './lib/stop_propagation'
import './lib/modals'
import './lib/card_tabs'
import './lib/sentry_config'
import './lib/ad'

import swal from 'sweetalert2'
// @ts-ignore
window.Swal = swal
