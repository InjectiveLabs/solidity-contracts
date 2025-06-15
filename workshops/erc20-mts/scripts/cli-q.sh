#!/bin/sh

source .local.env

injectived q $* --node $INJ_URL

echo ""
