--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

const ProfileStore = if RunService:IsServer() then require(script.Parent.Parent.ProfileStore) :: any else nil
const Signal = require(script.Parent.Parent.Parent.Packages.Signal) :: any
const Vault = require(script.Parent.Vault)

local Bank = {}
Bank.__index = Bank

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	DisconnectAll: (self: Signal<T...>) -> (),
	GetConnections: (self: Signal<T...>) -> { Connection },
	Destroy: (self: Signal<T...>) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

export type JSONAcceptable = { JSONAcceptable } | { [string]: JSONAcceptable } | number | string | boolean | buffer

export type Profile<T> = {
	Data: T & JSONAcceptable,
	LastSavedData: T & JSONAcceptable,
	FirstSessionTime: number,
	SessionLoadCount: number,
	Session: { PlaceId: number, JobId: string }?,
	RobloxMetaData: JSONAcceptable,
	UserIds: { number },
	KeyInfo: DataStoreKeyInfo,
	OnSave: { Connect: (self: any, listener: () -> ()) -> { Disconnect: (self: any) -> () } },
	OnLastSave: {
		Connect: (
			self: any,
			listener: (reason: "Manual" | "External" | "Shutdown") -> ()
		) -> { Disconnect: (self: any) -> () },
	},
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> { Disconnect: (self: any) -> () } },
	OnAfterSave: {
		Connect: (
			self: any,
			listener: (last_saved_data: T & JSONAcceptable) -> ()
		) -> { Disconnect: (self: any) -> () },
	},
	ProfileStore: JSONAcceptable,
	Key: string,

	IsActive: (self: any) -> boolean,
	Reconcile: (self: any) -> (),
	EndSession: (self: any) -> (),
	AddUserId: (self: any, user_id: number) -> (),
	RemoveUserId: (self: any, user_id: number) -> (),
	MessageHandler: (self: any, fn: (message: JSONAcceptable, processed: () -> ()) -> ()) -> (),
	Save: (self: any) -> (),
	SetAsync: (self: any) -> (),
}

export type VersionQuery<T> = {
	NextAsync: (self: any) -> Profile<T>?,
}

type ProfileStoreStandard<T> = {
	Name: string,
	StartSessionAsync: (self: any, profile_key: string, params: { Steal: boolean? }) -> Profile<T>?,
	MessageAsync: (self: any, profile_key: string, message: JSONAcceptable) -> boolean,
	GetAsync: (self: any, profile_key: string, version: string?) -> Profile<T>?,
	VersionQuery: (
		self: any,
		profile_key: string,
		sort_direction: Enum.SortDirection?,
		min_date: DateTime | number | nil,
		max_date: DateTime | number | nil
	) -> VersionQuery<T>,
	RemoveAsync: (self: any, profile_key: string) -> boolean,
}

export type ProfileStore<T> = {
	Mock: ProfileStoreStandard<T>,
} & ProfileStoreStandard<T>

export type Config<T> = {
	template: T,
	useMock: boolean?,
}

export type Bank<T> = typeof(setmetatable(
	{} :: {
		_name: string,
		_template: T,
		_useMock: boolean?,
		_bank: ProfileStore<any>,
		_vaults: { [Player]: Vault.Vault },

		VaultLoaded: Signal<Player, Vault.Vault>,
	},
	Bank
))

local banks: { [string]: Bank<any> } = {}
local bankRegistered = Signal.new() :: Signal<string>

function Bank.new<T>(name: string, config: Config<T>): Bank<T>
	assert(not banks[name], `Bank {name} already exists`)

	local self = setmetatable({}, Bank) :: Bank<T>

	self._name = name
	self._template = config.template
	self._useMock = config.useMock or false
	self._bank = ProfileStore.New(name, self._template)
	self._vaults = {}

	self.VaultLoaded = Signal.new()

	if self._useMock then
		self._bank = self._bank.Mock :: ProfileStore<T>
	end

	banks[name] = self :: Bank<any>
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

function Bank._loadVault(self: Bank<any>, player: Player): ()
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
			self.VaultLoaded:Fire(player, self._vaults[player])
		else
			profile:EndSession()
		end
	else
		player:Kick("Data load fail - Please rejoin")
	end
end

function Bank._saveVault(self: Bank<any>, player: Player): ()
	local vault = self._vaults[player]

	if vault then
		vault._profile:EndSession()
	end
end

function Bank.getVault<T>(self: Bank<T>, player: Player): Vault.Vault
	return self._vaults[player]
end

function Bank.getBank<T>(_self: Bank<any>, name: string): Bank<T>?
	if banks[name] then
		return banks[name]
	end

	local deadline = os.clock() + 10
	local connection = nil
	local result = nil :: Bank<any>?

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

return Bank
