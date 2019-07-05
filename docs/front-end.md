<!--front-end.md -->

## Front-end

### Javascript

All Javascript files are located in [apps/block_scout_web/assets/js](https://github.com/poanetwork/blockscout/tree/master/apps/block_scout_web/assets/js). The main file is [app.js](https://github.com/poanetwork/blockscout/blob/master/apps/block_scout_web/assets/js/app.js). This file imports all javascript used in the application. If you want to create a new JS file consider creating in [/js/pages](https://github.com/poanetwork/blockscout/tree/master/apps/block_scout_web/assets/js/pages) or [/js/lib](https://github.com/poanetwork/blockscout/tree/master/apps/block_scout_web/assets/js/lib), as follows:

#### js/lib
This folder contains all scripts usable for any page or as helpers to some component.

#### js/pages
This folder contains the scripts that are page-specific.

#### Redux
This project uses Redux to control the state in some pages. There are pages with real-time events that use Phoenix channels, e.g. Address page. The page state changes often depending on which events it is listening to. Redux is also used to load some contents asynchronously, see [async_listing_load.js](https://github.com/poanetwork/blockscout/blob/master/apps/block_scout_web/assets/js/lib/async_listing_load.js).

To understand how to build new pages that require Redux, see the [redux_helpers.js](https://github.com/poanetwork/blockscout/blob/master/apps/block_scout_web/assets/js/lib/redux_helpers.js) file.