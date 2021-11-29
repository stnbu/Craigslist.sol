#!/usr/bin/env python3

import pytest
import brownie
from brownie import Sale, accounts

@pytest.fixture
def sale():
    return accounts[0].deploy(Sale)

def test_initial_happiness(sale):
    # Bug ID 0 -- why do these fail?
    assert sale.buyer_happy() == True
    assert sale.seller_happy() == True

def test_blind_call_to_accept(sale):
    with brownie.reverts():
        # This call should revert because
        #   1. state!=STARTED
        #   2. account[0] is not "seller_address"
        sale.acceptCurrentOffer()
