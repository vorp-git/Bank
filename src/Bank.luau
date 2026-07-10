--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const ProfileStore = if RunService:IsServer() then require(script.Parent.Parent.ProfileStore) :: any else nil
const Signal = require(script.Parent.Parent.Signal) :: any
const Vault = require(script.Parent.Vault)

const Bank = {}
Bank.__index = Bank

export type Config = {
	template: { [string]: any },
	useMock: boolean?,
}

export type Bank = typeof(setmetatable(
	{} :: {
		_name: string,
		_template: { [string]: any },
		_useMock: boolean?,
		_bank: any,
		_vaults: { [Player]: Vault.Vault },
		_vaultLoaded: any,
	},
	Bank
))

const banks: { [string]: Bank } = {}
const bankRegistered = Signal.new()

function Bank.new(name: string, config: Config): Bank
	assert(not banks[name], `Bank {name} already exists`)

	local self = setmetatable({}, Bank) :: Bank

	self._name = name
	self._template = config.template
	self._useMock = config.useMock or false
	self._bank = ProfileStore.New(name, self._template)
	self._vaults = {}
	self._vaultLoaded = Signal.new()

	if self._useMock then
		self._bank = self._bank.Mock
	end

	banks[name] = self
	bankRegistered:Fire(name)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_loadVault(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player: Player): ()
		self:_loadVault(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player): ()
		self:_saveVault(player)
	end)

	return self
end

function Bank.getBank(name: string): Bank?
	if banks[name] then
		return banks[name]
	end

	const deadline = os.clock() + 10
	local connection = nil
	local result = nil :: Bank?

	connection = bankRegistered:Connect(function(bank: string)
		if bank == name then
			result = banks[name]
		end
	end)

	while not result and os.clock() < deadline do
		task.wait()
	end

	connection:Disconnect()

	if not result then
		warn(`Bank.getBank timed out waiting for Bank "{name}", make sure it was created and the name matches exactly.`)
	end

	return result
end

function Bank._loadVault(self: Bank, player: Player): ()
	local profile = self._bank:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			self._vaults[player] = nil
			player:Kick("Data session end - Please rejoin")
		end)

		if player.Parent == Players then
			self._vaults[player] = Vault.new(profile)
			self._vaultLoaded:Fire(player, self._vaults[player])
		else
			profile:EndSession()
		end
	else
		player:Kick("Data load fail - Please rejoin")
	end
end

function Bank._saveVault(self: Bank, player: Player): ()
	local vault = self._vaults[player]

	if vault then
		vault._profile:EndSession()
		vault:destroy()
	end
end

function Bank.vaultLoaded(self: Bank, callback: (Player, Vault.Vault) -> ())
	self._vaultLoaded:Connect(function(player, vault)
		callback(player, vault)
	end)
end

function Bank.getVault(self: Bank, player: Player): Vault.Vault?
	return self._vaults[player]
end

return Bank
