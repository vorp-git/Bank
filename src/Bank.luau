--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

const ProfileStore = if RunService:IsServer() then require(script.Parent.Parent.ProfileStore) :: any else nil

local Bank = {}
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
		_vaults: {},
	},
	Bank
))

function Bank.new(name: string, config: Config): Bank
	local self = setmetatable({}, Bank) :: Bank

	self._name = name
	self._template = config.template
	self._useMock = config.useMock or false
	self._bank = ProfileStore.New(name, self._template)
	self._vaults = {}

	if self._useMock then
		self._bank = self._bank.Mock
	end

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

function Bank._loadVault(self: Bank, player: Player): ()
	local vault = self._bank:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if vault then
		vault:AddUserId(player.UserId)
		vault:Reconcile()

		vault.OnSessionEnd:Connect(function()
			self._vaults[player] = nil
			player:Kick("Data session end - Please rejoin")
		end)

		if player.Parent == Players then
			self._vaults[player] = vault
		else
			vault:EndSession()
		end
	else
		player:Kick("Data load fail - Please rejoin")
	end
end

function Bank._saveVault(self: Bank, player: Player): ()
	local vault = self._vaults[player]
	if vault then
		vault:EndSession()
	end
end

return Bank
