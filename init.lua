-- a machine to copy books

minetest.register_node("mfu:mfu_active", {
     description = "Multifunction Unit",
     tiles = {	{name="mfu_top_active.png", 
				animation={type="vertical_frames",
				aspect_w=32, 
				aspect_h=32, 
				length=3}}, 
			"mfu_bottom.png",
			"mfu_front_active.png",
			"mfu_back.png",
			"mfu_side.png",
			"mfu_side.png"},
     groups = {cracky = 1},
     light_source = 3,
     drop = "",
--      can_dig = function(pos, player)
--           return false
--      end
})


minetest.register_node("mfu:mfu", {
     description = "Multifunction Unit",
	tiles = {	"mfu_top.png",
			"mfu_bottom.png",
			"mfu_front.png",
			"mfu_back.png",
			"mfu_side.png",
			"mfu_side.png"},
     groups = {cracky = 1},
--      light_source = 5,
     drop = "",
--      can_dig = function(pos, player)
--           return false
--      end
})
