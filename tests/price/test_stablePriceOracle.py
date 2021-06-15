#!/usr/bin/python3
import pytest
import brownie
from namehash import namehash


# @pytest.mark.skip
def test_price(stablePriceOracle, accounts, web3, chain):
    assert stablePriceOracle.price("foo", 0, 3600) == 1440
    assert stablePriceOracle.price("quux", 0, 3600) == 720
    assert stablePriceOracle.price("fubar", 0, 3600) == 360
    assert stablePriceOracle.price("foobie", 0, 3600) == 360


def test_price_larger(stablePriceOracle, accounts, web3, chain):
    #   1 USD per second!
    stablePriceOracle.setPrices([1000000000000000000], {'from': accounts[0]})
    assert stablePriceOracle.price("foo", 0, 86400) == 8640000000000000000000
