#!/bin/bash

# Helper to kill the blockscout process on ort 4001
# if it does not abort cleanly and holds the port

sudo kill -9 $(sudo lsof -t -i:4001)
