#!/usr/bin/env python3

from brownie import Sale, accounts

def test_deploy():
    assert Sale.deploy({"from": accounts[0]})
