-- a machine to copy books

local S

if minetest.get_modpath( "intllib" ) and intllib then
	S = intllib.Getter()
else
	S = function(s) return s end
end


local prepare_formspec = function(channel)
-- 	local label = "nothing"
-- 	local item = "air"
-- 	local hint = ""
-- 	local percent = 0
-- 	if contents then
-- 		hint = liquids[contents].name
-- 		label = contents
-- 		item = liquids[contents].bucket
-- 	end
-- 	if fill then 
-- 		percent = 100 * fill / barrel_max
-- 	end
-- 	
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
	  
	if inv:room_for_item ("output", copy) then
		if inv:contains_item("input", {name = "default:book", count = 1}) then
			inv:remove_item("input", {name = "default:book", count = 1})
		elseif inv:contains_item("input", {name = "default:paper", count = 3}) then
			inv:remove_item("input", {name = "default:paper", count = 3})
		end
		inv:add_item("output", copy)
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
                                          
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.set then
			minetest.chat_send_all(fields.channel)
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
                                   
	on_construct = function( pos )
		return on_construct( pos )
	end,
                                   
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.set then
			minetest.chat_send_all(fields.channel)
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
