if not BotNames then

	BotNames = {}
	BotNames.mod_path = ModPath
	BotNames.settings = {
		group = "modworkshop"
	}
	BotNames.members = {}
	BotNames.names = {}
	BotNames.nick_names = {}
	BotNames.name_index = 1
	BotNames.menu_builder = MenuBuilder:new("bot_names", BotNames.settings)

	function BotNames:fetch_group_member_names()

		local url = "https://steamcommunity.com/" .. (tonumber(self.settings.group) and "gid/" or "groups/") .. self.settings.group .. "/memberslistxml/?xml=1"
		local file = io.open(SavePath .. "bot_names_" .. self.settings.group .. ".txt", "r")
		if file then
			self.members = json.decode(file:read("*all"))
			file:close()
		end

		local function fetch_names()
			for _ = 1, tweak_data.max_players - 1 do
				local index = math.random(#self.members)
				local member = self.members[index]
				table.remove(self.members, index)
				dohttpreq("https://steamcommunity.com/profiles/" .. member .. "/?xml=1", function (data)
					local name = data:match("<steamID><!%[CDATA%[(.+)%]%]></steamID>")
					if name then
						table.insert(self.names, name)
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

	BotNames:fetch_group_member_names()

end

if RequiredScript == "lib/units/player_team/teamaibase" then

	local nick_name_original = TeamAIBase.nick_name
	function TeamAIBase:nick_name()
		if not BotNames.nick_names[self._tweak_table] then
			BotNames.nick_names[self._tweak_table] = BotNames.names[BotNames.name_index] or nick_name_original(self)
			BotNames.name_index = BotNames.name_index + 1
		end
		return BotNames.nick_names[self._tweak_table]
	end

end

if RequiredScript == "lib/managers/menumanager" then

	Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitStreamlinedHeisting", function (loc)
		HopLib:load_localization(BotNames.mod_path .. "loc/", loc)
	end)

	Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusBotNames", function(menu_manager, nodes)
		BotNames.menu_builder:create_menu(nodes)
	end)

end