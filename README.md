# Bank

A Bank/Vault data management library built on ProfileStore

## Installation

Add to your `wally.toml`: under `[server-dependencies]`

```toml
Bank = "vorp-git/bank@0.4.0"
```

## Quick Start

```lua
local Bank = require(path)

local playerDataBank = Bank.new("PlayerData_v1", {
    template = {},
    useMock = false,
})
```
