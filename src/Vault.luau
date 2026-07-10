--!strict
const Signal = require(script.Parent.Parent.Signal) :: any

local Vault = {}
Vault.__index = Vault

export type Vault = typeof(setmetatable(
	{} :: {
		_profile: any,
		_changed: any,
	},
	Vault
))

function Vault.new(profile): Vault
	local self = setmetatable({}, Vault) :: Vault

	self._profile = profile
	self._changed = Signal.new()

	return self
end

function Vault.get(self: Vault, key: string): any?
	if not self._profile.Data[key] then
		return
	end

	return self._profile.Data[key]
end

function Vault.getData(self: Vault): {}
	return self._profile.Data
end

function Vault.set(self: Vault, key: string, value: any): ()
	if self._profile.Data[key] ~= nil then
		self._profile.Data[key] = value
		self._changed:Fire(key, value)
	end
end

function Vault.increment(self: Vault, key: string, amount: number): ()
	self:update(key, function(current: number): number
		return current + amount
	end)
end

function Vault.decrement(self: Vault, key: string, amount: number): ()
	self:update(key, function(current: number): number
		return current - amount
	end)
end

function Vault.update(self: Vault, key: string, callback: (number) -> number): ()
	const current = self._profile.Data[key]
	if current ~= nil then
		const new = callback(current)
		self._profile.Data[key] = new
		self._changed:Fire(key, new)
	end
end

function Vault.onLastSave(self: Vault, callback: (reason: "Manual" | "External" | "Shutdown") -> ())
	const connection = self._profile.OnLastSave:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function Vault.onChanged(self: Vault, callback: (key: string, value: any) -> ()): ()
	const connection = self._changed:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function Vault.destroy(self: Vault): ()
	self._profile = nil
end

return Vault
