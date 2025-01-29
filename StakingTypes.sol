// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library StakingTypes {
    
   /// @dev User-defined type for staking methods that can be approved. This 
   /// matches the MsgType type defined in the Staking authz types.
   type MsgType is uint8;

   /// @dev Define all the staking methods available for approval.
   MsgType public constant MsgType_Delegate = MsgType.wrap(1);
   MsgType public constant MsgType_Undelegate = MsgType.wrap(2);
   MsgType public constant MsgType_Redelegate = MsgType.wrap(3);
   MsgType public constant MsgType_Unknown = MsgType.wrap(4);
}