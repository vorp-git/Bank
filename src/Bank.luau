--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const dependencies = script.Parent.Parent :: Folder
const ProfileStore = if RunService:IsServer() then require(dependencies:FindFirstChild("ProfileStore")) :: any else nil
const Signal = require(dependencies:FindFirstChild("Signal")) :: any
const Janitor = require(dependencies:FindFirstChild("Janitor")) :: any
const Vault = require(script.Parent.Vault)

const Bank = {}
Bank.__index = Bank

export type Config = {
	template: { [string]: any },
	leaderstats: { string }?,
	useMock: boolean?,
}

export type Bank = typeof(setmetatable(
	{} :: {
		_template: { [string]: any },
		_leaderstats: { string }?,
		_store: any,
		_vaultLoaded: any,
		_janitor: any,
		_vaults: { [Player]: Vault.Vault },
	},
	Bank
))

function Bank.new(name: string, config: Config): Bank
	const self = setmetatable({}, Bank) :: Bank

	self._template = config.template
	self._leaderstats = config.leaderstats or nil
	self._store = ProfileStore.New(name, config.template)
	self._vaultLoaded = Signal.new()
	self._janitor = Janitor.new()
	self._vaults = {}

	if config.useMock then
		self._store = self._store.Mock
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
	const profile = self._store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick()
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		self._vaults[player]:destroy()
		self._vaults[player] = nil
		player:Kick()
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	self._vaults[player] = Vault.new(profile)
	self:_createLeaderstats(player)
	self._vaultLoaded:Fire(player, self._vaults[player])
end

function Bank._saveVault(self: Bank, player: Player): ()
	const vault = self._vaults[player]
	if vault then
		vault:release()
	end
end

function Bank._createLeaderstats(self: Bank, player: Player): ()
	if not self._leaderstats then
		return
	end

	const vault = self._vaults[player]
	const leaderstatsFolder = Instance.new("Folder")
	leaderstatsFolder.Name = "leaderstats"
	leaderstatsFolder.Parent = player

	for _, stat in self._leaderstats do
		if typeof(self._template[stat]) == "number" then
			const val = Instance.new("NumberValue")
			val.Name = stat
			val.Value = vault:get(stat)
			val.Parent = leaderstatsFolder
		elseif typeof(self._template[stat]) == "string" then
			const val = Instance.new("StringValue")
			val.Name = stat
			val.Value = vault:get(stat)
			val.Parent = leaderstatsFolder
		end
	end

	self._vaults[player]:onChanged(function(key, value)
		for _, new: any in leaderstatsFolder:GetChildren() do
			if new.Name ~= key then
				continue
			end

			new.Value = value
		end
	end)
end

function Bank.vaultLoaded(self: Bank, callback: (Player, Vault.Vault) -> ()): ()
	self._janitor:Add(self._vaultLoaded:Connect(callback))
end

function Bank.getVault(self: Bank, player: Player): Vault.Vault
	return self._vaults[player]
end

return Bank
