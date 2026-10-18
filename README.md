# World mining token (WORLD)

A fixed-supply ERC-20 built with Foundry on OpenZeppelin Contracts v5.1.0 (vendored in `lib/`).

| Property | Value |
| --- | --- |
| Solidity contract | `WorldToken` (`src/WorldToken.sol`) |
| `name()` | `World mining token` |
| `symbol()` | `WORLD` |
| `decimals()` | `18` |
| `totalSupply()` | `1,000,000,000 × 10^18` = `1000000000000000000000000000` minor units |
| Constructor arguments | none |
| Compiler | solc 0.8.26, optimizer 200 runs, `bytecode_hash = "none"` |

## Behaviour

- The constructor mints the entire supply once to `msg.sender` (the deployer; on the IMD launch, the factory).
- There is no further mint, no burn, no owner, no pause, no blacklist, no transfer fee or tax, and no upgrade path.
  Every transfer moves exactly the requested amount, so the launch flows (distributor share, pool seed, swaps)
  arrive whole.
- Standard ERC-20 semantics from OpenZeppelin: custom errors on insufficient balance/allowance, transfers to or
  approvals for the zero address revert, a `type(uint256).max` allowance is not decremented.

## Assumptions

- The brief asks only for name, symbol, supply and decimals; no transfer rules, so none were added.
- No application contracts accompany the token.
- Distribution of the supply after deployment (swarm share, pool seed, remainder) is handled entirely by the
  launch factory; the token contract has no knowledge of it and needs no constructor arguments.

## Deployment parameters

- Deploy `WorldToken` with no constructor arguments. The deployer receives all 1,000,000,000 WORLD.
- `script/DeployWorldToken.s.sol` is a reviewable reference script for local/test networks
  (`forge script script/DeployWorldToken.s.sol`). The production launch is performed by IMD's factory; this
  repository does not broadcast transactions or hold keys.

## Operational responsibilities

- The token has no admin, so there is nothing to operate or configure after launch, and nothing can be recovered
  or changed: tokens sent to a wrong address (including the token contract itself) are lost.
- Whoever holds the minted supply at deployment is responsible for distributing it.

## After launch

Nothing to set: the contract has no owner-settable configuration.

## Development

```sh
forge build
forge test
forge fmt --check
```

Tests in `test/WorldToken.t.sol` cover metadata, the one-time mint, transfers, allowances, failure cases
(insufficient balance/allowance, zero addresses), absence of mint/admin entry points, the deploy function, and fuzzed
supply conservation. Passing tests are not a security audit.
