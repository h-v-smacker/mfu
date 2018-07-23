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
	local meta = minetest.get_meta(pos);
	local listen_on = meta:get_string('digiline_channel')
	local inv = meta:get_inventory()
	
	if listen_on and channel == listen_on and msg.command and msg.command == "STATUS" then
		
		if not inv:contains_item("input", {name = "default:book", count = 1}) and 
			not inv:contains_item("input", {name = "default:paper", count = 3}) then
			digilines.receptor_send(pos, digilines.rules.default, channel, "NO PAPER")
		elseif not inv:room_for_item("output", {name = "default:book_written", count = 1}) then
			digilines.receptor_send(pos, digilines.rules.default, channel, "OUTPUT FULL")
		elseif not inv:is_empty("master") then
			digilines.receptor_send(pos, digilines.rules.default, channel, "COPYING")
		else
			digilines.receptor_send(pos, digilines.rules.default, channel, "IDLE")
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
			
				digilines.receptor_send(pos, digilines.rules.default, channel, "NO PAPER")
				
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
				digilines.receptor_send(pos, digilines.rules.default, channel, "OK")
			else
				digilines.receptor_send(pos, digilines.rules.default, channel, "FULL @ " .. msg.copies - n .. "/" .. msg.copies)
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
	groups = {cracky = 1, not_in_creative_inventory = 1},
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
	groups = {cracky = 1},
	
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

	
})
