#!/usr/bin/python3

from brownie import ENSRegistry, accounts, network, web3


def main():
    ens = ENSRegistry.deploy({'from': accounts[0]})

