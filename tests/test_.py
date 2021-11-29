#!/usr/bin/env python3

import pytest
from brownie import Sale, accounts

@pytest.fixture
def sale():
    return accounts[0].deploy(Sale)

def test_initial_happiness(sale):
    # Bug ID 0 -- why do these fail?
    assert sale.buyer_happy() == True
    assert sale.seller_happy() == True
