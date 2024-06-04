require('dotenv').config()
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
	solidity: {
		compilers: [{
			version: "0.8.17",
			settings: {
				optimizer: {
					enabled: true,
					runs: 200
				}
			},
		}]
	},
	networks: {
		test_polygon: {
			url: `${process.env.POLYGON_TEST_NETWORK}`,
			chainId: 80001,
			gasPrice: 'auto',
			accounts: [`${process.env.DEPLOYER}`,`${process.env.TESTER1}`,`${process.env.TESTER2}`]
		},
		main_polygon: {
			url: `${process.env.POLYGON_MAINNET_NETWORK}`,
			chainId: 137,
			gasPrice: 'auto',
			accounts: [`${process.env.DEPLOYER}`,`${process.env.TESTER1}`,`${process.env.TESTER2}`]
		}
	},
};