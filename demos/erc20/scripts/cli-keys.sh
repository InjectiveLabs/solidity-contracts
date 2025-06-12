#!/bin/sh

source .local.env

injectived keys $* --keyring-backend=test

echo ""
