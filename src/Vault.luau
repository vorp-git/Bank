--!strict
local Vault = {}
Vault.__index = Vault

export type Vault = typeof(setmetatable(
	{} :: {
		_profile: any,
	},
	Vault
))

function Vault.new<T>(profile): Vault
	local self = setmetatable({}, Vault) :: Vault

	self._profile = profile

	return self
end

function Vault.get(self: Vault, key: string): any?
	if self._profile.Data[key] then
		return self._profile.Data[key]
	end

	return nil
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

return Vault
