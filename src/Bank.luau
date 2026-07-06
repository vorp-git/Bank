--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

const ProfileStore = if RunService:IsServer() then require(script.Parent.Parent.ProfileStore) :: any else nil
const Vault = require(script.Parent.Vault)

local Bank = {}
Bank.__index = Bank

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
	},
	Bank
))

function Bank.new<T>(name: string, config: Config<T>): Bank<T>
	local self = setmetatable({}, Bank) :: Bank<T>

	self._name = name
	self._template = config.template
	self._useMock = config.useMock or false
	self._bank = ProfileStore.New(name, self._template)
	self._vaults = {}

	if self._useMock then
		self._bank = self._bank.Mock :: ProfileStore<T>
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

return Bank
