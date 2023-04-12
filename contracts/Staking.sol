// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Stake is Ownable {
    constructor() payable {}

    // 批量授权 todo: 合约管理员操作
    function approve(
        address[] calldata coins,
        address[] calldata spenders
    ) public onlyOwner {
        for (uint i = 0; i < coins.length; i++) {
            if (IERC20(coins[i]).allowance(address(this), spenders[i]) != 0) {
                continue;
            }
            IERC20(coins[i]).approve(
                spenders[i],
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            );
        }
    }

    // 批量取消授权
    function dis_approve(
        address[] calldata coins,
        address[] calldata spenders
    ) public onlyOwner {
        for (uint i = 0; i < coins.length; i++) {
            IERC20(coins[i]).approve(
                spenders[i],
                0x0000000000000000000000000000000000000000000000000000000000000000
            );
        }
    }

    // 转账功能
    function transfer(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function deposit_and_stake(
        // 实现方法的合约
        address proxy,
        // 矿池合约地址
        address pool,
        // 真正质押的calldata,传给proxy合约
        bytes calldata data,
        // 入金币种列表, 判断合约是否授权
        address[] calldata inputCoins,
        // 入金币种额度, 用于转钱
        uint256[] calldata inputCoinsAmount,
        // 出金币种
        address[] calldata outputCoins
    ) public payable {
        /**
         * 检查授权
         * 1. 检查用户 是否授权给聚合合约
         * 2. 检查 聚合合约是否授权给矿池
         */
        for (uint i = 0; i < inputCoins.length; i++) {
            // 直接把用户的钱转入合约, 顺便判断授权额度是否够用
            address token = inputCoins[i];
            uint256 amount = inputCoinsAmount[i];
            // eth
            if (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                // 检查value是否足够
                require(msg.value >= amount);
            } else {
                // erc20
                require(
                    IERC20(inputCoins[i]).transferFrom(
                        msg.sender,
                        address(this),
                        amount
                    ),
                    "please approve or low balance"
                );
                // 判断聚合合约 授权额度是否 大于 入金额度
                if (IERC20(token).allowance(address(this), pool) < amount) {
                    IERC20(token).approve(
                        pool,
                        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                    );
                }
            }
        }

        // 记录交易前 合约币种的余额
        uint256[] memory outputCoinsBalance = new uint256[](outputCoins.length);
        for (uint j = 0; j < outputCoins.length; j++) {
            address token = inputCoins[j];
            // eth获取原生币余额
            if (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                outputCoinsBalance[j] = address(this).balance;
                continue;
            }
            // erc20获取token余额
            outputCoinsBalance[j] = IERC20(token).balanceOf(address(this));
        }

        (bool success, ) = proxy.call{value: msg.value}(data);
        require(success, "revert");

        // 把钱转给用户
        for (uint k = 0; k < outputCoins.length; k++) {
            address token = inputCoins[k];
            uint256 balance = outputCoinsBalance[k];
            if (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                require(
                    payable(msg.sender).send(address(this).balance - balance),
                    "eth transfer failed"
                );
                continue;
            }
            require(
                IERC20(outputCoins[k]).transfer(
                    msg.sender,
                    IERC20(outputCoins[k]).balanceOf(address(this)) - balance
                ),
                "send token to user failed"
            );
        }
    }
}

contract StakeProxy1 {
    constructor() {}

    function deposit_and_stake(
        address pool,
        bytes calldata data
    ) public payable {
        (bool success, ) = pool.delegatecall(data);
        require(success, "revert");
    }
}
