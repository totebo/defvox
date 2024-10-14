local magicavoxel = require "magicavoxel"
local rendy = require "rendy.rendy"

local M = {}

local SWIPE_RAY_LENGTH = 10000
local TTL = 0.25

local dig_pressed_time
local dig_pressed_position
local total_drag_distance

local voxels = {}

local voxel_touched
local is_digging

local function create_voxel(position, color)

	local game_object = factory.create("/go#voxel_factory", position)
	local cube_model = msg.url(nil, game_object, "model") 
	go.set(cube_model, "tint", color)
	voxels[game_object] = {
		ttl = TTL,
	}
	
end

local function delete_voxel(game_object)

	go.delete(game_object, true)
	voxels[game_object] = nil
	if game_object == voxel_touched then
		voxel_touched = nil
	end

end

function M.load()
	local magicavoxel_data = magicavoxel.load("/custom_resources/test.vox")
	for model_index, model in ipairs(magicavoxel_data.models) do
		for _, voxel in ipairs(model.voxels) do
			local color = magicavoxel.get_color(voxel.color_index)
			create_voxel(voxel.world_position, color)
		end
	end
end

local function dig(x, y)

	local rendy_id = go.get_id("/rendy")
	local position_start = vmath.vector3(x, y, -SWIPE_RAY_LENGTH/2)
	local position_end = vmath.vector3(x, y, SWIPE_RAY_LENGTH/2)
	local ray_start = rendy.screen_to_world(rendy_id, position_start)
	local ray_end = rendy.screen_to_world(rendy_id, position_end)

	local hit = physics.raycast(ray_start, ray_end, {hash("voxel")})

	if not hit then
		-- Not hitting a voxel_touched

		-- Reset previously touched voxel ttl
		if voxel_touched then
			local voxel = voxels[voxel_touched]
			voxel.ttl = TTL
		end

		-- Remove reference
		voxel_touched = nil

	else

		-- Touching a voxel

		if voxel_touched ~= hit.id then
			
			-- Reset previously touched voxel ttl
			if voxel_touched then
				local voxel = voxels[voxel_touched]
				voxel.ttl = TTL
			end

			-- Set new touched voxel reference
			voxel_touched = hit.id

		end

	end

end

function M.on_input(self, action_id, action)

	if action_id == hash("touch") then
		if action.pressed then

			total_drag_distance = 0
			dig_pressed_time = socket.gettime()
			dig_pressed_position = vmath.vector3(action.screen_x, action.screen_y, 0)

		elseif action.released then

			voxel_touched = nil
			is_digging = false

		else

			if not is_digging then
				local position = vmath.vector3(action.screen_x, action.screen_y, 0)
				local drag_distance = vmath.length(dig_pressed_position - position)
				total_drag_distance = total_drag_distance + drag_distance
				local drag_duration = socket.gettime() - dig_pressed_time
				if drag_duration > 0.35 and total_drag_distance < 50 then
					is_digging = true
				end
			else
				dig(action.screen_x, action.screen_y)
			end
			
		end

		return is_digging

	end

end

function M.update(self, dt)

	if voxel_touched then

		local voxel = voxels[voxel_touched]
		local new_ttl = voxel.ttl - dt
		if new_ttl <= 0 then
			delete_voxel(voxel_touched)
			return
		end
		voxel.ttl = new_ttl
		
	end
	
end

return M