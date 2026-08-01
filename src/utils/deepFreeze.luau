--!strict
const function deepFreeze(target: { any })
	table.freeze(target)

	for _, value in target do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
end

return deepFreeze
