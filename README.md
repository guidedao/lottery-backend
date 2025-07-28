# GuideDAO Lottery (Back-end)

Full information is available in the [wiki](https://github.com/guidedao/lottery-backend/wiki).

(c) GuideDAO et al.

## Getting started

This project is built with **Foundry** framework for Solidity, so you can use all the tools included.

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

Now you can properly set the VRF consumer config ([details](https://docs.chain.link/vrf/v2-5/overview/subscription)) :

```Solidity
// src/libraries/Configs.sol

library VRFConsumerConfig  {
// Both taken from {MocksDeployScript} logs (or
// Chainlink Subscription Manager if not testing locally)
address constant VRF_COORDINATOR = <COORDINATOR_ADDRESS>
uint256 constant SUBSCRIPTION_ID = <SUBSCRIPTION_ID>

// Indicates maximum gas price you are willing to pay,
// use arbitrary bytes32 value if running locally
bytes32 constant KEY_HASH = <KEY_HASH>
// ...
```

Don't forget to save changes.

Then you have will have to deploy the lottery contract:

```bash
// You will be asked to enter GuideDAO token address
forge script script/LotteryDeploy.s.sol:LotteryDeployScript --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

And add the lottery in VRF consumers list:

```bash
// Now you will need to provide the lottery address
forge script script/AddConsumer.s.sol:AddConsumerScript --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

Now you have fully prepared local chain, and you can use [http://localhost:8545](http://localhost:8545) as RPC URL for your purposes.

### Running in production or public testnets

In this case you will only have to set config values (VRF coordinator address, subscription id and key hash), taken from Chainlink Subscription Manager, and deploy the lottery contract in the same way as above.

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
