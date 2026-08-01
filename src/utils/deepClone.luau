--!strict
const function deepClone(original: { any })
	const clone = table.clone(original)

	for key, value in original do
		if type(value) == "table" then
			clone[key] = deepClone(value)
		end
	end

	return clone
end

return deepClone
