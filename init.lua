-- a machine to copy books

local S

if minetest.get_modpath( "intllib" ) and intllib then
	S = intllib.Getter()
else
	S = function(s) return s end
end


local prepare_formspec = function(channel)

	local c = ''
	if channel then
		c = channel
	end
		
	local formspec =  "size[8,9]"..
	
				"label[0,0;"..S("Paper:").."]"..
				"list[context;input;0,0.5;3,3;]"..
				
				"label[3,0;"..S("Master:").."]"..
				"list[context;master;3,0.5;1,1;]"..
				
				"button_exit[3,1.5;1,1;quit;" .. S("Quit") .. "]"..
				"button_exit[3,2.5;1,1;set;" .. S("Save") .. "]"..
	
				"label[4,0;"..S("Copies:").."]"..
				"list[context;output;4,0.5;4,4;]"..
				
				"field[0.25,4;4,1;channel;" .. S("Digiline channel:") .. ";" .. c .. "]"..
				
				"list[current_player;main;0,5;8,4;]"
				
	return (formspec)
end


local on_construct = function( pos )

	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	
	inv:set_size("input", 9)
	inv:set_size("output", 16)
	inv:set_size("master", 1)
	meta:set_string('digiline_channel', "")
	meta:set_string('formspec', prepare_formspec())
	meta:set_string('infotext', S("MFU Idle"))

end


local mfu_allow_metadata_inventory_put = function(pos, listname, index, stack, player)
	local iname = stack:get_name()                              
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	
	if listname == "input" then
	
		if (iname == "default:book" or iname == "default:paper") and inv:room_for_item("input", stack) then
			return stack:get_count()
		else
			return 0
		end
		
	end
                                      
	if listname == "output" then
		return 0
	end
	
	if listname == "master" then
		if iname == "default:book_written" and inv:room_for_item("master", stack) then
			return 1
		else 
			return 0
		end
	end
                                      
end

local mfu_allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
	if to_list == "input" then
		return 99
	else
		return 0
	end
end

local mfu_copy = function(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	
	if inv:is_empty("master") then
		return
	end
	
	local input = inv:get_list("input")
	local output = inv:get_list("output")
	local master = inv:get_list("master")
	
	local master_copy = inv:get_stack("master", 1)
	local master_contents = master_copy:get_meta():to_table()

	-- mark the copy
	if not master_contents.fields.owner then
		master_contents.fields.owner = "???"
	end
	master_contents.fields.owner = master_contents.fields.owner .. S(" (copy)")
        
	local copy = ItemStack({name = "default:book_written", count = 1})
	copy:get_meta():from_table(master_contents)
	  
	if inv:room_for_item("output", copy) then
		if inv:contains_item("input", {name = "default:book", count = 1}) then
			inv:remove_item("input", {name = "default:book", count = 1})
			inv:add_item("output", copy)
		elseif inv:contains_item("input", {name = "default:paper", count = 3}) then
			inv:remove_item("input", {name = "default:paper", count = 3})
			inv:add_item("output", copy)
		end
		
	end
	
	-- and continue [trying] making copies as long as there's a master copy in the slot
	local timer = minetest.get_node_timer(pos)
	timer:start(1)
	
end

local mfu_can_dig = function(pos, player)

	local name = player:get_player_name()
	if minetest.is_protected(pos, name) then
		minetest.record_protection_violation(pos, name)
		return false
	end

	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	
	return (inv:is_empty("input") and inv:is_empty("output") and inv:is_empty("master"))
	
end

local mfu_on_digiline_receive = function (pos, _, channel, msg)

	if type(msg) ~= "table" then return end
	
	local meta = minetest.get_meta(pos);
	local listen_on = meta:get_string('digiline_channel')
	local inv = meta:get_inventory()
	
	if listen_on and channel == listen_on and msg.command and msg.command == "STATUS" then
		
		if not inv:contains_item("input", {name = "default:book", count = 1}) and 
			not inv:contains_item("input", {name = "default:paper", count = 3}) then
			digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "NO PAPER" })
		elseif not inv:room_for_item("output", {name = "default:book_written", count = 1}) then
			digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OUTPUT FULL" })
		elseif not inv:is_empty("master") then
			digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "COPYING" })
		else
			digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "IDLE" })
		end
		
		return
	end
	
	
	if listen_on and channel == listen_on and msg.command and msg.command == "SUPPLIES" then
		
		local data = {
			["default:paper"] = 0,
			["default:book"] = 0,
			empty = 0,
		}
		
		for i = 1,9,1 do
			local s = inv:get_stack("input", i)
			if not s:is_empty() then
				local name = s:get_name()
				data[name] = data[name] + s:get_count()
			else 
				data.empty = data.empty + 1
			end
		end
		
		local message = {
			STATUS = "OK",
			FREE = data.empty,
			PAPER = tonumber(data["default:paper"]),
			BOOKS = tonumber(data["default:book"]),
			COPIES = math.floor(tonumber(data["default:paper"]) / 3) + tonumber(data["default:book"]),
		}
		
		digilines.receptor_send(pos, digilines.rules.default, channel, message)
		
		return
	end
	
	
	if listen_on and channel == listen_on and msg.command and msg.command == "EJECT" then

		local node = minetest.get_node(pos)
		local pos1 = vector.new(pos)
		
		local x_velocity = 0
		local z_velocity = 0
		
		-- Output always on the right
		if node.param2 == 3 then pos1.z = pos1.z + 1  z_velocity =  1 end
		if node.param2 == 2 then pos1.x = pos1.x - 1  x_velocity = -1 end
		if node.param2 == 1 then pos1.z = pos1.z - 1  z_velocity = -1 end
		if node.param2 == 0 then pos1.x = pos1.x + 1  x_velocity =  1 end
		
		local node1 = minetest.get_node(pos1) 
		if not (minetest.get_item_group(node1.name, "tubedevice") > 0) then
			digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "NOT CONNECTED" })
			return
		end
		
		local n = 0
		
		for i = 1,16,1 do
			local s = inv:get_stack("output", i)
			if not s:is_empty() then
				local r = pipeworks.tube_inject_item(pos, pos, vector.new(x_velocity, 0, z_velocity), s:to_table(), nil)
				if r then
					s:clear()
					inv:set_stack("output", i, stack)
					n = n + 1
				else
					digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "MALFUNCTION" })
					return
				end
			end
		end
				
		digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OK", COUNT = n })
		
		return
	end
	
	
	if listen_on and channel == listen_on and msg.command == "USERGUIDE" then
		local file = io.open (minetest.get_modpath("mfu") .. "/manual.txt")
		local manual = file:read("*all")
		io.close(file)
		
		local lpp = 14
		
		local book = ItemStack({name = "default:book_written", count = 1})
		local data = {}
		data.owner = S("MFU (itself)")
		data.title = S("MFU User Guide")
		data.description = S("Setup and operations manual for MFU ver. 1 rev. 1")
		data.text = manual
		data.page = 1
		data.page_max = math.ceil((#data.text:gsub("[^\n]", "") + 1) / lpp) + 1
		
		book:get_meta():from_table({ fields = data })
		
		if inv:room_for_item("output", book) then
			inv:add_item("output", book)
			digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OK" })
		else
			digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OUTPUT FULL" })
		end
		
		return
		
	end
	
	
	if listen_on and channel == listen_on and msg.command and msg.command == "PRINT" and msg.copies and tonumber(msg.copies) > 0 then
		
		-- default book settings
		local max_text_size = 10000
		local max_title_size = 80
		local short_title_size = 35
		local lpp = 14
		
		-----
		local book = ItemStack({name = "default:book_written", count = 1})
		local data = {}

		data.owner = S("MFU (automatic)")
		if msg.author then
			data.owner = msg.author .. S(" (printed)")
		end

		data.title = S("Untitled")
		if msg.title then
			data.title = msg.title:sub(1, max_title_size)
		end
		
		local short_title = data.title
		-- Don't bother triming the title if the trailing dots would make it longer
		if #short_title > short_title_size + 3 then
			short_title = short_title:sub(1, short_title_size) .. "..."
		end
		data.description = "\""..short_title.."\" by "..data.owner
		data.text = msg.text:sub(1, max_text_size)
		data.text = data.text:gsub("\r\n", "\n"):gsub("\r", "\n")
		data.page = 1
		data.page_max = math.ceil((#data.text:gsub("[^\n]", "") + 1) / lpp)

		if msg.watermark then
			data.watermark = msg.watermark
		end
		
		book:get_meta():from_table({ fields = data })
		
		-----
		
		if not inv:contains_item("input", {name = "default:book", count = 1}) and 
			not inv:contains_item("input", {name = "default:paper", count = 3}) then
			
				digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "NO PAPER" })
				
		else

		
			local n = tonumber(msg.copies)
			
			while inv:room_for_item("output", book) and n > 0 do
				
				if inv:contains_item("input", {name = "default:book", count = 1}) then
					inv:remove_item("input", {name = "default:book", count = 1})
					inv:add_item("output", book)
					n = n - 1
				elseif inv:contains_item("input", {name = "default:paper", count = 3}) then
					inv:remove_item("input", {name = "default:paper", count = 3})
					inv:add_item("output", book)
					n = n - 1
				else
					break
				end
				
			end
			
			if n == 0 then
				digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OK", COUNT = msg.copies })
			else
				digilines.receptor_send(pos, digilines.rules.default, channel, { STATUS = "OUTPUT FULL", COUNT = msg.copies - n, DROPPED = n })
			end
			
		end
		
	end
end

minetest.register_node("mfu:mfu_active", {
	description = "Multifunction Unit",
	tiles = {	{name="mfu_top_active.png", 
				animation={type="vertical_frames",
				aspect_w=32, 
				aspect_h=32, 
				length=3}}, 
			"mfu_bottom.png",
			"mfu_side.png",
			"mfu_side.png",
			"mfu_back.png",
			"mfu_front_active.png",
			},
	groups = {cracky = 1, not_in_creative_inventory = 1, tubedevice = 1, tubedevice_receiver = 1},
	light_source = 3,
	
	allow_metadata_inventory_put = mfu_allow_metadata_inventory_put,
	allow_metadata_inventory_move = mfu_allow_metadata_inventory_move,
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "mfu:mfu",
	can_dig = mfu_can_dig,
                 
	digiline =
	{
		receptor = {},
		effector = {
			action = mfu_on_digiline_receive
		},
	},
                                          
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.set then
			local meta = minetest.get_meta(pos);
			meta:set_string('digiline_channel', fields.channel)
			meta:set_string('formspec', prepare_formspec(fields.channel))
            end                      
	end,
                                   
	on_timer = mfu_copy,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "master" then
			local timer = minetest.get_node_timer(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string('infotext', S("MFU Active"))
			minetest.swap_node(pos, {name = "mfu:mfu_active", param2 = minetest.get_node(pos).param2})
			timer:start(1)
		end
	end,
                                   
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		if listname == "master" then
			local timer = minetest.get_node_timer(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string('infotext', S("MFU Idle"))
			minetest.swap_node(pos, {name = "mfu:mfu", param2 = minetest.get_node(pos).param2})
			timer:stop()
		end
	end,
                                          
                                          
	tube = (function() if minetest.get_modpath("pipeworks") then return {
		-- using a different stack from defaut when inserting
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("input", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if stack:get_name() == "default:paper" or stack:get_name() == "default:book" then
				return inv:room_for_item("input", stack)
			else
				return false
			end
		end,
		-- the default stack, from which objects will be taken
		input_inventory = "output",
		connect_sides = {left = 1, right = 1, back = 1, bottom = 1,}
	} end end)(),

                                          
})


minetest.register_node("mfu:mfu", {
	description = "Multifunction Unit",
	tiles = {	"mfu_top.png",
			"mfu_bottom.png",
			"mfu_side.png",
			"mfu_side.png",
			"mfu_back.png",
			"mfu_front.png",
			},
	groups = {cracky = 1, tubedevice = 1, tubedevice_receiver = 1},
	
	on_place = minetest.rotate_node,
                                   
	allow_metadata_inventory_put = mfu_allow_metadata_inventory_put,
	allow_metadata_inventory_move = mfu_allow_metadata_inventory_move,
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "mfu:mfu",
	can_dig = mfu_can_dig,
                  
	digiline =
	{
		receptor = {},
		effector = {
			action = mfu_on_digiline_receive
		},
	},
                                   
	on_construct = function( pos )
		return on_construct( pos )
	end,
                                   
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.set then
			local meta = minetest.get_meta(pos);
			meta:set_string('digiline_channel', fields.channel)
			meta:set_string('formspec', prepare_formspec(fields.channel))
            end                      
	end,
                                   
	on_timer = mfu_copy,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		if listname == "master" then
			local timer = minetest.get_node_timer(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string('infotext', S("MFU Active"))
			minetest.swap_node(pos, {name = "mfu:mfu_active", param2 = minetest.get_node(pos).param2})
			timer:start(1)
		end
	end,
                                   
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		if listname == "master" then
			local timer = minetest.get_node_timer(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string('infotext', S("MFU Idle"))
			minetest.swap_node(pos, {name = "mfu:mfu", param2 = minetest.get_node(pos).param2})
			timer:stop()
		end
	end,

	tube = (function() if minetest.get_modpath("pipeworks") then return {
		-- using a different stack from defaut when inserting
		insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("input", stack)
		end,
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if stack:get_name() == "default:paper" or stack:get_name() == "default:book" then
				return inv:room_for_item("input", stack)
			else
				return false
			end
		end,
		-- the default stack, from which objects will be taken
		input_inventory = "output",
		connect_sides = {left = 1, right = 1, back = 1, bottom = 1,}
	} end end)(),
	
})


local mfu_item_a = "default:meselamp"
if minetest.get_modpath("technic") and technic.mod == "linuxforks" then
	mfu_item_a = "technic:lv_led"
end

local mfu_item_b = "default:book"
if minetest.get_modpath("digilines") then
	mfu_item_b = "digilines:wire_std_00000000"
end

local mfu_item_c = "default:diamond"
if minetest.get_modpath("pipeworks") then
	mfu_item_c = "pipeworks:tube_1"
end


if minetest.get_modpath("technic") then
	
	minetest.register_craft({
		output = "mfu:mfu",
		recipe = {
				{"homedecor:plastic_sheeting", "default:obsidian_glass", "homedecor:plastic_sheeting"},
				{mfu_item_c, mfu_item_a, mfu_item_c},
				{"technic:stainless_steel_ingot", mfu_item_b, "technic:stainless_steel_ingot"},
			}
		})
	
else
	minetest.register_craft({
		output = "mfu:mfu",
		recipe = {
				{"default:copper_ingot", "default:obsidian_glass", "default:copper_ingot"},
				{mfu_item_c, mfu_item_a, mfu_item_c},
				{"default:steel_ingot", mfu_item_b, "default:steel_ingot"},
			}
		})
end
