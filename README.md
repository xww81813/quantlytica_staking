# Quantlytica

Solidity contracts used in [Quantlytica](https://www.quantlytica.com/) .

## Overview

## Audits

- : [report]() (Also available in Chinese in the same folder)

## Contracts

### Installation

- To run, pull the repository from GitHub and install its dependencies. You will need [npm](https://docs.npmjs.com/cli/install) installed.

```bash
git clone https://github.com/xww81813/quantlytica_staking.git
cd quantlytica_staking
npm install 
```
- Create an enviroment file named `.env` and fill the next enviroment variables

```
# Import private key
PRIVATEKEY= your private key  

# Add Infura provider keys
POLYGON_NETWORK=https://polygon-mainnet.infura.io/v3/YOUR_API_KEY
TESTPOLYGON_NETWORK=https://polygon-amoy.infura.io/v3/YOUR_API_KEY
```

### Compile

```
npx hardhat compile
```

## License

- (c) Quantlytica Ltd., 2023 - [All rights reserved](https://github.com/xww81813/quantlytica_core_v1/blob/main/LICENSE).


## Discussion

For any concerns with the protocol, open an issue or visit us on [Discord](https://discord.com/invite/quantlytica) to discuss.

For security concerns, please email [dev@quantlytica.com](mailto:dev@quantlytica.com).

_© Copyright 2023, Quantlytica Ltd._
