# NOTICE: Bank is still under development and should not be used as of now.

# Bank

A Bank/Vault data management library built on ProfileStore

## Installation

Add to your `wally.toml`: under `[server-dependencies]`

```toml
Bank = "vorp-git/bank@0.5.3"
```

## Quick Start

```lua
local Bank = require(path)

local playerDataBank = Bank.new("PlayerData_v1", {
    template = {},
    useMock = false,
})
```

## Multiple Banks

You can create multiple independent Banks (e.g. one for player data, one for clan data).
Each is created once with `Bank.new(name, config)`, then retrieved anywhere by name with `Bank:getBank(name)`.

## Getting A Player's Vault

```lua
local Bank = require(path)

local playerDataBank = Bank:getBank("PlayerData_v1")

playerDataBank:vaultLoaded(function(player, vault)
    print(player, vault)
end)
```

## Using A Vault

```lua
vault:getData()
vault:get("cash")
vault:set("cash", 100)

vault:increment("cash", 10)
vault:decrement("cash", 10)

vault:update("cash", function(currentCash)
    return currentCash + 100
end)

vault:onLastSave(function(reason)
    print(reason)
end)
```

## Scope

Bank is server-only. It does not replicate data to the client automatically.
If you need client-side access to player data, you'll need to build your own replication layer (e.g. RemoteEvents, or a library like Blink).

## Roadmap

- [ ] Global leaderboard support (via OrderedDataStore)
