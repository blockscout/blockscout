// We need to import the CSS so that webpack will load it.
// The ExtractTextPlugin is used to separate it out into
// its own CSS file.
import '../css/app.scss'

// webpack automatically concatenates all files in your
// watched paths. Those paths can be configured as
// endpoints in "webpack.config.js".
//
// Import dependencies
//
import '@babel/polyfill'
import 'phoenix_html'
import 'bootstrap'

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

<<<<<<< HEAD
// import socket from "./socket"
=======
import './socket'
import './lib/sidebar'
import './lib/market_history_chart'
>>>>>>> Prepend broadcasted transaction to address transactions list
import './lib/card_flip'
import './lib/clipboard_buttons'
import './lib/from_now'
import './lib/market_history_chart'
import './lib/sidebar'
import './lib/tooltip'
