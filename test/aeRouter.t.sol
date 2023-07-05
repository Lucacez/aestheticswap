// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/aeFactory.sol";
import "./utils/mock/MockToken.sol";
import "../src/aePair.sol";
import "../src/aeRouter.sol";
import "solmate/src/tokens/WETH.sol";
import {SafeTransferLib, ERC20} from "solmate/src/utils/SafeTransferLib.sol";

contract aeRouterTest is Test {
  using SafeTransferLib for ERC20;
  using SafeTransferLib for address;

  aeFactory public aefactory;
  MockToken public mockToken1;
  MockToken public mockToken2;
  aePair public aepair;
  WETH public weth;
  aeRouter public aerouter;

  address public admin = address(64);
  address public alice = address(128);
  address public bob = address(256);

  address public pair1;
  uint256 public constant AMOUNT = 5000;

  function setUp() public {
    aefactory = new aeFactory();
    mockToken1 = new MockToken("TestToken1", "TT1", 18, admin);
    mockToken2 = new MockToken("TestToken2", "TT2", 18, admin);
    weth = new WETH();
    aerouter = new aeRouter(address(aefactory), address(weth));

    vm.startPrank(admin);
    mockToken1.transfer(alice, AMOUNT);
    mockToken2.transfer(alice, AMOUNT);
    mockToken1.transfer(bob, 3500);
    vm.deal(alice, 5000 wei);
    vm.stopPrank();
  } 

  function testAddLiquidity() public {
    assertEq(mockToken1.balanceOf(alice), AMOUNT);
    assertEq(mockToken2.balanceOf(alice), AMOUNT);

    vm.startPrank(alice);

    ERC20(address(mockToken1)).safeApprove(address(aerouter), AMOUNT);
    ERC20(address(mockToken2)).safeApprove(address(aerouter), AMOUNT);

    (, , uint256 lps) = aerouter.addLiquidity(
      address(mockToken1), address(mockToken2), 
      AMOUNT, AMOUNT, 
      0, 0, 
      alice, type(uint256).max);

    vm.stopPrank();

    assertEq(mockToken1.balanceOf(alice), 0);
    assertEq(mockToken2.balanceOf(alice), 0);
    assertEq(lps, 4000);
  }

  function testaddLiquidityETH() public {
    assertEq(mockToken1.balanceOf(alice), AMOUNT);
    assertEq(mockToken2.balanceOf(alice), AMOUNT);


    vm.startPrank(alice);

    ERC20(address(mockToken1)).safeApprove(address(aerouter), AMOUNT);

    (, , uint256 lps) = aerouter.addLiquidityETH{
        value: 5000 wei }(
        address(mockToken1), AMOUNT, 
        0, 0, alice, type(uint256).max);
    
    vm.stopPrank();

    assertEq(mockToken1.balanceOf(alice), 0);
    assertEq(alice.balance, 0);
    assertEq(lps, 4000);
  }
    
  function testRemoveLiquidity() public {
    uint256 LPs = 4000;

    address pair = pairFor(address(aefactory), address(mockToken1), address(mockToken2));

    testAddLiquidity();

    vm.startPrank(alice);

    aePair(pair).approve(address(aerouter), LPs); 

    aerouter.removeLiquidity(
      address(mockToken1), address(mockToken2), 
      LPs, 0, 0, 
      alice, type(uint256).max);

    vm.stopPrank();

    assertEq(mockToken1.balanceOf(alice), 4000);
    assertEq(mockToken2.balanceOf(alice), 4000);
    assertEq(aePair(pair).balanceOf(alice), 0);
  }

  function testRemoveLiquidityETH() public {
    uint256 LPs = 4000;

    address pair = pairFor(address(aefactory), address(mockToken1), address(weth));

    testaddLiquidityETH();

    vm.startPrank(alice);

    aePair(pair).approve(address(aerouter), LPs);
    
    aerouter.removeLiquidityETH(
      address(mockToken1), LPs, 
      0, 0, 
      alice, type(uint256).max);

    vm.stopPrank();

    assertEq(mockToken1.balanceOf(alice), 4000);
    assertEq(alice.balance, 4000 wei);
    assertEq(aePair(pair).balanceOf(alice), 0);
  }

  // function testswapExactTokensForTokens() public {

  //   testAddLiquidity();

  //   vm.startPrank(bob);

  //   mockToken1.approve(address(aerouter), 3500);

  //   aerouter.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);

  // }





  function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
    require(tokenA != tokenB);
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(token0 != address(0));
  }


  function pairFor(address factory, address tokenA, address tokenB) public pure returns (address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);
    pair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'896ef8cddea29f8b5d03aefe9b609c3f563f7bba2b5abfe78b7b020f3173e3e1' // init code hash
        )))));
  }
}