# GuideDAO Lottery (Back-end)

Full information is available in the [wiki](https://github.com/guidedao/lottery-backend/wiki).

(c) GuideDAO et al.

## Getting started

This project is built with **Foundry** framework for Solidity, so you can use all the tools included.

Here are all the configuration values for the contracts (src/libraries/Configs.sol):

```Solidity
// Details: https://docs.chain.link/vrf/v2-5/overview/subscription
library VRFConsumerConfig {
    bytes32 constant KEY_HASH = <...>;
    uint32 constant CALLBACK_GAS_LIMIT = <...>;
    uint16 constant REQUEST_CONFIRMATIONS = <...>;
}

// Business logic
library LotteryConfig {
    uint256 constant INITIAL_TICKET_PRICE = <...>;
    uint8 constant TARGET_PARTICIPANTS_NUMBER = <...>;
    uint16 constant MAX_PARTICIPANTS_NUMBER = <...>;
    uint256 constant REGISTRATION_DURATION = <...>;
    uint256 constant MAX_EXTENSION_TIME = <...>;
    uint256 constant REFUND_WINDOW = <...>;
}
```

You probably won't need to change anything for setting up locally, however, you can do that if you want.

### Running Locally

First, open two terminal tabs and run a local Ethereum node in any of them:

```bash
anvil
```

And switch to another.

Then mine a couple of blocks:

```bash
cast rpc anvil_mine 5 --rpc-url http://localhost:8545
```

This is extremely important, as Chainlink computes subscription id based on the hash of the previous block.

Since you are running locally, you don't have all the necessary contracts, specifically Chainlink VRF coordinator and GuideDAO token. Instead you should deploy their mocks:

```bash
forge script script/local/MocksDeploy.s.sol:MocksDeployScript --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

If deployment is successful, you will see the logs:

```bash
== Logs ==
  VRF coordinator mock deployed to:  <COORDINATOR_ADDRESS>
  GuideDAO token mock deployed to: <TOKEN_ADDRESS>
```

You will instantly need the VRF coordinator address to fund a subscription and receive back the active subscription id and current consumer balance (you can execute the same script later to make a top-up):

```bash
forge script script/local/FundSubscription.s.sol:FundSubscriptionScript --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

Then you have will have to deploy the lottery contract (you will have to specify initial organizer and GuideDAO token address along with VRF coordinator address and subscription ID):

```bash
forge script script/LotteryDeploy.s.sol:LotteryDeployScript --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

And add the lottery in VRF consumers list (now you will need to provide the lottery, GuideDAO NFT fallback recipient and coordinator addresses and corresponding subscription ID):

```bash
forge script script/local/AddConsumer.s.sol:AddConsumerScript --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

Now you have fully prepared local chain, and you can use [http://localhost:8545](http://localhost:8545) as RPC URL for your purposes.

### Running in production or public testnets

In this case you will only have to deploy the lottery contract in the same way as above.

## Code Quality

To check code for linting errors, run:

```bash
solhint ./**/*.sol
```

## Project Structure

The main source code is organized as follows:

```
lib/           # External dependencies
  script/      # Deployment and interaction scripts
    local/     # Scripts required only for local setup
src/           # Contracts source code
  interfaces/  # Contracts interfaces
  libraries/   # Helper library contracts (Configs, Types)
test/          # Test-related contracts
  mocks/       # Contracts to simulate future interaction
```
