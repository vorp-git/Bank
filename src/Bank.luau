--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

const ProfileStore = if RunService:IsServer() then require(script.Parent.Parent.ProfileStore) :: any else nil

local Bank = {}
Bank.__index = Bank

export type JSONAcceptable = { JSONAcceptable } | { [string]: JSONAcceptable } | number | string | boolean | buffer

export type Vault<T> = {
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
	NextAsync: (self: any) -> Vault<T>?,
}

type ProfileStoreStandard<T> = {
	Name: string,
	StartSessionAsync: (self: any, profile_key: string, params: { Steal: boolean? }) -> Vault<T>?,
	MessageAsync: (self: any, profile_key: string, message: JSONAcceptable) -> boolean,
	GetAsync: (self: any, profile_key: string, version: string?) -> Vault<T>?,
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

export type Config = {
	template: { [string]: any },
	useMock: boolean?,
}

export type Bank = typeof(setmetatable(
	{} :: {
		_name: string,
		_template: { [string]: any },
		_useMock: boolean?,
		_bank: ProfileStore<any>,
		_vaults: { [Player]: Vault<any> },
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
		self._bank = self._bank.Mock :: ProfileStore<any>
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
