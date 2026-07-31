--!strict
const function deepFreeze(target: { any })
	table.freeze(target)

	for _, value in target do
		if type(value) ~= "table" and table.isfrozen(value) then
			continue
		end

		deepFreeze(value)
	end
end

return deepFreeze
