FORMAT: 1A
HOST:http://blockscout.com/xdai/testnet
# 


# API Documentation


# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/info]
### BlockScoutWeb.Account.Api.V1.UserController info [GET /api/account/v1/user/info]


 


+ Request Get info about user
**GET**&nbsp;&nbsp;`/api/account/v1/user/info`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTBkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTEzQGJsb2Nrc2NvdXQuY29tZAACaWRh42QABG5hbWVtAAAAC1VzZXIgVGVzdDEwZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjEwZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDEwZAAMd2F0Y2hsaXN0X2lkYeM.d_nsIdBT4zP1sObizRp2ufpZ2-HDGFD1puY3eNSvftY; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gur6Ap5Rc1YAAAYC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "nickname": "test_user10",
              "name": "User Test10",
              "email": "test_user-13@blockscout.com",
              "avatar": "https://example.com/avatar/test_user10"
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMmQABWVtYWlsbQAAABp0ZXN0X3VzZXItMkBibG9ja3Njb3V0LmNvbWQAAmlkYdtkAARuYW1lbQAAAApVc2VyIFRlc3QyZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjJkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMmQADHdhdGNobGlzdF9pZGHb.XPfo6e6fTpCgSOVWcAgze_SHHkf_6UVp-SfOi2EVKcM; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gt7Hha-gjLUAABDh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "MyName",
              "id": 65,
              "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMmQABWVtYWlsbQAAABp0ZXN0X3VzZXItMkBibG9ja3Njb3V0LmNvbWQAAmlkYdtkAARuYW1lbQAAAApVc2VyIFRlc3QyZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjJkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMmQADHdhdGNobGlzdF9pZGHb.XPfo6e6fTpCgSOVWcAgze_SHHkf_6UVp-SfOi2EVKcM; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gt8j_62gjLUAABFB
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
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/address/72]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_address [PUT /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `72`
            id: 72


+ Request Edit private address tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/address/72`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "name3",
              "address_hash": "0x0000000000000000000000000000000000000054"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTdkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIxQGJsb2Nrc2NvdXQuY29tZAACaWRh6mQABG5hbWVtAAAAC1VzZXIgVGVzdDE3ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE3ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE3ZAAMd2F0Y2hsaXN0X2lkYeo.SwNPw9upySrwQX8GCp62J924WYWbJY-WNA31fMLjUas; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvKquVfUECUAAB4B
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "name3",
              "id": 72,
              "address_hash": "0x0000000000000000000000000000000000000054"
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_address [GET /api/account/v1/user/tags/address]


 


+ Request Get private addresses tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/address`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTFkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE0QGJsb2Nrc2NvdXQuY29tZAACaWRh5GQABG5hbWVtAAAAC1VzZXIgVGVzdDExZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjExZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDExZAAMd2F0Y2hsaXN0X2lkYeQ.YOpB44xZNsuC9o5OZZQWpH-ijPijlYkT_fApVrfNuhs; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1guwn5VVeZtAAABdh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "name2",
                "id": 71,
                "address_hash": "0x000000000000000000000000000000000000003a"
              },
              {
                "name": "name1",
                "id": 70,
                "address_hash": "0x0000000000000000000000000000000000000039"
              },
              {
                "name": "name0",
                "id": 69,
                "address_hash": "0x0000000000000000000000000000000000000038"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_address [DELETE /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `66`
            id: 66


+ Request Delete private address tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/address/66`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNmQABWVtYWlsbQAAABp0ZXN0X3VzZXItN0BibG9ja3Njb3V0LmNvbWQAAmlkYd9kAARuYW1lbQAAAApVc2VyIFRlc3Q2ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjZkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwNmQADHdhdGNobGlzdF9pZGHf.2gy24vcTMAaovCIPA7q8PYmlv1ojuZGzgHCkQ6n_W70; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1guUM2L0cz9IAABXh
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
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
              "name": "MyName"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjFkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI1QGJsb2Nrc2NvdXQuY29tZAACaWRh7mQABG5hbWVtAAAAC1VzZXIgVGVzdDIxZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIxZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIxZAAMd2F0Y2hsaXN0X2lkYe4.OALg_k0K4kFbxlwrk2_wILKz3Ojtx5g-lwqsQWUvTHE; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvV7jRTkLOwAACCB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
              "name": "MyName",
              "id": 72
            }


+ Request Error on try to create private transaction tag for tx does not exist
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000008",
              "name": "MyName"
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjFkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI1QGJsb2Nrc2NvdXQuY29tZAACaWRh7mQABG5hbWVtAAAAC1VzZXIgVGVzdDIxZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIxZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIxZAAMd2F0Y2hsaXN0X2lkYe4.OALg_k0K4kFbxlwrk2_wILKz3Ojtx5g-lwqsQWUvTHE; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvVV0ZPkLOwAACBh
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
## BlockScoutWeb.Account.Api.V1.TagsController [/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000009]
### BlockScoutWeb.Account.Api.V1.TagsController tags_transaction [GET /api/account/v1/tags/transaction/{transaction_hash}]


 

+ Parameters
    + transaction_hash: `0x0000000000000000000000000000000000000000000000000000000000000009`
            transaction_hash: 0x0000000000000000000000000000000000000000000000000000000000000009


+ Request Get tags for transaction
**GET**&nbsp;&nbsp;`/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000009`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjFkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI1QGJsb2Nrc2NvdXQuY29tZAACaWRh7mQABG5hbWVtAAAAC1VzZXIgVGVzdDIxZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIxZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIxZAAMd2F0Y2hsaXN0X2lkYe4.OALg_k0K4kFbxlwrk2_wILKz3Ojtx5g-lwqsQWUvTHE; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvWZkx3kLOwAACCh
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
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/transaction/65]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_transaction [PUT /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `65`
            id: 65


+ Request Edit private transaction tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/65`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "name1"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyOGQABWVtYWlsbQAAABp0ZXN0X3VzZXItOUBibG9ja3Njb3V0LmNvbWQAAmlkYeFkAARuYW1lbQAAAApVc2VyIFRlc3Q4ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjhkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwOGQADHdhdGNobGlzdF9pZGHh.CybEtb6DRCGrUsJ2qnEERIZwD6pRhUfUSwFugOLA9kg; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gunOuMiiGZsAAASi
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "name1",
              "id": 65
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_transaction [GET /api/account/v1/user/tags/transaction]


 


+ Request Get private transactions tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTRkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE4QGJsb2Nrc2NvdXQuY29tZAACaWRh52QABG5hbWVtAAAAC1VzZXIgVGVzdDE0ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE0ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE0ZAAMd2F0Y2hsaXN0X2lkYec.CDHGLjvSgiNStdl55exaXgWiuAWfGw65IX3_vK5h5dU; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gu9MDrtpGp0AABnh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000004",
                "name": "name2",
                "id": 68
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000003",
                "name": "name1",
                "id": 67
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000002",
                "name": "name0",
                "id": 66
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_transaction [DELETE /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `69`
            id: 69


+ Request Delete private transaction tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/69`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTZkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIwQGJsb2Nrc2NvdXQuY29tZAACaWRh6WQABG5hbWVtAAAAC1VzZXIgVGVzdDE2ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE2ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE2ZAAMd2F0Y2hsaXN0X2lkYek.LsY5H_7VsGeJ-WoDRIReTCTZmPTJNCTjme7ZshEuEpQ; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvGE13QyfYIAAByB
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
                "email": true
              },
              "name": "test16",
              "address_hash": "0x0000000000000000000000000000000000000011"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyM2QABWVtYWlsbQAAABp0ZXN0X3VzZXItM0BibG9ja3Njb3V0LmNvbWQAAmlkYdxkAARuYW1lbQAAAApVc2VyIFRlc3QzZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjNkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwM2QADHdhdGNobGlzdF9pZGHc.ujumccFj98DtF6Rf_O0i31DGgry0eHmykzCC1xvjVfY; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gt-4UWemyBYAABJB
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
                "email": true
              },
              "name": "test16",
              "id": 75,
              "exchange_rate": null,
              "address_hash": "0x0000000000000000000000000000000000000011",
              "address_balance": null
            }
### BlockScoutWeb.Account.Api.V1.UserController watchlist [GET /api/account/v1/user/watchlist]


 


+ Request Get addresses from watchlists
**GET**&nbsp;&nbsp;`/api/account/v1/user/watchlist`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyM2QABWVtYWlsbQAAABp0ZXN0X3VzZXItM0BibG9ja3Njb3V0LmNvbWQAAmlkYdxkAARuYW1lbQAAAApVc2VyIFRlc3QzZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjNkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwM2QADHdhdGNobGlzdF9pZGHc.ujumccFj98DtF6Rf_O0i31DGgry0eHmykzCC1xvjVfY; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1guCYRuamyBYAAANj
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "notification_settings": {
                  "native": {
                    "outcoming": true,
                    "incoming": false
                  },
                  "ERC-721": {
                    "outcoming": true,
                    "incoming": false
                  },
                  "ERC-20": {
                    "outcoming": false,
                    "incoming": true
                  }
                },
                "notification_methods": {
                  "email": false
                },
                "name": "test17",
                "id": 76,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000012",
                "address_balance": null
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
                  "email": true
                },
                "name": "test16",
                "id": 75,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000011",
                "address_balance": null
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_watchlist [DELETE /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `82`
            id: 82


+ Request Delete address from watchlist by id
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/watchlist/82`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTlkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIzQGJsb2Nrc2NvdXQuY29tZAACaWRh7GQABG5hbWVtAAAAC1VzZXIgVGVzdDE5ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE5ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE5ZAAMd2F0Y2hsaXN0X2lkYew.slyWFXgdvd78Pwp3lyrU5tmgCtF7VNIPHxnFkfAQ-YQ; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvR861_DWHcAAAhC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `80`
            id: 80


+ Request Edit watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/80`

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
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test21",
              "address_hash": "0x0000000000000000000000000000000000000023"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyN2QABWVtYWlsbQAAABp0ZXN0X3VzZXItOEBibG9ja3Njb3V0LmNvbWQAAmlkYeBkAARuYW1lbQAAAApVc2VyIFRlc3Q3ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjdkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwN2QADHdhdGNobGlzdF9pZGHg.2IaE2naK_o4H_guVwcTb0JZIp2hs2c4fvtASxCmIWHM; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gugvkSj5PXEAAANi
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
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test21",
              "id": 80,
              "exchange_rate": null,
              "address_hash": "0x0000000000000000000000000000000000000023",
              "address_balance": null
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
              "name": "test18",
              "address_hash": "0x0000000000000000000000000000000000000013"
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNGQABWVtYWlsbQAAABp0ZXN0X3VzZXItNEBibG9ja3Njb3V0LmNvbWQAAmlkYd1kAARuYW1lbQAAAApVc2VyIFRlc3Q0ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjRkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwNGQADHdhdGNobGlzdF9pZGHd.jCNAb9dB6WGIZv9wIVL9tpikIPr056ChTYcDeSWdnG4; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1guGsUmFGrIUAABMB
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
    + id: `79`
            id: 79


+ Request Example of error on editing watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/79`

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
              "name": "test18",
              "address_hash": "0x0000000000000000000000000000000000000013"
            }

+ Response 422

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNGQABWVtYWlsbQAAABp0ZXN0X3VzZXItNEBibG9ja3Njb3V0LmNvbWQAAmlkYd1kAARuYW1lbQAAAApVc2VyIFRlc3Q0ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjRkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwNGQADHdhdGNobGlzdF9pZGHd.jCNAb9dB6WGIZv9wIVL9tpikIPr056ChTYcDeSWdnG4; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1guIKk8ZGrIUAABNB
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjBkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI0QGJsb2Nrc2NvdXQuY29tZAACaWRh7WQABG5hbWVtAAAAC1VzZXIgVGVzdDIwZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIwZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIwZAAMd2F0Y2hsaXN0X2lkYe0.hIRgUayy_NKWZARAIxD2-TPy3PaP5kQSHuKGOLxxwz0; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvTjkbFZ2PwAACBB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test",
              "api_key": "05b65dfd-0d08-4aa1-b22b-95e3fc8a55e5"
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTVkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE5QGJsb2Nrc2NvdXQuY29tZAACaWRh6GQABG5hbWVtAAAAC1VzZXIgVGVzdDE1ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE1ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE1ZAAMd2F0Y2hsaXN0X2lkYeg.M4suuaCnSncg5sgQepwyEGrDqMcSle2BvUjGq5qw0Q8; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gu_KXoEIU2IAABrh
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTVkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE5QGJsb2Nrc2NvdXQuY29tZAACaWRh6GQABG5hbWVtAAAAC1VzZXIgVGVzdDE1ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE1ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE1ZAAMd2F0Y2hsaXN0X2lkYeg.M4suuaCnSncg5sgQepwyEGrDqMcSle2BvUjGq5qw0Q8; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gu_ZqjIIU2IAABsB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "test",
                "api_key": "3d07da0e-428e-4410-bc54-43ab544e20f4"
              },
              {
                "name": "test",
                "api_key": "92036fb5-a22a-418d-ac3a-0415e731d55a"
              },
              {
                "name": "test",
                "api_key": "0262ffe5-6d6a-4f79-8444-479e8be85d0e"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController update_api_key [PUT /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `6bcec727-d945-4785-99b6-c6094bbf0452`
            api_key: 6bcec727-d945-4785-99b6-c6094bbf0452


+ Request Edit api key
**PUT**&nbsp;&nbsp;`/api/account/v1/user/api_keys/6bcec727-d945-4785-99b6-c6094bbf0452`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test_1"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMGQABWVtYWlsbQAAABp0ZXN0X3VzZXItMEBibG9ja3Njb3V0LmNvbWQAAmlkYdlkAARuYW1lbQAAAApVc2VyIFRlc3QwZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjBkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMGQADHdhdGNobGlzdF9pZGHZ.eNhiwGmTdeNAVqQGfVgtac9gGTsoXnysChIBQN75BQk; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gtunEs8BJMYAABCE
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test_1",
              "api_key": "6bcec727-d945-4785-99b6-c6094bbf0452"
            }
### BlockScoutWeb.Account.Api.V1.UserController delete_api_key [DELETE /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `0e26955f-5431-4652-84da-d08aded97a28`
            api_key: 0e26955f-5431-4652-84da-d08aded97a28


+ Request Delete api key
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/api_keys/0e26955f-5431-4652-84da-d08aded97a28`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMThkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIyQGJsb2Nrc2NvdXQuY29tZAACaWRh62QABG5hbWVtAAAAC1VzZXIgVGVzdDE4ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE4ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE4ZAAMd2F0Y2hsaXN0X2lkYes.NYp71-Be73f-HTquq2QWWCa70c169Rd9GXDOOSCdC34; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvMpP3rEvHcAAAei
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
              "name": "test26",
              "contract_address_hash": "0x0000000000000000000000000000000000000089",
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjNkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTM3QGJsb2Nrc2NvdXQuY29tZAACaWRh8GQABG5hbWVtAAAAC1VzZXIgVGVzdDIzZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIzZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIzZAAMd2F0Y2hsaXN0X2lkYfA.EgDkDw8R9zBMVjqsTcEWr77klYQVx6QOCcxXyN7EAqg; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvk62Sj0d-gAAArC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test26",
              "id": 161,
              "contract_address_hash": "0x0000000000000000000000000000000000000089",
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
              "name": "test15",
              "contract_address_hash": "0x0000000000000000000000000000000000000010",
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMWQABWVtYWlsbQAAABp0ZXN0X3VzZXItMUBibG9ja3Njb3V0LmNvbWQAAmlkYdpkAARuYW1lbQAAAApVc2VyIFRlc3QxZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjFkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMWQADHdhdGNobGlzdF9pZGHa.ynGrz6gad7RIkTh1lopco9xXNhiI-y6Bm6ecAnv3Usg; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gt5BIL0fpssAABCB
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMWQABWVtYWlsbQAAABp0ZXN0X3VzZXItMUBibG9ja3Njb3V0LmNvbWQAAmlkYdpkAARuYW1lbQAAAApVc2VyIFRlc3QxZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjFkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMWQADHdhdGNobGlzdF9pZGHa.ynGrz6gad7RIkTh1lopco9xXNhiI-y6Bm6ecAnv3Usg; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gt5U3pwfpssAABCh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "test14",
                "id": 159,
                "contract_address_hash": "0x000000000000000000000000000000000000000f",
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
                "id": 158,
                "contract_address_hash": "0x000000000000000000000000000000000000000e",
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
                "id": 157,
                "contract_address_hash": "0x000000000000000000000000000000000000000d",
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
                "id": 156,
                "contract_address_hash": "0x000000000000000000000000000000000000000c",
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
                "id": 155,
                "contract_address_hash": "0x000000000000000000000000000000000000000b",
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
                "id": 154,
                "contract_address_hash": "0x000000000000000000000000000000000000000a",
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
                "id": 153,
                "contract_address_hash": "0x0000000000000000000000000000000000000009",
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
                "id": 152,
                "contract_address_hash": "0x0000000000000000000000000000000000000008",
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
                "id": 151,
                "contract_address_hash": "0x0000000000000000000000000000000000000007",
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
                "id": 150,
                "contract_address_hash": "0x0000000000000000000000000000000000000006",
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
                "id": 149,
                "contract_address_hash": "0x0000000000000000000000000000000000000005",
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
                "name": "test3",
                "id": 148,
                "contract_address_hash": "0x0000000000000000000000000000000000000004",
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
                "name": "test2",
                "id": 147,
                "contract_address_hash": "0x0000000000000000000000000000000000000003",
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
                "name": "test1",
                "id": 146,
                "contract_address_hash": "0x0000000000000000000000000000000000000002",
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
                "name": "test0",
                "id": 145,
                "contract_address_hash": "0x0000000000000000000000000000000000000001",
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
    + id: `160`
            id: 160


+ Request Edit custom abi
**PUT**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/160`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test23",
              "contract_address_hash": "0x0000000000000000000000000000000000000046",
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
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTNkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE3QGJsb2Nrc2NvdXQuY29tZAACaWRh5mQABG5hbWVtAAAAC1VzZXIgVGVzdDEzZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjEzZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDEzZAAMd2F0Y2hsaXN0X2lkYeY.sl0nMtxBkMGt3aK7ohM3AYMcNEI-l37Xvqvl9qZ2Tso; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gu0y0bFQlB0AAAbi
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test23",
              "id": 160,
              "contract_address_hash": "0x0000000000000000000000000000000000000046",
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
    + id: `162`
            id: 162


+ Request Delete custom abi
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/162`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjRkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTM4QGJsb2Nrc2NvdXQuY29tZAACaWRh8WQABG5hbWVtAAAAC1VzZXIgVGVzdDI0ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjI0ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDI0ZAAMd2F0Y2hsaXN0X2lkYfE.i0XOrEfBULTfd08Ig4nhy_veB1sWxl2UWYT9kkveABw; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvnkpEhLN3QAACMB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_public_tags_request [POST /api/account/v1/user/public_tags]


 


+ Request Submit request to add a public tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/public_tags`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "website": "website3",
              "tags": "Tag5;Tag6",
              "is_owner": false,
              "full_name": "full name3",
              "email": "test_user-16@blockscout.com",
              "company": "company3",
              "addresses": [
                "0x000000000000000000000000000000000000003b",
                "0x000000000000000000000000000000000000003c",
                "0x000000000000000000000000000000000000003d",
                "0x000000000000000000000000000000000000003e",
                "0x000000000000000000000000000000000000003f",
                "0x0000000000000000000000000000000000000040",
                "0x0000000000000000000000000000000000000041",
                "0x0000000000000000000000000000000000000042",
                "0x0000000000000000000000000000000000000043",
                "0x0000000000000000000000000000000000000044"
              ],
              "additional_comment": "additional_comment3"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTJkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE1QGJsb2Nrc2NvdXQuY29tZAACaWRh5WQABG5hbWVtAAAAC1VzZXIgVGVzdDEyZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjEyZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDEyZAAMd2F0Y2hsaXN0X2lkYeU.8B0VERlCeTBlp1w0Zys_ZGaVIKj0VYi6pV2wMnCjeac; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1guxmyw_F-rUAAATj
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "website": "website3",
              "tags": "Tag5;Tag6",
              "submission_date": "2022-09-03T21:02:22.651943Z",
              "is_owner": false,
              "id": 146,
              "full_name": "full name3",
              "email": "test_user-16@blockscout.com",
              "company": "company3",
              "addresses": [
                "0x000000000000000000000000000000000000003b",
                "0x000000000000000000000000000000000000003c",
                "0x000000000000000000000000000000000000003d",
                "0x000000000000000000000000000000000000003e",
                "0x000000000000000000000000000000000000003f",
                "0x0000000000000000000000000000000000000040",
                "0x0000000000000000000000000000000000000041",
                "0x0000000000000000000000000000000000000042",
                "0x0000000000000000000000000000000000000043",
                "0x0000000000000000000000000000000000000044"
              ],
              "additional_comment": "additional_comment3"
            }
### BlockScoutWeb.Account.Api.V1.UserController public_tags_requests [GET /api/account/v1/user/public_tags]


 


+ Request Get list of requests to add a public tag
**GET**&nbsp;&nbsp;`/api/account/v1/user/public_tags`


+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjJkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI2QGJsb2Nrc2NvdXQuY29tZAACaWRh72QABG5hbWVtAAAAC1VzZXIgVGVzdDIyZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIyZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIyZAAMd2F0Y2hsaXN0X2lkYe8.oZY96LW6ZLfw1aK-C5TYkrK2GRNQEJCapnUSkd5OjXU; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvdQvQ8r6iIAAAki
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "website": "website13",
                "tags": "Tag18;Tag19",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": false,
                "id": 156,
                "full_name": "full name13",
                "email": "test_user-36@blockscout.com",
                "company": "company13",
                "addresses": [
                  "0x0000000000000000000000000000000000000084",
                  "0x0000000000000000000000000000000000000085",
                  "0x0000000000000000000000000000000000000086",
                  "0x0000000000000000000000000000000000000087",
                  "0x0000000000000000000000000000000000000088"
                ],
                "additional_comment": "additional_comment13"
              },
              {
                "website": "website12",
                "tags": "Tag17",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": true,
                "id": 155,
                "full_name": "full name12",
                "email": "test_user-35@blockscout.com",
                "company": "company12",
                "addresses": [
                  "0x0000000000000000000000000000000000000083"
                ],
                "additional_comment": "additional_comment12"
              },
              {
                "website": "website11",
                "tags": "Tag16",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": false,
                "id": 154,
                "full_name": "full name11",
                "email": "test_user-34@blockscout.com",
                "company": "company11",
                "addresses": [
                  "0x000000000000000000000000000000000000007b",
                  "0x000000000000000000000000000000000000007c",
                  "0x000000000000000000000000000000000000007d",
                  "0x000000000000000000000000000000000000007e",
                  "0x000000000000000000000000000000000000007f",
                  "0x0000000000000000000000000000000000000080",
                  "0x0000000000000000000000000000000000000081",
                  "0x0000000000000000000000000000000000000082"
                ],
                "additional_comment": "additional_comment11"
              },
              {
                "website": "website10",
                "tags": "Tag15",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": false,
                "id": 153,
                "full_name": "full name10",
                "email": "test_user-33@blockscout.com",
                "company": "company10",
                "addresses": [
                  "0x0000000000000000000000000000000000000073",
                  "0x0000000000000000000000000000000000000074",
                  "0x0000000000000000000000000000000000000075",
                  "0x0000000000000000000000000000000000000076",
                  "0x0000000000000000000000000000000000000077",
                  "0x0000000000000000000000000000000000000078",
                  "0x0000000000000000000000000000000000000079",
                  "0x000000000000000000000000000000000000007a"
                ],
                "additional_comment": "additional_comment10"
              },
              {
                "website": "website9",
                "tags": "Tag14",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": false,
                "id": 152,
                "full_name": "full name9",
                "email": "test_user-32@blockscout.com",
                "company": "company9",
                "addresses": [
                  "0x000000000000000000000000000000000000006d",
                  "0x000000000000000000000000000000000000006e",
                  "0x000000000000000000000000000000000000006f",
                  "0x0000000000000000000000000000000000000070",
                  "0x0000000000000000000000000000000000000071",
                  "0x0000000000000000000000000000000000000072"
                ],
                "additional_comment": "additional_comment9"
              },
              {
                "website": "website8",
                "tags": "Tag13",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": false,
                "id": 151,
                "full_name": "full name8",
                "email": "test_user-31@blockscout.com",
                "company": "company8",
                "addresses": [
                  "0x0000000000000000000000000000000000000064",
                  "0x0000000000000000000000000000000000000065",
                  "0x0000000000000000000000000000000000000066",
                  "0x0000000000000000000000000000000000000067",
                  "0x0000000000000000000000000000000000000068",
                  "0x0000000000000000000000000000000000000069",
                  "0x000000000000000000000000000000000000006a",
                  "0x000000000000000000000000000000000000006b",
                  "0x000000000000000000000000000000000000006c"
                ],
                "additional_comment": "additional_comment8"
              },
              {
                "website": "website7",
                "tags": "Tag11;Tag12",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": true,
                "id": 150,
                "full_name": "full name7",
                "email": "test_user-30@blockscout.com",
                "company": "company7",
                "addresses": [
                  "0x0000000000000000000000000000000000000063"
                ],
                "additional_comment": "additional_comment7"
              },
              {
                "website": "website6",
                "tags": "Tag9;Tag10",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": false,
                "id": 149,
                "full_name": "full name6",
                "email": "test_user-29@blockscout.com",
                "company": "company6",
                "addresses": [
                  "0x0000000000000000000000000000000000000060",
                  "0x0000000000000000000000000000000000000061",
                  "0x0000000000000000000000000000000000000062"
                ],
                "additional_comment": "additional_comment6"
              },
              {
                "website": "website5",
                "tags": "Tag8",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": true,
                "id": 148,
                "full_name": "full name5",
                "email": "test_user-28@blockscout.com",
                "company": "company5",
                "addresses": [
                  "0x000000000000000000000000000000000000005e",
                  "0x000000000000000000000000000000000000005f"
                ],
                "additional_comment": "additional_comment5"
              },
              {
                "website": "website4",
                "tags": "Tag7",
                "submission_date": "2022-09-03T21:02:23.000000Z",
                "is_owner": false,
                "id": 147,
                "full_name": "full name4",
                "email": "test_user-27@blockscout.com",
                "company": "company4",
                "addresses": [
                  "0x000000000000000000000000000000000000005b",
                  "0x000000000000000000000000000000000000005c",
                  "0x000000000000000000000000000000000000005d"
                ],
                "additional_comment": "additional_comment4"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_public_tags_request [DELETE /api/account/v1/user/public_tags/{id}]


 

+ Parameters
    + id: `156`
            id: 156


+ Request Delete public tags request
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/public_tags/156`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "remove_reason": "reason"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjJkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI2QGJsb2Nrc2NvdXQuY29tZAACaWRh72QABG5hbWVtAAAAC1VzZXIgVGVzdDIyZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIyZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIyZAAMd2F0Y2hsaXN0X2lkYe8.oZY96LW6ZLfw1aK-C5TYkrK2GRNQEJCapnUSkd5OjXU; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1gvdm8H0r6iIAAAlC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController update_public_tags_request [PUT /api/account/v1/user/public_tags/{id}]


 

+ Parameters
    + id: `145`
            id: 145


+ Request Edit request to add a public tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/public_tags/145`

    + Headers
    
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "website": "website2",
              "tags": "Tag3;Tag4",
              "is_owner": false,
              "full_name": "full name2",
              "email": "test_user-12@blockscout.com",
              "company": "company2",
              "addresses": [
                "0x000000000000000000000000000000000000002f",
                "0x0000000000000000000000000000000000000030",
                "0x0000000000000000000000000000000000000031",
                "0x0000000000000000000000000000000000000032",
                "0x0000000000000000000000000000000000000033",
                "0x0000000000000000000000000000000000000034",
                "0x0000000000000000000000000000000000000035",
                "0x0000000000000000000000000000000000000036",
                "0x0000000000000000000000000000000000000037"
              ],
              "additional_comment": "additional_comment2"
            }

+ Response 200

    + Headers
    
            set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyOWQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTBAYmxvY2tzY291dC5jb21kAAJpZGHiZAAEbmFtZW0AAAAKVXNlciBUZXN0OWQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI5ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDlkAAx3YXRjaGxpc3RfaWRh4g.cM2caeO_bvTyojrTAKD7Tt4WEPEIsHwTMmWkTEVgSLo; path=/; HttpOnly
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FxF1guqVaODqqc8AAAUi
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "website": "website2",
              "tags": "Tag3;Tag4",
              "submission_date": "2022-09-03T21:02:23.000000Z",
              "is_owner": false,
              "id": 145,
              "full_name": "full name2",
              "email": "test_user-12@blockscout.com",
              "company": "company2",
              "addresses": [
                "0x000000000000000000000000000000000000002f",
                "0x0000000000000000000000000000000000000030",
                "0x0000000000000000000000000000000000000031",
                "0x0000000000000000000000000000000000000032",
                "0x0000000000000000000000000000000000000033",
                "0x0000000000000000000000000000000000000034",
                "0x0000000000000000000000000000000000000035",
                "0x0000000000000000000000000000000000000036",
                "0x0000000000000000000000000000000000000037"
              ],
              "additional_comment": "additional_comment2"
            }

