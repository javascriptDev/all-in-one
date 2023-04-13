// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Stake is Ownable {
    event Response(bool success, bytes data, uint256);

    struct InputToken {
        address token
        address contract
        uint256 amount
    }

    struct Call3 {
        address target;
        bytes callData;
    }

    struct Call3Value {
        address target;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    constructor() payable {}

    // 批量授权 todo: 合约管理员操作
    function approve(address[] calldata coins, address[] calldata spenders)
        public
        onlyOwner
    {
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
    function dis_approve(address[] calldata coins, address[] calldata spenders)
        public
        onlyOwner
    {
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

        (bool success, bytes memory data) = proxy.delegatecall(data);
        require(success, "revert");
        emit Response(
            success,
            data,
            outputCoinsBalance[0],
            IERC20(outputCoins[0]).balanceOf(address(this))
        );

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

    function call(InputToken[] inputTokens, address[] outTokens, Call3[] calls, Call3Value[] valueCalls) {
        /**
         * 检查授权
         * 1. 检查用户 是否授权给聚合合约
         * 2. 检查 聚合合约是否授权给矿池
         */
        for (uint i = 0; i < inputTokens.length; i++) {
            // 直接把用户的钱转入合约, 顺便判断授权额度是否够用
            InputToken it = inputCoins[i];
            // eth
            if (it.token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                // 检查value是否足够
                require(msg.value >= it.amount);
            } else {
                // erc20
                require(
                    IERC20(it.token).transferFrom(
                        msg.sender,
                        address(this),
                        it.amount
                    ),
                    "please approve or low balance"
                );
                // 判断聚合合约 授权额度是否 大于 入金额度
                if (IERC20(it.token).allowance(address(this), it.contract) < it.amount) {
                    IERC20(it.token).approve(
                        it.contract,
                        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                    );
                }
            }
        }

        // 记录交易前 合约币种的余额
        uint256[] memory outCoinsBalance = new uint256[](outTokens.length);
        for (uint j = 0; j < outTokens.length; j++) {
            address token = inputCoins[j];
            // eth获取原生币余额
            if (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                outCoinsBalance[j] = address(this).balance;
                continue;
            }
            // erc20获取token余额
            outCoinsBalance[j] = IERC20(token).balanceOf(address(this));
        }

        // 执行erc20 call
        if (calls.length > 0) {
            aggregate3(calls);
        }

        // 执行eth call
        if (valueCalls.length > 0) {
            aggregate3Value(calls);
        }

        // 把钱转给用户
        for (uint k = 0; k < outTokens.length; k++) {
            address token = inputCoins[k];
            uint256 balance = outCoinsBalance[k];
            if (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                require(
                    payable(msg.sender).send(address(this).balance - balance),
                    "eth transfer failed"
                );
                continue;
            }
            require(
                IERC20(outTokens[k]).transfer(
                    msg.sender,
                    IERC20(outTokens[k]).balanceOf(address(this)) - balance
                ),
                "send token to user failed"
            );
        }
    }
    /// @notice Aggregate calls, ensuring each returns success if required
    /// @param calls An array of Call3 structs
    /// @return returnData An array of Result structs
    function aggregate3(Call3[] calldata calls) public payable returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3 calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.call(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x64)
                }
            }
            unchecked { ++i; }
        }
    }

    /// @notice Aggregate calls with a msg value
    /// @notice Reverts if msg.value is less than the sum of the call values
    /// @param calls An array of Call3Value structs
    /// @return returnData An array of Result structs
    function aggregate3Value(Call3Value[] calldata calls) public payable returns (Result[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked { valAccumulator += val; }
            (result.success, result.returnData) = calli.target.call{value: val}(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x84)
                }
            }
            unchecked { ++i; }
        }
        // Finally, make sure the msg.value = SUM(call[0...i].value)
        require(msg.value == valAccumulator, "Multicall3: value mismatch");
    }
}

contract StakeProxy1 {
    constructor() {}

    function deposit_and_stake(address pool, bytes calldata data)
        public
        payable
    {
        (bool success, ) = pool.call{value: msg.value}(data);
        require(success, "revert");
    }
    function claim_all () {}
}
