--!strict
local Vault = {}
Vault.__index = Vault

export type Vault = typeof(setmetatable(
	{} :: {
		_profile: any,
	},
	Vault
))

function Vault.new(profile): Vault
	local self = setmetatable({}, Vault) :: Vault

	self._profile = profile

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
	if self._profile.Data[key] then
		self._profile.Data[key] = value
	end
end

function Vault.increment(self: Vault, key: string, amount: number): ()
	if self._profile.Data[key] then
		self._profile.Data[key] += amount
	end
end

function Vault.decrement(self: Vault, key: string, amount: number): ()
	self:increment(key, -amount)
end

function Vault.update(self: Vault, key: string, callback: (...number) -> number): ()
	local current = self._profile.Data[key]
	if current ~= nil then
		self._profile.Data[key] = callback(current)
	end
end

function Vault.onLastSave(self: Vault, callback: (reason: "Manual" | "External" | "Shutdown") -> ())
	self._profile.OnLastSave:Connect(function(reason)
		callback(reason)
	end)
end

function Vault.destroy(self: Vault): ()
	self._profile = nil
end

return Vault
