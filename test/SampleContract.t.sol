// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test} from "lib/forge-std/src/Test.sol";

import {RICKS} from "src/RICKS.sol";

contract RICKSTest is Test {
    RICKS ricks;

    function setUp() public {
        ricks = new RICKS();
    }

    function testFunc1() public {
        sampleContract.func1(1337);
    }

    function testFunc2() public {
        sampleContract.func2(1337);
    }
}
