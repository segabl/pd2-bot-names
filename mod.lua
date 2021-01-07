if not BotNames then

	BotNames = {}
	BotNames.mod_path = ModPath
	BotNames.settings = {
		source = 1,
		group = "modworkshop"
	}
	BotNames.params = {
		source = { priority = 2, items = { "menu_bot_names_group", "menu_bot_names_friends" } },
		group = { priority = 1, callback = function ()
			os.remove(SavePath .. "bot_names_cache.txt")
		end }
	}
	BotNames.names = {}
	BotNames.host_names = {}
	BotNames.nick_names = {}
	BotNames.name_index = 1
	BotNames.menu_builder = MenuBuilder:new("bot_names", BotNames.settings, BotNames.params)

	function BotNames:fetch_group_names()

		local members = {}
		local url = "https://steamcommunity.com/" .. (tonumber(self.settings.group) and "gid/" or "groups/") .. self.settings.group .. "/memberslistxml/?xml=1"
		local file = io.open(SavePath .. "bot_names_cache.txt", "r")
		if file then
			members = json.decode(file:read("*all"))
			file:close()
		end

		local function fetch_member_names()
			local num_names = math.min(BigLobbyGlobals and BigLobbyGlobals.num_bot_slots and BigLobbyGlobals:num_bot_slots() or tweak_data.max_players - 1, #members)
			for _ = 1, num_names do
				local index = math.random(#members)
				local member = members[index]
				table.remove(members, index)
				Steam:http_request("https://steamcommunity.com/profiles/" .. member .. "/?xml=1", function (success, data)
					if not success then
						return
					end
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
			Steam:http_request(url, function (success, data)
				if not success then
					return
				end
				for id in data:gmatch("<steamID64>([0-9]+)</steamID64>") do
					table.insert(members, id)
				end
				url = data:match("<nextPageLink><!%[CDATA%[(.+)%]%]></nextPageLink>")
				if url then
					fetch_members()
				else
					file = io.open(SavePath .. "bot_names_cache.txt", "w+")
					if file then
						file:write(json.encode(members))
						file:close()
					end
					fetch_names()
				end
			end)
		end

		if #members == 0 then
			fetch_members()
		else
			fetch_member_names()
		end

	end

	function BotNames:fetch_friend_names()

		local friends = {}
		for _, v in pairs(Steam:friends()) do
			table.insert(friends, v:name())
		end
		local num_names = math.min(BigLobbyGlobals and BigLobbyGlobals.num_bot_slots and BigLobbyGlobals:num_bot_slots() or tweak_data.max_players - 1, #friends)
		for _ = 1, num_names do
			local index = math.random(#friends)
			local friend = friends[index]
			table.remove(friends, index)
			table.insert(self.names, friend)
		end
		if Network:is_server() then
			DelayedCalls:Add("send_bot_names", 2, function ()
				LuaNetworking:SendToPeers("bot_names", json.encode(self.names))
			end)
		end

	end

	function BotNames:fetch_names()
		self.names = {}
		if self.settings.source == 1 then
			self:fetch_group_names()
		else
			self:fetch_friend_names()
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

	BotNames:fetch_names()

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
		if peer:character() then
			BotNames.nick_names[peer:character()] = peer:name()
		end
	end)

end
