--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const dependencies = script.Parent.Parent :: Folder

const Signal = require(dependencies:FindFirstChild("Signal")) :: any
const ProfileStore = if RunService:IsServer() then require(dependencies:FindFirstChild("ProfileStore")) :: any else nil
const Janitor = require(dependencies:FindFirstChild("Janitor")) :: any

export type Config = {
	template: { [string]: any },
	useMock: boolean?,
	leaderstats: { string }?,
}

export type BankAPI = {
	vaultLoaded: (callback: (player: Player, vault: VaultAPI) -> ()) -> (),
	getVault: (player: Player) -> VaultAPI,
}

export type Bank = {
	create: (name: string, config: Config) -> BankAPI,
}

export type State = {
	store: any,
	vaultLoadedSignal: any,
	profiles: { [Player]: VaultAPI },
	leaderstats: { string },
	template: { [string]: any },
}

export type VaultAPI = {
	get: (key: string?) -> any,
	set: (key: string, value: any) -> (),
	increment: (key: string, amount: number) -> (),
	decrement: (key: string, amount: number) -> (),
	update: (key: string, callback: (number) -> number) -> (),
	onChanged: (callback: (key: string, value: any) -> ()) -> (),
	onLastSave: (callback: (reason: "Manual" | "External" | "Shutdown") -> ()) -> (),
	destroy: () -> (),
	profile: any,
}

const function createVault(profile): VaultAPI
	const janitor = Janitor.new()
	const changedSignal = Signal.new()
	const data = profile.Data

	janitor:Add(changedSignal)

	const function get(key: string?): any
		if not key then
			return data
		end

		return data[key]
	end

	const function update(key: string, callback: (number) -> number): ()
		const new = callback(data[key])
		data[key] = new
		changedSignal:Fire(key, new)
	end

	const function set(key: string, value: any): ()
		update(key, function()
			return value
		end)
	end

	const function increment(key: string, amount: number): ()
		update(key, function(prev)
			return prev + amount
		end)
	end

	const function decrement(key: string, amount: number): ()
		increment(key, -amount)
	end

	const function onChanged(callback: (key: string, value: any) -> ())
		janitor:Add(changedSignal:Connect(callback))
	end

	const function destroy()
		janitor:Destroy()
	end

	const function onLastSave(callback: (reason: "Manual" | "External" | "Shutdown") -> ()): ()
		janitor:Add(profile.OnLastSave:Connect(callback))
	end

	return {
		get = get,
		set = set,
		increment = increment,
		decrement = decrement,
		update = update,
		onChanged = onChanged,
		onLastSave = onLastSave,
		destroy = destroy,
		profile = profile,
	}
end

const function sessionOptions(player: Player)
	return {
		Cancel = function()
			return player.Parent ~= Players
		end,
	}
end

const function acquireProfile(state: State, player: Player)
	return state.store:StartSessionAsync(`{player.UserId}`, sessionOptions(player))
end

const function initializeProfile(profile, player: Player)
	profile:AddUserId(player.UserId)
	profile:Reconcile()
end

const function connectSessionEnd(profile, state: State, player: Player): ()
	profile.OnSessionEnd:Connect(function()
		state.profiles[player].destroy()
		state.profiles[player] = nil
		player:Kick("Data session end - Please rejoin")
	end)
end

const function createLeaderstats(state: State, player: Player)
	const leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	for _, stat in state.leaderstats do
		if typeof(state.template[stat]) == "number" then
			const val = Instance.new("NumberValue")
			val.Name = stat
			val.Value = state.profiles[player].get(stat)
			val.Parent = leaderstats
		elseif typeof(state.template[stat]) == "string" then
			const val = Instance.new("StringValue")
			val.Name = stat
			val.Value = state.profiles[player].get(stat)
			val.Parent = leaderstats
		end
	end

	state.profiles[player].onChanged(function(key, value)
		for _, z: any in leaderstats:GetChildren() do
			if z.Name == key then
				z.Value = value
			end
		end
	end)
end

const function load(state: State, player: Player): ()
	const profile = acquireProfile(state, player)

	if not profile then
		player:Kick("Data load fail - Please rejoin")
		return
	end

	initializeProfile(profile, player)
	connectSessionEnd(profile, state, player)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	state.profiles[player] = createVault(profile)
	state.vaultLoadedSignal:Fire(player, state.profiles[player])

	if state.leaderstats then
		createLeaderstats(state, player)
	end
end

const function save(state: State, player: Player): ()
	const profile = state.profiles[player].profile
	if profile then
		profile:EndSession()
	end
end

const Bank = {} :: Bank

function Bank.create(name: string, config: Config): BankAPI
	const template = config.template
	const useMock = config.useMock or false
	const state: State = {
		template = template,
		store = ProfileStore.New(name, template),
		vaultLoadedSignal = Signal.new(),
		profiles = {},
		leaderstats = config.leaderstats or {},
	}

	if useMock then
		warn(`Mock enabled for Bank {name}`)
		state.store = state.store.Mock
	end

	for _, player in Players:GetPlayers() do
		task.spawn(load, state, player)
	end

	Players.PlayerAdded:Connect(function(player: Player): ()
		load(state, player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player): ()
		save(state, player)
	end)

	return {
		vaultLoaded = function(callback: (player: Player, vault: VaultAPI) -> ())
			state.vaultLoadedSignal:Connect(callback)
		end,

		getVault = function(player: Player)
			return state.profiles[player]
		end,
	}
end

return Bank
