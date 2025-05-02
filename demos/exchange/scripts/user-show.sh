#!/bin/sh

injaddr=$(yes $USER_PWD | injectived keys show -a $USER)
ethaddr=$(injectived q exchange eth-address-from-inj-address $injaddr)
subaccount=$(injectived q exchange subaccount-id-from-inj-address $injaddr)

echo "inj address: $injaddr"
echo "eth address: $ethaddr"
echo "subaccount id: $subaccount"