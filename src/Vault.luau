--!strict
const dependencies = script.Parent.Parent :: Folder
const deepClone = require(script.Parent.utils.deepClone)
const deepFreeze = require(script.Parent.utils.deepFreeze)
const Signal = require(dependencies:FindFirstChild("Signal")) :: any
const Janitor = require(dependencies:FindFirstChild("Janitor")) :: any

const Vault = {}
Vault.__index = Vault

export type Vault = typeof(setmetatable(
	{} :: {
		_profile: any,
		_data: any,
		_changed: any,
		_janitor: any,
	},
	Vault
))

const function cloneAndFreeze(target: { any }): any
	if type(target) ~= "table" then
		return target
	end

	const clone = deepClone(target)
	deepFreeze(clone)

	return clone
end

function Vault.new(profile: any): Vault
	const self = setmetatable({}, Vault) :: Vault

	self._profile = profile
	self._data = self._profile.Data
	self._janitor = Janitor.new()
	self._changed = Signal.new()

	return self
end

function Vault.get(self: Vault, key: string | { string }?): any
	if typeof(key) == "table" then
		local current = self._data

		for i = 1, #key do
			current = current[key[i]]
		end

		return cloneAndFreeze(current)
	end

	if not key then
		return cloneAndFreeze(self._data)
	end

	return cloneAndFreeze(self._data[key])
end

function Vault.set(self: Vault, key: string | { string }, value: any): ()
	self:update(key, function()
		return value
	end)
end

function Vault.update(self: Vault, key: string | { string }, callback: (any) -> any): ()
	if typeof(key) == "table" then
		local current = self._data

		for i = 1, #key - 1 do
			current = current[key[i]]
		end

		const new = callback(current[key[#key]])
		current[key[#key]] = new
		self._changed:Fire(key, new)

		return
	end

	const new = callback(self._data[key])
	self._data[key] = new
	self._changed:Fire(key, new)
end

function Vault.increment(self: Vault, key: string, amount: number): ()
	self:update(key, function(prev)
		return prev + amount
	end)
end

function Vault.decrement(self: Vault, key: string, amount: number): ()
	self:increment(key, -amount)
end

function Vault.onChanged(self: Vault, callback: (key: string, value: any) -> ()): ()
	self._janitor:Add(self._changed:Connect(callback))
end

function Vault.onLastSave(self: Vault, callback: (reason: "Manual" | "External" | "Shutdown") -> ()): ()
	self._janitor:Add(self._profile.OnLastSave:Connect(callback))
end

function Vault.release(self: Vault): ()
	self._profile:EndSession()
end

function Vault.destroy(self: Vault): ()
	self._janitor:Destroy()
	self._profile = nil
	self._data = nil
end

return Vault
