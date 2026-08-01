# Bank is actively maintained. New features and improvements will be added over time. If you find any bugs or have suggestions, feel free to open an issue.

# Bank

A Bank/Vault data management library built on ProfileStore

## Installation

Add to your `wally.toml`: under `[server-dependencies]`

```toml
Bank = "vorp-git/bank@1.1.2"
```

## Quick Start

```lua
local Bank = require(path)

local playerDataBank = Bank.new("PlayerDataBank", {
    template = {},
    useMock = false,
})
```

## Leaderstats

You can easily pick what data you want to be displayed on the Player List (the leaderboard shown in the top-right corner of the screen):

```lua
local Bank = require(path)

local playerDataBank = Bank.new("PlayerDataBank", {
    template = {
        cash = 0,
    },
    leaderstats = { "cash" }
})
```

## Getting A Player's Vault

```lua
local Players = game:GetService("Players")
local Bank = require(path)

local playerDataBank = Bank.new("PlayerDataBank", {
    template = {},
})

playerDataBank:vaultLoaded(function(player, vault)
    print(player, vault)
end)

Players.PlayerAdded:Connect(function(player)
    local vault = playerDataBank:getVault(player)
end)
```

## Using A Vault

```lua
vault:get() -- returns data table
vault:get("cash")
vault:set("cash", 100)

vault:increment("cash", 10)
vault:decrement("cash", 50)

vault:set({"inventory", "maxSlots"}, 50)

vault:update("cash", function(prev)
    return prev + 100
end)

vault:onLastSave(function(reason)
    print(reason)
end)

vault:onChanged(function(key, value)
    print(key, value)
end)
```

## Scope

Bank is server-only. It does not replicate data to the client automatically.
If you need client-side access to player data, you'll need to build your own replication layer (e.g. RemoteEvents, or a library like Blink).

## Roadmap

- [ ] Global leaderboard support (via OrderedDataStore)
