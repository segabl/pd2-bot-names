if not BotNames then

	BotNames = {}
	BotNames.mod_path = ModPath
	BotNames.settings = {
		group = "modworkshop"
	}
	BotNames.members = {}
	BotNames.names = {}
	BotNames.host_names = {}
	BotNames.nick_names = {}
	BotNames.name_index = 1
	BotNames.menu_builder = MenuBuilder:new("bot_names", BotNames.settings)

	function BotNames:fetch_random_names()

		local url = "https://steamcommunity.com/" .. (tonumber(self.settings.group) and "gid/" or "groups/") .. self.settings.group .. "/memberslistxml/?xml=1"
		local file = io.open(SavePath .. "bot_names_" .. self.settings.group .. ".txt", "r")
		if file then
			self.members = json.decode(file:read("*all"))
			file:close()
		end

		local function fetch_names()
			local num_names = math.min(tweak_data.max_players - 1, #self.members)
			for _ = 1, num_names do
				local index = math.random(#self.members)
				local member = self.members[index]
				table.remove(self.members, index)
				dohttpreq("https://steamcommunity.com/profiles/" .. member .. "/?xml=1", function (data)
					local name = data:match("<steamID><!%[CDATA%[(.+)%]%]></steamID>")
					if name then
						table.insert(self.names, name)
						if #self.names >= num_names and Network:is_server() then
							LuaNetworking:SendToPeers("bot_names", json.encode(self.names))
						end
					end
				end)
			end
		end

		local function fetch_members()
			dohttpreq(url, function (data)
				for id in data:gmatch("<steamID64>([0-9]+)</steamID64>") do
					table.insert(self.members, id)
				end
				url = data:match("<nextPageLink><!%[CDATA%[(.+)%]%]></nextPageLink>")
				if url then
					fetch_members()
				else
					file = io.open(SavePath .. "bot_names_" .. self.settings.group .. ".txt", "w+")
					if file then
						file:write(json.encode(self.members))
						file:close()
					end
					fetch_names()
				end
			end)
		end

		if #self.members == 0 then
			fetch_members()
		else
			fetch_names()
		end

	end

	function BotNames:get_name()
		local name = BotNames.host_names[BotNames.name_index] or BotNames.names[BotNames.name_index]
		BotNames.name_index = BotNames.name_index + 1
		return name
	end

	Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitBotNames", function (loc)
		HopLib:load_localization(BotNames.mod_path .. "loc/", loc)
	end)

	Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusBotNames", function(menu_manager, nodes)
		BotNames.menu_builder:create_menu(nodes)
	end)

	Hooks:Add("NetworkReceivedData", "NetworkReceivedDataBotNames", function(sender, id, data)
		if sender == 1 and id == "bot_names" then
			BotNames.host_names = json.decode(data)
		end
	end)

end

if RequiredScript == "lib/units/player_team/teamaibase" then

	BotNames:fetch_random_names()

	local nick_name_original = TeamAIBase.nick_name
	function TeamAIBase:nick_name(...)
		if not BotNames.nick_names[self._tweak_table] then
			BotNames.nick_names[self._tweak_table] = BotNames:get_name() or nick_name_original(self, ...)
		end
		return BotNames.nick_names[self._tweak_table]
	end

end

if RequiredScript == "lib/network/base/basenetworksession" then

	Hooks:PreHook(BaseNetworkSession, "_on_peer_removed", "_on_peer_removed_bot_names", function (self, peer)
		BotNames.nick_names[peer:character()] = peer:name()
	end)

end
