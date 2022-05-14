export const tokenList = [
      {
        address: "0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9",
        index: 0,
        symbol: "ALUSD",
    },
    {
        address: "0x956F47F50A910163D8BF957Cf5846D573E7f87CA",
        index: 1,
        symbol: "FEI",
    },
    {
        address: "0x853d955aCEf822Db058eb8505911ED77F175b99e",
        index: 2,
        symbol: "FRAX",
    },
    {
        address: "0x5f98805A4E8be255a32880FDeC7F6728C6568bA0",
        index: 3,
        symbol: "LUSD",
    },
];

export const UNI_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

export const TOKEN_ABI = [
    {
        constant: true,
        inputs: [
            {
                name: "_owner",
                type: "address",
            },
        ],
        name: "balanceOf",
        outputs: [
            {
                name: "balance",
                type: "uint256",
            },
        ],
        payable: false,
        type: "function",
    },
    {
        inputs: [
            {
                internalType: "address",
                name: "spender",
                type: "address",
            },
            {
                internalType: "uint256",
                name: "value",
                type: "uint256",
            },
        ],
        name: "approve",
        outputs: [
            {
                internalType: "bool",
                name: "",
                type: "bool",
            },
        ],
        stateMutability: "nonpayable",
        type: "function",
    },
];

export const UNISWAP_ABI = [
    "function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts)"
]

export const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
export const FRAX = "0x853d955aCEf822Db058eb8505911ED77F175b99e";

export const SADDLE_ABI = [
    "function addLiquidity(uint256[] calldata amounts, uint256 minToMint, uint256 deadline) external returns (uint256)"
];

export const FRAX_ABI = [
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "account",
          "type": "address"
        }
      ],
      "name": "earned",
      "outputs": [
        {
          "internalType": "uint256[]",
          "name": "",
          "type": "uint256[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "exit",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getReward",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "account",
          "type": "address"
        }
      ],
      "name": "lockedStakesOf",
      "outputs": [
        {
          "components": [
            {
              "internalType": "bytes32",
              "name": "kek_id",
              "type": "bytes32"
            },
            {
              "internalType": "uint256",
              "name": "start_timestamp",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "liquidity",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "ending_timestamp",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "lock_multiplier",
              "type": "uint256"
            }
          ],
          "internalType": "struct IFraxStaking.LockedStake",
          "name": "",
          "type": "tuple"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "index",
          "type": "uint256"
        }
      ],
      "name": "rewardRates",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "index",
          "type": "uint256"
        }
      ],
      "name": "rewardTokens",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "rewardsPerToken",
      "outputs": [
        {
          "internalType": "uint256[]",
          "name": "",
          "type": "uint256[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "liquidity",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "secs",
          "type": "uint256"
        }
      ],
      "name": "stakeLocked",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "totalLiquidityLocked",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "withdraw",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "bytes32",
          "name": "kek_id",
          "type": "bytes32"
        }
      ],
      "name": "withdrawLocked",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]