FORMAT: 1A
HOST:http://blockscout.com/poa/core
# 


# API Documentation


# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/info]
### BlockScoutWeb.Account.Api.V1.UserController info [GET /api/account/v1/user/info]


 


+ Request Get info about user
**GET**&nbsp;&nbsp;`/api/account/v1/user/info`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjNkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTM3QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABHGQABG5hbWVtAAAAC1VzZXIgVGVzdDIzZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIzZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIzZAAMd2F0Y2hsaXN0X2lkYgAAARw.E0Sm_2oS5AyE0tua4lSouZRAcWS_F5ZcfGxLWSTUkXA; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2a5ilyuHABAAABjC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "nickname": "test_user23",
              "name": "User Test23",
              "email": "test_user-37@blockscout.com",
              "avatar": "https://example.com/avatar/test_user23"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_tag_address [POST /api/account/v1/user/tags/address]


 


+ Request Add private address tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/address`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "MyName",
              "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyN2QABWVtYWlsbQAAABt0ZXN0X3VzZXItMTdAYmxvY2tzY291dC5jb21kAAJpZGIAAAEMZAAEbmFtZW0AAAAKVXNlciBUZXN0N2QACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI3ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDdkAAx3YXRjaGxpc3RfaWRiAAABDA.nTbrGL1cYPUoZ-N2MiHq9YBaqutQsS6G_gJBJmjD_mE; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2Za89gG9wigAABTB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "MyName",
              "id": 66,
              "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b",
              "address": {
                "watchlist_names": [],
                "public_tags": [],
                "private_tags": [],
                "name": null,
                "is_verified": false,
                "is_contract": false,
                "implementation_name": null,
                "hash": "0x3E9AC8f16C92bc4F093357933B5BEFBF1E16987B"
              }
            }

# Group BlockScoutWeb.Account.Api.V1.TagsController
## BlockScoutWeb.Account.Api.V1.TagsController [/api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b]
### BlockScoutWeb.Account.Api.V1.TagsController tags_address [GET /api/account/v1/tags/address/{address_hash}]


 

+ Parameters
    + address_hash: `0x3e9ac8f16c92bc4f093357933b5befbf1e16987b`
            address_hash: 0x3e9ac8f16c92bc4f093357933b5befbf1e16987b


+ Request Get tags for address
**GET**&nbsp;&nbsp;`/api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyN2QABWVtYWlsbQAAABt0ZXN0X3VzZXItMTdAYmxvY2tzY291dC5jb21kAAJpZGIAAAEMZAAEbmFtZW0AAAAKVXNlciBUZXN0N2QACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI3ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDdkAAx3YXRjaGxpc3RfaWRiAAABDA.nTbrGL1cYPUoZ-N2MiHq9YBaqutQsS6G_gJBJmjD_mE; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2ZcSwwK9wigAABMC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "watchlist_names": [],
              "personal_tags": [
                {
                  "label": "MyName",
                  "display_name": "MyName",
                  "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
                }
              ],
              "common_tags": []
            }

# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/address/70]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_address [PUT /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `70`
            id: 70


+ Request Edit private address tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/address/70`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "name3",
              "address_hash": "0x000000000000000000000000000000000000007e"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTlkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTMxQGJsb2Nrc2NvdXQuY29tZAACaWRiAAABGGQABG5hbWVtAAAAC1VzZXIgVGVzdDE5ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE5ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE5ZAAMd2F0Y2hsaXN0X2lkYgAAARg.gpllu6S6EuYQy2GBhhmdrwjWa7uNmRUMz8aoKGDaPQU; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aYSywZD3jIAAAQF
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "name3",
              "id": 70,
              "address_hash": "0x000000000000000000000000000000000000007e",
              "address": {
                "watchlist_names": [],
                "public_tags": [],
                "private_tags": [],
                "name": null,
                "is_verified": false,
                "is_contract": false,
                "implementation_name": null,
                "hash": "0x000000000000000000000000000000000000007E"
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_address [GET /api/account/v1/user/tags/address]


 


+ Request Get private addresses tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/address`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMThkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTMwQGJsb2Nrc2NvdXQuY29tZAACaWRiAAABF2QABG5hbWVtAAAAC1VzZXIgVGVzdDE4ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE4ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE4ZAAMd2F0Y2hsaXN0X2lkYgAAARc.MgpnF7n_gJEhkWphCunY7unXVQWz6NAKdXJtAlCtm-E; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aT84qhvvqoAABfh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "name2",
                "id": 69,
                "address_hash": "0x000000000000000000000000000000000000007c",
                "address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": false,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000007c"
                }
              },
              {
                "name": "name1",
                "id": 68,
                "address_hash": "0x000000000000000000000000000000000000007b",
                "address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": false,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000007B"
                }
              },
              {
                "name": "name0",
                "id": 67,
                "address_hash": "0x000000000000000000000000000000000000007a",
                "address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": false,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000007a"
                }
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_address [DELETE /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `63`
            id: 63


+ Request Delete private address tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/address/63`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNGQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTRAYmxvY2tzY291dC5jb21kAAJpZGIAAAEJZAAEbmFtZW0AAAAKVXNlciBUZXN0NGQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI0ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDRkAAx3YXRjaGxpc3RfaWRiAAABCQ.3f3SFCRJgY59jb-YfVwAjM-xZEMv78Z1X-yNR03pCOI; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2YwZcxcJlUgAABJh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_tag_transaction [POST /api/account/v1/user/tags/transaction]


 


+ Request Create private transaction tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000006",
              "name": "MyName"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTVkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI3QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABFGQABG5hbWVtAAAAC1VzZXIgVGVzdDE1ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE1ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE1ZAAMd2F0Y2hsaXN0X2lkYgAAARQ.y7cpDUrwXiGxhgdOS0V14Rsohk8wJHkv940fW0Mw1YQ; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aDXRGevcEwAABYh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000006",
              "name": "MyName",
              "id": 61
            }


+ Request Error on try to create private transaction tag for tx does not exist
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000005",
              "name": "MyName"
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTVkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI3QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABFGQABG5hbWVtAAAAC1VzZXIgVGVzdDE1ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE1ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE1ZAAMd2F0Y2hsaXN0X2lkYgAAARQ.y7cpDUrwXiGxhgdOS0V14Rsohk8wJHkv940fW0Mw1YQ; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aCGof2vcEwAAAlk
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "tx_hash": [
                  "Transaction does not exist"
                ]
              }
            }

# Group BlockScoutWeb.Account.Api.V1.TagsController
## BlockScoutWeb.Account.Api.V1.TagsController [/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000006]
### BlockScoutWeb.Account.Api.V1.TagsController tags_transaction [GET /api/account/v1/tags/transaction/{transaction_hash}]


 

+ Parameters
    + transaction_hash: `0x0000000000000000000000000000000000000000000000000000000000000006`
            transaction_hash: 0x0000000000000000000000000000000000000000000000000000000000000006


+ Request Get tags for transaction
**GET**&nbsp;&nbsp;`/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000006`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTVkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI3QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABFGQABG5hbWVtAAAAC1VzZXIgVGVzdDE1ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE1ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE1ZAAMd2F0Y2hsaXN0X2lkYgAAARQ.y7cpDUrwXiGxhgdOS0V14Rsohk8wJHkv940fW0Mw1YQ; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aEbojKvcEwAABZB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "watchlist_names": [],
              "personal_tx_tag": {
                "label": "MyName"
              },
              "personal_tags": [],
              "common_tags": []
            }

# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/transaction/57]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_transaction [PUT /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `57`
            id: 57


+ Request Edit private transaction tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/57`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "name1"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMWQABWVtYWlsbQAAABp0ZXN0X3VzZXItMUBibG9ja3Njb3V0LmNvbWQAAmlkYgAAAQZkAARuYW1lbQAAAApVc2VyIFRlc3QxZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjFkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMWQADHdhdGNobGlzdF9pZGIAAAEG.K4xvLgb-ji7_yiP-B80J_ItCchTMzzYcgcN7ku9a4B8; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2XSUU7NY8y8AAAME
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "name1",
              "id": 57
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_transaction [GET /api/account/v1/user/tags/transaction]


 


+ Request Get private transactions tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjJkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTM2QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABG2QABG5hbWVtAAAAC1VzZXIgVGVzdDIyZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIyZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIyZAAMd2F0Y2hsaXN0X2lkYgAAARs.O7Ha2Ze8DT1d2yaZbQEy9tZXE6OUDWyuh3yoyB2WNAU; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2a4GFi44x6sAABii
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
                "name": "name2",
                "id": 64
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000008",
                "name": "name1",
                "id": 63
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000007",
                "name": "name0",
                "id": 62
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_transaction [DELETE /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `58`
            id: 58


+ Request Delete private transaction tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/58`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTRkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI2QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABE2QABG5hbWVtAAAAC1VzZXIgVGVzdDE0ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE0ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE0ZAAMd2F0Y2hsaXN0X2lkYgAAARM.XN0A5eUbCpZdpnhayHyU-YiQ4jm1-WjwYxvGD6JVCmg; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2Z9NDKXc1FcAABYC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Add address to watch list
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-20": {
                  "outcoming": true,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test26",
              "address_hash": "0x000000000000000000000000000000000000007f"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjBkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTMyQGJsb2Nrc2NvdXQuY29tZAACaWRiAAABGWQABG5hbWVtAAAAC1VzZXIgVGVzdDIwZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIwZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIwZAAMd2F0Y2hsaXN0X2lkYgAAARk.vaGEF62HMb-YGk5JNfvq8xH6YkGmQaEEa1gpNIUmjJM; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2acnBbQAq20AAARF
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-20": {
                  "outcoming": true,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test26",
              "id": 73,
              "exchange_rate": null,
              "address_hash": "0x000000000000000000000000000000000000007f",
              "address_balance": null,
              "address": {
                "watchlist_names": [],
                "public_tags": [],
                "private_tags": [],
                "name": null,
                "is_verified": false,
                "is_contract": false,
                "implementation_name": null,
                "hash": "0x000000000000000000000000000000000000007f"
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController watchlist [GET /api/account/v1/user/watchlist]


 


+ Request Get addresses from watchlists
**GET**&nbsp;&nbsp;`/api/account/v1/user/watchlist`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjBkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTMyQGJsb2Nrc2NvdXQuY29tZAACaWRiAAABGWQABG5hbWVtAAAAC1VzZXIgVGVzdDIwZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIwZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIwZAAMd2F0Y2hsaXN0X2lkYgAAARk.vaGEF62HMb-YGk5JNfvq8xH6YkGmQaEEa1gpNIUmjJM; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aiKtdsAq20AABhh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "notification_settings": {
                  "native": {
                    "outcoming": true,
                    "incoming": true
                  },
                  "ERC-721": {
                    "outcoming": true,
                    "incoming": false
                  },
                  "ERC-20": {
                    "outcoming": false,
                    "incoming": false
                  }
                },
                "notification_methods": {
                  "email": true
                },
                "name": "test27",
                "id": 74,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000080",
                "address_balance": null,
                "address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": false,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000080"
                }
              },
              {
                "notification_settings": {
                  "native": {
                    "outcoming": true,
                    "incoming": true
                  },
                  "ERC-721": {
                    "outcoming": true,
                    "incoming": false
                  },
                  "ERC-20": {
                    "outcoming": true,
                    "incoming": true
                  }
                },
                "notification_methods": {
                  "email": false
                },
                "name": "test26",
                "id": 73,
                "exchange_rate": null,
                "address_hash": "0x000000000000000000000000000000000000007f",
                "address_balance": null,
                "address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": false,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000007f"
                }
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_watchlist [DELETE /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `72`
            id: 72


+ Request Delete address from watchlist by id
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/watchlist/72`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTdkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI5QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABFmQABG5hbWVtAAAAC1VzZXIgVGVzdDE3ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE3ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE3ZAAMd2F0Y2hsaXN0X2lkYgAAARY.bngpdS3ELd9RFd1465ZhfhaitqcUi6xG4s0BoDGWoAw; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aNXuJ9GNz0AABch
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `70`
            id: 70


+ Request Edit watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/70`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test21",
              "address_hash": "0x0000000000000000000000000000000000000064"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTBkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIxQGJsb2Nrc2NvdXQuY29tZAACaWRiAAABD2QABG5hbWVtAAAAC1VzZXIgVGVzdDEwZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjEwZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDEwZAAMd2F0Y2hsaXN0X2lkYgAAAQ8.JqlZQRGTvi6UZy4cEjJW6UYnZgNo0LaoO3R4mxO_fFA; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2Zo1KOm2BRoAAAJl
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test21",
              "id": 70,
              "exchange_rate": null,
              "address_hash": "0x0000000000000000000000000000000000000064",
              "address_balance": null,
              "address": {
                "watchlist_names": [],
                "public_tags": [],
                "private_tags": [],
                "name": null,
                "is_verified": false,
                "is_contract": false,
                "implementation_name": null,
                "hash": "0x0000000000000000000000000000000000000064"
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Example of error on creating watchlist address
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test0",
              "address_hash": "0x0000000000000000000000000000000000000001"
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMGQABWVtYWlsbQAAABp0ZXN0X3VzZXItMEBibG9ja3Njb3V0LmNvbWQAAmlkYgAAAQVkAARuYW1lbQAAAApVc2VyIFRlc3QwZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjBkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMGQADHdhdGNobGlzdF9pZGIAAAEF.4CS6L7Ror_vIdEgjt8Mh9y2TJagC83VObHAGZ-ABOI4; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2W1ZceoPnWQAAATj
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "watchlist_id": [
                  "Address already added to the watch list"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `69`
            id: 69


+ Request Example of error on editing watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/69`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test0",
              "address_hash": "0x0000000000000000000000000000000000000001"
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMGQABWVtYWlsbQAAABp0ZXN0X3VzZXItMEBibG9ja3Njb3V0LmNvbWQAAmlkYgAAAQVkAARuYW1lbQAAAApVc2VyIFRlc3QwZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjBkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMGQADHdhdGNobGlzdF9pZGIAAAEF.4CS6L7Ror_vIdEgjt8Mh9y2TJagC83VObHAGZ-ABOI4; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2W6esdoPnWQAAAKE
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "watchlist_id": [
                  "Address already added to the watch list"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController create_api_key [POST /api/account/v1/user/api_keys]


 


+ Request Add api key
**POST**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTZkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI4QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABFWQABG5hbWVtAAAAC1VzZXIgVGVzdDE2ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE2ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE2ZAAMd2F0Y2hsaXN0X2lkYgAAARU.bIr9Nod33f3ivryxZfzUGzSN34H8R1h_oOPJvRdulDY; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2aGwztUoK_8AAAnk
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test",
              "api_key": "5dcfeb7d-6a73-47ed-8001-130692ebdf30"
            }


+ Request Example of error on creating api key
**POST**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjRkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTM4QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABHWQABG5hbWVtAAAAC1VzZXIgVGVzdDI0ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjI0ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDI0ZAAMd2F0Y2hsaXN0X2lkYgAAAR0.K_0yxkRjZq43jcCKzlzgHFNjm7aB_BmvBzlTVbpDUYI; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2a-lcgwKyxIAAAuk
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "name": [
                  "Max 3 keys per account"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController api_keys [GET /api/account/v1/user/api_keys]


 


+ Request Get api keys list
**GET**&nbsp;&nbsp;`/api/account/v1/user/api_keys`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjRkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTM4QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABHWQABG5hbWVtAAAAC1VzZXIgVGVzdDI0ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjI0ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDI0ZAAMd2F0Y2hsaXN0X2lkYgAAAR0.K_0yxkRjZq43jcCKzlzgHFNjm7aB_BmvBzlTVbpDUYI; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2a-2qPMKyxIAABki
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "test",
                "api_key": "00c90b31-db68-4de5-8022-32b6d9bdfaf2"
              },
              {
                "name": "test",
                "api_key": "936f1623-4cfb-4581-badf-ff82193cc55e"
              },
              {
                "name": "test",
                "api_key": "8af19684-7d84-4fa5-bc5e-98391204fa21"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController update_api_key [PUT /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `e6fcab8c-d092-415d-a64e-caeebdab7e0a`
            api_key: e6fcab8c-d092-415d-a64e-caeebdab7e0a


+ Request Edit api key
**PUT**&nbsp;&nbsp;`/api/account/v1/user/api_keys/e6fcab8c-d092-415d-a64e-caeebdab7e0a`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test_1"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTNkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI1QGJsb2Nrc2NvdXQuY29tZAACaWRiAAABEmQABG5hbWVtAAAAC1VzZXIgVGVzdDEzZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjEzZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDEzZAAMd2F0Y2hsaXN0X2lkYgAAARI.oCXF9HRta7QoX4kvCCJGwXim8h2PvKmQnL3qC-BrYT0; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2ZxOPw0OLVMAABTC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test_1",
              "api_key": "e6fcab8c-d092-415d-a64e-caeebdab7e0a"
            }
### BlockScoutWeb.Account.Api.V1.UserController delete_api_key [DELETE /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `ed840181-ee0a-49e7-931c-ed12c44c3c5c`
            api_key: ed840181-ee0a-49e7-931c-ed12c44c3c5c


+ Request Delete api key
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/api_keys/ed840181-ee0a-49e7-931c-ed12c44c3c5c`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyOGQABWVtYWlsbQAAABt0ZXN0X3VzZXItMThAYmxvY2tzY291dC5jb21kAAJpZGIAAAENZAAEbmFtZW0AAAAKVXNlciBUZXN0OGQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI4ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDhkAAx3YXRjaGxpc3RfaWRiAAABDQ.N8IAT9JlprYQcjF97-2AwyvKRZ2pWrOhPA-piu_yjxY; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2ZeeHae-W7UAABPi
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_custom_abi [POST /api/account/v1/user/custom_abis]


 


+ Request Add custom abi
**POST**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test3",
              "contract_address_hash": "0x0000000000000000000000000000000000000049",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNWQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTVAYmxvY2tzY291dC5jb21kAAJpZGIAAAEKZAAEbmFtZW0AAAAKVXNlciBUZXN0NWQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI1ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDVkAAx3YXRjaGxpc3RfaWRiAAABCg.Ed2YB-WoqETtu1WlAOdX7KJi6sFIJ1SGIeS89Aie2pg; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2Y2Ja_DGUGwAAAWE
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test3",
              "id": 146,
              "contract_address_hash": "0x0000000000000000000000000000000000000049",
              "contract_address": {
                "watchlist_names": [],
                "public_tags": [],
                "private_tags": [],
                "name": null,
                "is_verified": false,
                "is_contract": true,
                "implementation_name": null,
                "hash": "0x0000000000000000000000000000000000000049"
              },
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }


+ Request Example of error on creating custom abi
**POST**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test19",
              "contract_address_hash": "0x0000000000000000000000000000000000000059",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNmQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTZAYmxvY2tzY291dC5jb21kAAJpZGIAAAELZAAEbmFtZW0AAAAKVXNlciBUZXN0NmQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI2ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDZkAAx3YXRjaGxpc3RfaWRiAAABCw.SNgNlsqLtHPQ2HgJTPlyNjbvKw2FlW_U6_cJXTD-ZE4; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2ZR-dhCywD0AABJC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "name": [
                  "Max 15 ABIs per account"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController custom_abis [GET /api/account/v1/user/custom_abis]


 


+ Request Get custom abis list
**GET**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNmQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTZAYmxvY2tzY291dC5jb21kAAJpZGIAAAELZAAEbmFtZW0AAAAKVXNlciBUZXN0NmQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI2ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDZkAAx3YXRjaGxpc3RfaWRiAAABCw.SNgNlsqLtHPQ2HgJTPlyNjbvKw2FlW_U6_cJXTD-ZE4; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2ZSytrGywD0AABJi
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "test18",
                "id": 161,
                "contract_address_hash": "0x0000000000000000000000000000000000000058",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000058"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test17",
                "id": 160,
                "contract_address_hash": "0x0000000000000000000000000000000000000057",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000057"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test16",
                "id": 159,
                "contract_address_hash": "0x0000000000000000000000000000000000000056",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000056"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test15",
                "id": 158,
                "contract_address_hash": "0x0000000000000000000000000000000000000055",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000055"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test14",
                "id": 157,
                "contract_address_hash": "0x0000000000000000000000000000000000000054",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000054"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test13",
                "id": 156,
                "contract_address_hash": "0x0000000000000000000000000000000000000053",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000053"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test12",
                "id": 155,
                "contract_address_hash": "0x0000000000000000000000000000000000000052",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000052"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test11",
                "id": 154,
                "contract_address_hash": "0x0000000000000000000000000000000000000051",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000051"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test10",
                "id": 153,
                "contract_address_hash": "0x0000000000000000000000000000000000000050",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x0000000000000000000000000000000000000050"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test9",
                "id": 152,
                "contract_address_hash": "0x000000000000000000000000000000000000004f",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000004f"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test8",
                "id": 151,
                "contract_address_hash": "0x000000000000000000000000000000000000004e",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000004e"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test7",
                "id": 150,
                "contract_address_hash": "0x000000000000000000000000000000000000004d",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000004D"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test6",
                "id": 149,
                "contract_address_hash": "0x000000000000000000000000000000000000004c",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000004C"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test5",
                "id": 148,
                "contract_address_hash": "0x000000000000000000000000000000000000004b",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000004B"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test4",
                "id": 147,
                "contract_address_hash": "0x000000000000000000000000000000000000004a",
                "contract_address": {
                  "watchlist_names": [],
                  "public_tags": [],
                  "private_tags": [],
                  "name": null,
                  "is_verified": false,
                  "is_contract": true,
                  "implementation_name": null,
                  "hash": "0x000000000000000000000000000000000000004A"
                },
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController update_custom_abi [PUT /api/account/v1/user/custom_abis/{id}]


 

+ Parameters
    + id: `162`
            id: 162


+ Request Edit custom abi
**PUT**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/162`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test23",
              "contract_address_hash": "0x0000000000000000000000000000000000000066",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTFkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIyQGJsb2Nrc2NvdXQuY29tZAACaWRiAAABEGQABG5hbWVtAAAAC1VzZXIgVGVzdDExZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjExZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDExZAAMd2F0Y2hsaXN0X2lkYgAAARA.M0fGYF6uHlLOsjA-gLmGzzXuTxSr8hQVlDi3jIhAXX0; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2ZrqXJvdOdEAAAdE
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test23",
              "id": 162,
              "contract_address_hash": "0x0000000000000000000000000000000000000066",
              "contract_address": {
                "watchlist_names": [],
                "public_tags": [],
                "private_tags": [],
                "name": null,
                "is_verified": false,
                "is_contract": true,
                "implementation_name": null,
                "hash": "0x0000000000000000000000000000000000000066"
              },
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }
### BlockScoutWeb.Account.Api.V1.UserController delete_custom_abi [DELETE /api/account/v1/user/custom_abis/{id}]


 

+ Parameters
    + id: `145`
            id: 145


+ Request Delete custom abi
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/145`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMmQABWVtYWlsbQAAABp0ZXN0X3VzZXItMkBibG9ja3Njb3V0LmNvbWQAAmlkYgAAAQdkAARuYW1lbQAAAApVc2VyIFRlc3QyZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjJkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMmQADHdhdGNobGlzdF9pZGIAAAEH.xeXAG0XBVkoEw0SR5kJ04tyapR1tY5N9XTrN_nrO63c; path=/; SameSite=Lax
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: Fy1W2XZv72akD4sAAAQk
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
