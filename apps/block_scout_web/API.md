# API Documentation

  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [info](#blockscoutweb-account-api-v1-usercontroller-info)
    * [create_tag_address](#blockscoutweb-account-api-v1-usercontroller-create_tag_address)
  * [BlockScoutWeb.Account.Api.V1.TagsController](#blockscoutweb-account-api-v1-tagscontroller)
    * [tags_address](#blockscoutweb-account-api-v1-tagscontroller-tags_address)
  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [update_tag_address](#blockscoutweb-account-api-v1-usercontroller-update_tag_address)
    * [tags_address](#blockscoutweb-account-api-v1-usercontroller-tags_address)
    * [delete_tag_address](#blockscoutweb-account-api-v1-usercontroller-delete_tag_address)
    * [create_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-create_tag_transaction)
  * [BlockScoutWeb.Account.Api.V1.TagsController](#blockscoutweb-account-api-v1-tagscontroller)
    * [tags_transaction](#blockscoutweb-account-api-v1-tagscontroller-tags_transaction)
  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [update_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-update_tag_transaction)
    * [tags_transaction](#blockscoutweb-account-api-v1-usercontroller-tags_transaction)
    * [delete_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-delete_tag_transaction)
    * [create_watchlist](#blockscoutweb-account-api-v1-usercontroller-create_watchlist)
    * [watchlist](#blockscoutweb-account-api-v1-usercontroller-watchlist)
    * [delete_watchlist](#blockscoutweb-account-api-v1-usercontroller-delete_watchlist)
    * [update_watchlist](#blockscoutweb-account-api-v1-usercontroller-update_watchlist)
    * [create_watchlist](#blockscoutweb-account-api-v1-usercontroller-create_watchlist)
    * [update_watchlist](#blockscoutweb-account-api-v1-usercontroller-update_watchlist)
    * [create_api_key](#blockscoutweb-account-api-v1-usercontroller-create_api_key)
    * [api_keys](#blockscoutweb-account-api-v1-usercontroller-api_keys)
    * [update_api_key](#blockscoutweb-account-api-v1-usercontroller-update_api_key)
    * [delete_api_key](#blockscoutweb-account-api-v1-usercontroller-delete_api_key)
    * [create_custom_abi](#blockscoutweb-account-api-v1-usercontroller-create_custom_abi)
    * [custom_abis](#blockscoutweb-account-api-v1-usercontroller-custom_abis)
    * [update_custom_abi](#blockscoutweb-account-api-v1-usercontroller-update_custom_abi)
    * [delete_custom_abi](#blockscoutweb-account-api-v1-usercontroller-delete_custom_abi)
    * [create_public_tags_request](#blockscoutweb-account-api-v1-usercontroller-create_public_tags_request)
    * [public_tags_requests](#blockscoutweb-account-api-v1-usercontroller-public_tags_requests)
    * [delete_public_tags_request](#blockscoutweb-account-api-v1-usercontroller-delete_public_tags_request)
    * [update_public_tags_request](#blockscoutweb-account-api-v1-usercontroller-update_public_tags_request)

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-info></a>info
#### Get info about user

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/info

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNGQABWVtYWlsbQAAABp0ZXN0X3VzZXItNEBibG9ja3Njb3V0LmNvbWQAAmlkYcRkAARuYW1lbQAAAApVc2VyIFRlc3Q0ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjRkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwNGQADHdhdGNobGlzdF9pZGHE.Ovcc2Vzzv4fhFzmirtQjJ06gcqQwUHMMlju7VX24fyo; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y1_QfU9-YaIAAGdh
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "nickname": "test_user4",
  "name": "User Test4",
  "email": "test_user-4@blockscout.com",
  "avatar": "https://example.com/avatar/test_user4"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_address></a>create_tag_address
#### Add private address tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "MyName",
  "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMThkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIyQGJsb2Nrc2NvdXQuY29tZAACaWRh0mQABG5hbWVtAAAAC1VzZXIgVGVzdDE4ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE4ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE4ZAAMd2F0Y2hsaXN0X2lkYdI.tFFJ387fBBdBFuMzzeaWcMTeapzMHnbuEfnqTdq5lJ8; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3ALw8xSCMAAAHAC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "MyName",
  "id": 61,
  "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
}
```

## BlockScoutWeb.Account.Api.V1.TagsController
### <a id=blockscoutweb-account-api-v1-tagscontroller-tags_address></a>tags_address
#### Get tags for address

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMThkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIyQGJsb2Nrc2NvdXQuY29tZAACaWRh0mQABG5hbWVtAAAAC1VzZXIgVGVzdDE4ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE4ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE4ZAAMd2F0Y2hsaXN0X2lkYdI.tFFJ387fBBdBFuMzzeaWcMTeapzMHnbuEfnqTdq5lJ8; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3BIWjdSCMAAAG4B
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
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
```

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-update_tag_address></a>update_tag_address
#### Edit private address tag

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/tags/address/57
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "name3",
  "address_hash": "0x0000000000000000000000000000000000000016"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyN2QABWVtYWlsbQAAABt0ZXN0X3VzZXItMTBAYmxvY2tzY291dC5jb21kAAJpZGHHZAAEbmFtZW0AAAAKVXNlciBUZXN0N2QACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI3ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDdkAAx3YXRjaGxpc3RfaWRhxw.Bn03yTZrlP0m6amYLQVeI-pvhvUf1F6d9SGAkDTLEck; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2IdgOjzsTkAAGYC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "name3",
  "id": 57,
  "address_hash": "0x0000000000000000000000000000000000000016"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_address></a>tags_address
#### Get private addresses tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/address

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTVkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE5QGJsb2Nrc2NvdXQuY29tZAACaWRhz2QABG5hbWVtAAAAC1VzZXIgVGVzdDE1ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE1ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE1ZAAMd2F0Y2hsaXN0X2lkYc8.AoYBq7uUH9JOt11vL4-71qtsXMzpPDFsx8BV97n1Y-o; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2ynKDFWAsYAAG5C
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "name": "name2",
    "id": 60,
    "address_hash": "0x000000000000000000000000000000000000003f"
  },
  {
    "name": "name1",
    "id": 59,
    "address_hash": "0x000000000000000000000000000000000000003e"
  },
  {
    "name": "name0",
    "id": 58,
    "address_hash": "0x000000000000000000000000000000000000003d"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_address></a>delete_tag_address
#### Delete private address tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/address/62

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjRkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTM4QGJsb2Nrc2NvdXQuY29tZAACaWRh2GQABG5hbWVtAAAAC1VzZXIgVGVzdDI0ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjI0ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDI0ZAAMd2F0Y2hsaXN0X2lkYdg.x6Qf5zC5gCGQrKy2MbTqd3Xt7S_2oUYaCnO-pbZwRMI; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3biZmVZE0MAAHKC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_transaction></a>create_tag_transaction
#### Error on try to create private transaction tag for tx does not exist

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000008",
  "name": "MyName"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTlkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIzQGJsb2Nrc2NvdXQuY29tZAACaWRh02QABG5hbWVtAAAAC1VzZXIgVGVzdDE5ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE5ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE5ZAAMd2F0Y2hsaXN0X2lkYdM.zuwR-sOIcF7Xpo97W6G9Szzi_BPlu6Pu9_4kn7T2c10; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3DXWVBu-HUAAG6h
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "errors": {
    "tx_hash": [
      "Transaction does not exist"
    ]
  }
}
```

#### Create private transaction tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
  "name": "MyName"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTlkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIzQGJsb2Nrc2NvdXQuY29tZAACaWRh02QABG5hbWVtAAAAC1VzZXIgVGVzdDE5ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE5ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE5ZAAMd2F0Y2hsaXN0X2lkYdM.zuwR-sOIcF7Xpo97W6G9Szzi_BPlu6Pu9_4kn7T2c10; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3EB0Ytu-HUAAG7B
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
  "name": "MyName",
  "id": 64
}
```

## BlockScoutWeb.Account.Api.V1.TagsController
### <a id=blockscoutweb-account-api-v1-tagscontroller-tags_transaction></a>tags_transaction
#### Get tags for transaction

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000009

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTlkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIzQGJsb2Nrc2NvdXQuY29tZAACaWRh02QABG5hbWVtAAAAC1VzZXIgVGVzdDE5ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE5ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE5ZAAMd2F0Y2hsaXN0X2lkYdM.zuwR-sOIcF7Xpo97W6G9Szzi_BPlu6Pu9_4kn7T2c10; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3Efe0tu-HUAAG7h
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "watchlist_names": [],
  "personal_tx_tag": {
    "label": "MyName"
  },
  "personal_tags": [],
  "common_tags": []
}
```

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-update_tag_transaction></a>update_tag_transaction
#### Edit private transaction tag

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/tags/transaction/57
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
  "name": "name1"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMGQABWVtYWlsbQAAABp0ZXN0X3VzZXItMEBibG9ja3Njb3V0LmNvbWQAAmlkYcBkAARuYW1lbQAAAApVc2VyIFRlc3QwZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjBkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMGQADHdhdGNobGlzdF9pZGHA.-aMP6TTEeEfxopoeChJPvTvjkSRD9_ZgaeLDlOC21gU; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y1xoENHeIlkAAGEi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
  "name": "name1",
  "id": 57
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_transaction></a>tags_transaction
#### Get private transactions tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/transaction

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTRkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE4QGJsb2Nrc2NvdXQuY29tZAACaWRhzmQABG5hbWVtAAAAC1VzZXIgVGVzdDE0ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE0ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE0ZAAMd2F0Y2hsaXN0X2lkYc4.8SGhlMOY4aB444Afz1VajofmGp9YZbrfbVkZ4BTyaBI; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2tEsVp5P30AAGzi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000004",
    "name": "name2",
    "id": 60
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000003",
    "name": "name1",
    "id": 59
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000002",
    "name": "name0",
    "id": 58
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_transaction></a>delete_tag_transaction
#### Delete private transaction tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/transaction/61

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTZkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIwQGJsb2Nrc2NvdXQuY29tZAACaWRh0GQABG5hbWVtAAAAC1VzZXIgVGVzdDE2ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE2ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE2ZAAMd2F0Y2hsaXN0X2lkYdA.YfL9L7-UIBleRbWWhHNvutNuw8Y4SadvwGFmGwakxQA; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y26c9UuC4TcAAGwh
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_watchlist></a>create_watchlist
#### Add address to watch list

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test2",
  "address_hash": "0x0000000000000000000000000000000000000007"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyM2QABWVtYWlsbQAAABp0ZXN0X3VzZXItM0BibG9ja3Njb3V0LmNvbWQAAmlkYcNkAARuYW1lbQAAAApVc2VyIFRlc3QzZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjNkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwM2QADHdhdGNobGlzdF9pZGHD.kv5nnz8sVGLaopoZs9ppOfu0hfpFi58yuisPDN6PtPI; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y16Kv_0GzWcAAGKi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test2",
  "id": 68,
  "exchange_rate": null,
  "address_hash": "0x0000000000000000000000000000000000000007",
  "address_balance": null
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-watchlist></a>watchlist
#### Get addresses from watchlists

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/watchlist

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyM2QABWVtYWlsbQAAABp0ZXN0X3VzZXItM0BibG9ja3Njb3V0LmNvbWQAAmlkYcNkAARuYW1lbQAAAApVc2VyIFRlc3QzZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjNkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwM2QADHdhdGNobGlzdF9pZGHD.kv5nnz8sVGLaopoZs9ppOfu0hfpFi58yuisPDN6PtPI; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y19FyIUGzWcAAGMC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
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
        "incoming": false
      }
    },
    "notification_methods": {
      "email": false
    },
    "name": "test3",
    "id": 69,
    "exchange_rate": null,
    "address_hash": "0x0000000000000000000000000000000000000008",
    "address_balance": null
  },
  {
    "notification_settings": {
      "native": {
        "outcoming": false,
        "incoming": true
      },
      "ERC-721": {
        "outcoming": false,
        "incoming": true
      },
      "ERC-20": {
        "outcoming": false,
        "incoming": false
      }
    },
    "notification_methods": {
      "email": true
    },
    "name": "test2",
    "id": 68,
    "exchange_rate": null,
    "address_hash": "0x0000000000000000000000000000000000000007",
    "address_balance": null
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_watchlist></a>delete_watchlist
#### Delete address from watchlist by id

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/watchlist/74

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTFkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE0QGJsb2Nrc2NvdXQuY29tZAACaWRhy2QABG5hbWVtAAAAC1VzZXIgVGVzdDExZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjExZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDExZAAMd2F0Y2hsaXN0X2lkYcs.YjW8nzuA66id0ADg2qpyjTMGfKJ7BHhjU_HdVq8w8vk; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2f5j2WpY30AAGuC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_watchlist></a>update_watchlist
#### Edit watchlist address

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/watchlist/67
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test1",
  "address_hash": "0x0000000000000000000000000000000000000006"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMWQABWVtYWlsbQAAABp0ZXN0X3VzZXItMUBibG9ja3Njb3V0LmNvbWQAAmlkYcFkAARuYW1lbQAAAApVc2VyIFRlc3QxZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjFkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMWQADHdhdGNobGlzdF9pZGHB.3KOkZkPrcMrRXfooQckn-zi6xmax1LJMBGBSjmGM8ww; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y12FoNKu97sAAGch
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test1",
  "id": 67,
  "exchange_rate": null,
  "address_hash": "0x0000000000000000000000000000000000000006",
  "address_balance": null
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_watchlist></a>create_watchlist
#### Example of error on creating watchlist address

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": false,
      "incoming": false
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test4",
  "address_hash": "0x0000000000000000000000000000000000000017"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyOGQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTFAYmxvY2tzY291dC5jb21kAAJpZGHIZAAEbmFtZW0AAAAKVXNlciBUZXN0OGQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI4ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDhkAAx3YXRjaGxpc3RfaWRhyA.q1Rmte0qLd31GbmpA46bE8rXo2okwzX8aD_oDHn8CIQ; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2MCqHvooPMAAGbi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "errors": {
    "watchlist_id": [
      "Address already added to the watch list"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_watchlist></a>update_watchlist
#### Example of error on editing watchlist address

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/watchlist/72
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": false,
      "incoming": false
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test4",
  "address_hash": "0x0000000000000000000000000000000000000017"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyOGQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTFAYmxvY2tzY291dC5jb21kAAJpZGHIZAAEbmFtZW0AAAAKVXNlciBUZXN0OGQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI4ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDhkAAx3YXRjaGxpc3RfaWRhyA.q1Rmte0qLd31GbmpA46bE8rXo2okwzX8aD_oDHn8CIQ; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2Nh1eHooPMAAGci
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "errors": {
    "watchlist_id": [
      "Address already added to the watch list"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_api_key></a>create_api_key
#### Add api key

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/api_keys
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMmQABWVtYWlsbQAAABp0ZXN0X3VzZXItMkBibG9ja3Njb3V0LmNvbWQAAmlkYcJkAARuYW1lbQAAAApVc2VyIFRlc3QyZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjJkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwMmQADHdhdGNobGlzdF9pZGHC.ULESD1_sOySz8eEVGnagUzGw6eMIx_8Pwoyr_5S3K0M; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y14XlMBqXaQAAGHi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test",
  "api_key": "de9ef457-3f47-48d3-affa-79ad9d3b27b9"
}
```

#### Example of error on creating api key

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/api_keys
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjJkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI2QGJsb2Nrc2NvdXQuY29tZAACaWRh1mQABG5hbWVtAAAAC1VzZXIgVGVzdDIyZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIyZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIyZAAMd2F0Y2hsaXN0X2lkYdY.P37J2lZZdHaT4P-RatVaXCx77UcSH3s_TMx-FieaYk0; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3LmuuofZKYAAG_h
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "errors": {
    "name": [
      "Max 3 keys per account"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-api_keys></a>api_keys
#### Get api keys list

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/api_keys

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjJkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI2QGJsb2Nrc2NvdXQuY29tZAACaWRh1mQABG5hbWVtAAAAC1VzZXIgVGVzdDIyZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIyZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIyZAAMd2F0Y2hsaXN0X2lkYdY.P37J2lZZdHaT4P-RatVaXCx77UcSH3s_TMx-FieaYk0; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3LyOSIfZKYAAHAB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "name": "test",
    "api_key": "2ac16688-34e6-4fa4-8983-a9bc34c912f6"
  },
  {
    "name": "test",
    "api_key": "a55426db-04f0-40be-a146-1ced4558aa0c"
  },
  {
    "name": "test",
    "api_key": "d73fc23b-59f0-4e6f-a739-f4de30995101"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_api_key></a>update_api_key
#### Edit api key

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/api_keys/2b1d400d-713e-4bfc-8ef0-710555693138
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test_1"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTdkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTIxQGJsb2Nrc2NvdXQuY29tZAACaWRh0WQABG5hbWVtAAAAC1VzZXIgVGVzdDE3ZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjE3ZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDE3ZAAMd2F0Y2hsaXN0X2lkYdE.bLJKM3-kFm04mMC-4-3b2mjrig_lmQYt5C2tg-9q9so; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2-0eR7T2BMAAG0B
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test_1",
  "api_key": "2b1d400d-713e-4bfc-8ef0-710555693138"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_api_key></a>delete_api_key
#### Delete api key

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/api_keys/3bd44c0d-290f-4dfc-9283-5f674080f8ef

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjBkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI0QGJsb2Nrc2NvdXQuY29tZAACaWRh1GQABG5hbWVtAAAAC1VzZXIgVGVzdDIwZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIwZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIwZAAMd2F0Y2hsaXN0X2lkYdQ.WgjMmOxwwBGcTZZscpLA8EXErwL8ITCvoIXPLIQAhtw; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3HQdpa0710AAHBi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_custom_abi></a>create_custom_abi
#### Add custom abi

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/custom_abis
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test25",
  "contract_address_hash": "0x000000000000000000000000000000000000002c",
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
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTJkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTE1QGJsb2Nrc2NvdXQuY29tZAACaWRhzGQABG5hbWVtAAAAC1VzZXIgVGVzdDEyZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjEyZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDEyZAAMd2F0Y2hsaXN0X2lkYcw.7cCOt6SVrOb5VLYplBzwZ03FWMo9jQpAV7cNroY4txY; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2iZJWbZgfgAAGwC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test25",
  "id": 143,
  "contract_address_hash": "0x000000000000000000000000000000000000002c",
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
```

#### Example of error on creating custom abi

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/custom_abis
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test21",
  "contract_address_hash": "0x0000000000000000000000000000000000000028",
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
```

##### Response
* __Status__: 422
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyOWQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTJAYmxvY2tzY291dC5jb21kAAJpZGHJZAAEbmFtZW0AAAAKVXNlciBUZXN0OWQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI5ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDlkAAx3YXRjaGxpc3RfaWRhyQ.MCpJsS-nb95ccHRtzOk7DbIRjEcTG34ONq4PrC5hOcU; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2Ypm-ny0swAAGiB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "errors": {
    "name": [
      "Max 15 ABIs per account"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-custom_abis></a>custom_abis
#### Get custom abis list

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/custom_abis

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyOWQABWVtYWlsbQAAABt0ZXN0X3VzZXItMTJAYmxvY2tzY291dC5jb21kAAJpZGHJZAAEbmFtZW0AAAAKVXNlciBUZXN0OWQACG5pY2tuYW1lbQAAAAp0ZXN0X3VzZXI5ZAADdWlkbQAAAA9ibG9ja3Njb3V0fDAwMDlkAAx3YXRjaGxpc3RfaWRhyQ.MCpJsS-nb95ccHRtzOk7DbIRjEcTG34ONq4PrC5hOcU; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2Y-qjXy0swAAGnC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "name": "test20",
    "id": 141,
    "contract_address_hash": "0x0000000000000000000000000000000000000027",
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
    "name": "test19",
    "id": 140,
    "contract_address_hash": "0x0000000000000000000000000000000000000026",
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
    "name": "test18",
    "id": 139,
    "contract_address_hash": "0x0000000000000000000000000000000000000025",
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
    "id": 138,
    "contract_address_hash": "0x0000000000000000000000000000000000000024",
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
    "id": 137,
    "contract_address_hash": "0x0000000000000000000000000000000000000023",
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
    "id": 136,
    "contract_address_hash": "0x0000000000000000000000000000000000000022",
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
    "id": 135,
    "contract_address_hash": "0x0000000000000000000000000000000000000021",
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
    "id": 134,
    "contract_address_hash": "0x0000000000000000000000000000000000000020",
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
    "id": 133,
    "contract_address_hash": "0x000000000000000000000000000000000000001f",
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
    "id": 132,
    "contract_address_hash": "0x000000000000000000000000000000000000001e",
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
    "id": 131,
    "contract_address_hash": "0x000000000000000000000000000000000000001d",
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
    "id": 130,
    "contract_address_hash": "0x000000000000000000000000000000000000001c",
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
    "id": 129,
    "contract_address_hash": "0x000000000000000000000000000000000000001b",
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
    "id": 128,
    "contract_address_hash": "0x000000000000000000000000000000000000001a",
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
    "id": 127,
    "contract_address_hash": "0x0000000000000000000000000000000000000019",
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
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_custom_abi></a>update_custom_abi
#### Edit custom abi

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/custom_abis/144
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test27",
  "contract_address_hash": "0x000000000000000000000000000000000000004b",
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
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjFkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI1QGJsb2Nrc2NvdXQuY29tZAACaWRh1WQABG5hbWVtAAAAC1VzZXIgVGVzdDIxZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIxZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIxZAAMd2F0Y2hsaXN0X2lkYdU.SEUqq9ZiSD79HIzwKvwTspmBKKU87m_Xwu5gw2pX1e0; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3JcHmB4X2AAAHDC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test27",
  "id": 144,
  "contract_address_hash": "0x000000000000000000000000000000000000004b",
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
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_custom_abi></a>delete_custom_abi
#### Delete custom abi

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/custom_abis/142

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMTBkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTEzQGJsb2Nrc2NvdXQuY29tZAACaWRhymQABG5hbWVtAAAAC1VzZXIgVGVzdDEwZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjEwZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDEwZAAMd2F0Y2hsaXN0X2lkYco.x_6dmEjpZ1o8_ct-M7pWWP0LkI66xhwl8gWeQt9XzHA; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2b1jJGBaO4AAGrC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_public_tags_request></a>create_public_tags_request
#### Submit request to add a public tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/public_tags
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "website": "website0",
  "tags": "Tag0",
  "is_owner": true,
  "full_name": "full name0",
  "email": "test_user-6@blockscout.com",
  "company": "company0",
  "addresses": [
    "0x0000000000000000000000000000000000000009",
    "0x000000000000000000000000000000000000000a",
    "0x000000000000000000000000000000000000000b",
    "0x000000000000000000000000000000000000000c",
    "0x000000000000000000000000000000000000000d"
  ],
  "additional_comment": "additional_comment0"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNWQABWVtYWlsbQAAABp0ZXN0X3VzZXItNUBibG9ja3Njb3V0LmNvbWQAAmlkYcVkAARuYW1lbQAAAApVc2VyIFRlc3Q1ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjVkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwNWQADHdhdGNobGlzdF9pZGHF.kXAMBaL9a7aYjPDgZ9Llxe1etUCPH3vEvQe9Fq2May4; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2BIESA-ecUAAGgB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "website": "website0",
  "tags": "Tag0",
  "submission_date": "2022-09-03T21:00:07.156465Z",
  "is_owner": true,
  "id": 131,
  "full_name": "full name0",
  "email": "test_user-6@blockscout.com",
  "company": "company0",
  "addresses": [
    "0x0000000000000000000000000000000000000009",
    "0x000000000000000000000000000000000000000a",
    "0x000000000000000000000000000000000000000b",
    "0x000000000000000000000000000000000000000c",
    "0x000000000000000000000000000000000000000d"
  ],
  "additional_comment": "additional_comment0"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-public_tags_requests></a>public_tags_requests
#### Get list of requests to add a public tag

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/public_tags

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjNkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI3QGJsb2Nrc2NvdXQuY29tZAACaWRh12QABG5hbWVtAAAAC1VzZXIgVGVzdDIzZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIzZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIzZAAMd2F0Y2hsaXN0X2lkYdc._6gJnvzjA6VEztgoIdpp7chhmhsdFrJImlcdrp4-pW0; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3SaPVCdkicAAHIi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "website": "website13",
    "tags": "Tag17",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": false,
    "id": 143,
    "full_name": "full name13",
    "email": "test_user-37@blockscout.com",
    "company": "company13",
    "addresses": [
      "0x000000000000000000000000000000000000007e",
      "0x000000000000000000000000000000000000007f",
      "0x0000000000000000000000000000000000000080",
      "0x0000000000000000000000000000000000000081",
      "0x0000000000000000000000000000000000000082",
      "0x0000000000000000000000000000000000000083",
      "0x0000000000000000000000000000000000000084"
    ],
    "additional_comment": "additional_comment13"
  },
  {
    "website": "website12",
    "tags": "Tag16",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": false,
    "id": 142,
    "full_name": "full name12",
    "email": "test_user-36@blockscout.com",
    "company": "company12",
    "addresses": [
      "0x0000000000000000000000000000000000000075",
      "0x0000000000000000000000000000000000000076",
      "0x0000000000000000000000000000000000000077",
      "0x0000000000000000000000000000000000000078",
      "0x0000000000000000000000000000000000000079",
      "0x000000000000000000000000000000000000007a",
      "0x000000000000000000000000000000000000007b",
      "0x000000000000000000000000000000000000007c",
      "0x000000000000000000000000000000000000007d"
    ],
    "additional_comment": "additional_comment12"
  },
  {
    "website": "website11",
    "tags": "Tag15",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": false,
    "id": 141,
    "full_name": "full name11",
    "email": "test_user-35@blockscout.com",
    "company": "company11",
    "addresses": [
      "0x000000000000000000000000000000000000006d",
      "0x000000000000000000000000000000000000006e",
      "0x000000000000000000000000000000000000006f",
      "0x0000000000000000000000000000000000000070",
      "0x0000000000000000000000000000000000000071",
      "0x0000000000000000000000000000000000000072",
      "0x0000000000000000000000000000000000000073",
      "0x0000000000000000000000000000000000000074"
    ],
    "additional_comment": "additional_comment11"
  },
  {
    "website": "website10",
    "tags": "Tag14",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": false,
    "id": 140,
    "full_name": "full name10",
    "email": "test_user-34@blockscout.com",
    "company": "company10",
    "addresses": [
      "0x0000000000000000000000000000000000000067",
      "0x0000000000000000000000000000000000000068",
      "0x0000000000000000000000000000000000000069",
      "0x000000000000000000000000000000000000006a",
      "0x000000000000000000000000000000000000006b",
      "0x000000000000000000000000000000000000006c"
    ],
    "additional_comment": "additional_comment10"
  },
  {
    "website": "website9",
    "tags": "Tag13",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": true,
    "id": 139,
    "full_name": "full name9",
    "email": "test_user-33@blockscout.com",
    "company": "company9",
    "addresses": [
      "0x0000000000000000000000000000000000000061",
      "0x0000000000000000000000000000000000000062",
      "0x0000000000000000000000000000000000000063",
      "0x0000000000000000000000000000000000000064",
      "0x0000000000000000000000000000000000000065",
      "0x0000000000000000000000000000000000000066"
    ],
    "additional_comment": "additional_comment9"
  },
  {
    "website": "website8",
    "tags": "Tag12",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": false,
    "id": 138,
    "full_name": "full name8",
    "email": "test_user-32@blockscout.com",
    "company": "company8",
    "addresses": [
      "0x0000000000000000000000000000000000000060"
    ],
    "additional_comment": "additional_comment8"
  },
  {
    "website": "website7",
    "tags": "Tag11",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": true,
    "id": 137,
    "full_name": "full name7",
    "email": "test_user-31@blockscout.com",
    "company": "company7",
    "addresses": [
      "0x000000000000000000000000000000000000005f"
    ],
    "additional_comment": "additional_comment7"
  },
  {
    "website": "website6",
    "tags": "Tag9;Tag10",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": true,
    "id": 136,
    "full_name": "full name6",
    "email": "test_user-30@blockscout.com",
    "company": "company6",
    "addresses": [
      "0x000000000000000000000000000000000000005a",
      "0x000000000000000000000000000000000000005b",
      "0x000000000000000000000000000000000000005c",
      "0x000000000000000000000000000000000000005d",
      "0x000000000000000000000000000000000000005e"
    ],
    "additional_comment": "additional_comment6"
  },
  {
    "website": "website5",
    "tags": "Tag8",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": false,
    "id": 135,
    "full_name": "full name5",
    "email": "test_user-29@blockscout.com",
    "company": "company5",
    "addresses": [
      "0x0000000000000000000000000000000000000051",
      "0x0000000000000000000000000000000000000052",
      "0x0000000000000000000000000000000000000053",
      "0x0000000000000000000000000000000000000054",
      "0x0000000000000000000000000000000000000055",
      "0x0000000000000000000000000000000000000056",
      "0x0000000000000000000000000000000000000057",
      "0x0000000000000000000000000000000000000058",
      "0x0000000000000000000000000000000000000059"
    ],
    "additional_comment": "additional_comment5"
  },
  {
    "website": "website4",
    "tags": "Tag6;Tag7",
    "submission_date": "2022-09-03T21:00:07.000000Z",
    "is_owner": true,
    "id": 134,
    "full_name": "full name4",
    "email": "test_user-28@blockscout.com",
    "company": "company4",
    "addresses": [
      "0x000000000000000000000000000000000000004c",
      "0x000000000000000000000000000000000000004d",
      "0x000000000000000000000000000000000000004e",
      "0x000000000000000000000000000000000000004f",
      "0x0000000000000000000000000000000000000050"
    ],
    "additional_comment": "additional_comment4"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_public_tags_request></a>delete_public_tags_request
#### Delete public tags request

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/public_tags/143
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "remove_reason": "reason"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAmaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyMjNkAAVlbWFpbG0AAAAbdGVzdF91c2VyLTI3QGJsb2Nrc2NvdXQuY29tZAACaWRh12QABG5hbWVtAAAAC1VzZXIgVGVzdDIzZAAIbmlja25hbWVtAAAAC3Rlc3RfdXNlcjIzZAADdWlkbQAAABBibG9ja3Njb3V0fDAwMDIzZAAMd2F0Y2hsaXN0X2lkYdc._6gJnvzjA6VEztgoIdpp7chhmhsdFrJImlcdrp4-pW0; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y3SwObudkicAAHBB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_public_tags_request></a>update_public_tags_request
#### Edit request to add a public tag

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/public_tags/132
* __Request headers:__
```
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "website": "website2",
  "tags": "Tag2;Tag3",
  "is_owner": true,
  "full_name": "full name2",
  "email": "test_user-9@blockscout.com",
  "company": "company2",
  "addresses": [
    "0x000000000000000000000000000000000000000f",
    "0x0000000000000000000000000000000000000010",
    "0x0000000000000000000000000000000000000011",
    "0x0000000000000000000000000000000000000012",
    "0x0000000000000000000000000000000000000013",
    "0x0000000000000000000000000000000000000014"
  ],
  "additional_comment": "additional_comment2"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
set-cookie: _explorer_key=SFMyNTY.g3QAAAABbQAAAAxjdXJyZW50X3VzZXJ0AAAAB2QABmF2YXRhcm0AAAAlaHR0cHM6Ly9leGFtcGxlLmNvbS9hdmF0YXIvdGVzdF91c2VyNmQABWVtYWlsbQAAABp0ZXN0X3VzZXItN0BibG9ja3Njb3V0LmNvbWQAAmlkYcZkAARuYW1lbQAAAApVc2VyIFRlc3Q2ZAAIbmlja25hbWVtAAAACnRlc3RfdXNlcjZkAAN1aWRtAAAAD2Jsb2Nrc2NvdXR8MDAwNmQADHdhdGNobGlzdF9pZGHG.86gruprPiLE-Nf9xkOzjEcW2wfSnCCPly5fHTwHrF6c; path=/; HttpOnly
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FxF1Y2E03jhU4u4AAGSi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "website": "website2",
  "tags": "Tag2;Tag3",
  "submission_date": "2022-09-03T21:00:07.000000Z",
  "is_owner": true,
  "id": 132,
  "full_name": "full name2",
  "email": "test_user-9@blockscout.com",
  "company": "company2",
  "addresses": [
    "0x000000000000000000000000000000000000000f",
    "0x0000000000000000000000000000000000000010",
    "0x0000000000000000000000000000000000000011",
    "0x0000000000000000000000000000000000000012",
    "0x0000000000000000000000000000000000000013",
    "0x0000000000000000000000000000000000000014"
  ],
  "additional_comment": "additional_comment2"
}
```

