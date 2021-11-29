#!/usr/bin/env python3

import pytest
import brownie
from brownie import Sale, accounts
from brownie.test import strategy

def to_hex(n):
    return '0x' + n.hex()

@pytest.fixture
def params():
    # MAGIC HACK: these are "injected" via a globals update.
    params = {
        'deployer': accounts[0],
        'buyer': accounts[1],
        'seller': accounts[2],
        # This is just "any bytes32". Hardcoded for now.
        'sale_hash': (b'f\xd0Y\xea\x1e\x9b5\x10\xfcV\xa0'
                      b'\xba\xa4\x15\xd7\x0e\r\xb0g\xde'
                      b'\x13%\x84v\xfe\xe6(\xa5\xf9\x94\xd5\r'),
        'sale_contract': accounts[0].deploy(Sale),
    }
    globals().update(params)

def test_initial_happiness(params):
    assert sale_contract.buyer_happy() == True
    assert sale_contract.seller_happy() == True

def test_blind_call_to_accept(params):
    with brownie.reverts():
        # This call should revert because
        #   1. state!=STARTED
        #   2. account[0] is not "seller_address"
        sale_contract.acceptCurrentOffer()

def test_start(params):
    sale_contract.startSale(sale_hash, seller) ## WHO?
    assert sale_contract.sale_hash() == to_hex(sale_hash)
