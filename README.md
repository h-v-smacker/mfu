# MFU mod for Minetest game

The MFU if a multifunction device. It combines three machines: a photocopier, a networking printer, and a bindinig machine. The last element means that if you give the MFU loose paper sheets, the output will be books nonetheless.

It accepts commands from digiline cable and can act as a networking printer.

It is also integrated with pipeworks, and can accept paper and books in its input inventory, and send output away as well. Which will be needed in mass-production of books, since the built-in slot can only hold 16 written books. However, it won't connect from the front or top, because realism.

The digiline operations aren't just one command, so sending "USERGUIDE" to the MFU on its digiline channel will print you the user's guide.

The crafting recipes are conditional on presence of several mods, so I'll just copy-paste the relevant code snippet here:

```
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

```