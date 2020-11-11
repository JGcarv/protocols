// SPDX-License-Identifier: Apache-2.0
// Copyright 2017 Loopring Technology Limited.
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../../base/WalletDataLayout.sol";
import "../data/GuardianData.sol";
import "../data/OracleData.sol";
import "../data/QuotaData.sol";
import "../data/SecurityData.sol";
import "../utils/GuardianUtils.sol";
import "../utils/SignedRequest.sol";
import "./MetaTxAwareModule.sol";

// import "./GuardianUtils.sol";
// import "./SignedRequest.sol";


/// @title SecurityStore
///
/// @author Daniel Wang - <daniel@loopring.org>
abstract contract SecurityModule is MetaTxAwareModule
{
    using GuardianData  for WalletDataLayout.State;
    using OracleData    for WalletDataLayout.State;
    using QuotaData     for WalletDataLayout.State;
    using SecurityData  for WalletDataLayout.State;
    using SignedRequest for WalletDataLayout.State;

    // The minimal number of guardians for recovery and locking.
    uint public constant TOUCH_GRACE_PERIOD = 30 days;

    event WalletLocked(
        address indexed wallet,
        address         by,
        bool            locked
    );


    modifier onlyFromWalletOrOwnerWhenUnlocked()
    {
        address payable _sender = msgSender();
        require(
            _sender == address(this) ||
            _sender == thisWallet().owner() && !_isWalletLocked(address(this)),
             "NOT_FROM_WALLET_OR_OWNER_OR_WALLET_LOCKED"
        );
        state.touchLastActiveWhenRequired(TOUCH_GRACE_PERIOD);
        _;
    }

    modifier onlyWalletGuardian(address guardian)
    {
        require(state.isGuardian(guardian, false), "NOT_GUARDIAN");
        _;
    }

    modifier notWalletGuardian(address guardian)
    {
        require(!state.isGuardian(guardian, false), "IS_GUARDIAN");
        _;
    }

    // ----- internal methods -----

    function _verifyRequest(
        GuardianUtils.SigRequirement sigRequirement,
        SignedRequest.Request calldata request,
        bytes                 memory   encodedRequest
        )
        internal
    {
        state.verifyRequest(
            thisWallet().domainSeperator(),
            txAwareHash(),
            sigRequirement,
            request,
            encodedRequest
        );
    }

    function _lockWallet(address wallet, address by, bool locked)
        internal
    {
        state.setLock(locked);
        emit WalletLocked(wallet, by, locked);
    }

    function _isWalletLocked(address wallet)
        internal
        view
        returns (bool)
    {
        return state.isLocked();
    }

    function _updateQuota(
        address    token,
        uint       amount
        )
        internal
    {
        if (amount == 0) return;

        state.checkAndAddToSpent(
            token,
            amount,
            state.priceOracle()
        );
    }
}
