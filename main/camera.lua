local M = {}

local camera_is_locked
local camera_drag_pressed_time
local camera_drag_pressed_position
local camera_drag_camera_euler_z
local camera_drag_camera_euler_x
local camera_drag_last_positions = {}
local camera_drag_history_duration = 0.25 -- Time window in seconds for calculating drag speed

function M.set_camera_locked(locked)
	camera_is_locked = locked
end

function M.on_input(self, action_id, action)

	if not camera_is_locked then
		if action_id == hash("touch") then

			if action.pressed then

				-- Store the time and position when touch is pressed
				camera_drag_pressed_time = socket.gettime()
				camera_drag_pressed_position = vmath.vector3(action.screen_x, action.screen_y, 0)
				-- Store initial camera Euler angles
				camera_drag_camera_euler_z = go.get("/rotation", "euler.z")
				camera_drag_camera_euler_x = go.get("/tilt", "euler.x")

				-- Clear position history
				camera_drag_last_positions = {}
				table.insert(camera_drag_last_positions, {position = camera_drag_pressed_position, time = camera_drag_pressed_time})

				go.cancel_animations("/rotation", "euler.z")
				go.cancel_animations("/tilt", "euler.x")

			elseif action.released then

				-- Get the current time and position on release
				local released_time = socket.gettime()
				local release_position = vmath.vector3(action.screen_x, action.screen_y, 0)

				-- Remove history entries older than the defined camera_drag_history_duration (0.25 seconds)
				while #camera_drag_last_positions > 0 and (released_time - camera_drag_last_positions[1].time) > camera_drag_history_duration do
					table.remove(camera_drag_last_positions, 1)
				end

				-- Calculate drag speed based on the most recent position in the last 0.25 seconds
				if #camera_drag_last_positions > 0 then
					local last_position_data = camera_drag_last_positions[1]
					local drag_vector = last_position_data.position - release_position
					local drag_duration = released_time - last_position_data.time

					-- Calculate drag speed (distance/time) for the last 0.25 seconds
					local drag_speed_x = drag_vector.x / drag_duration * 0.01 -- Drag speed for rotation
					local drag_speed_y = drag_vector.y / drag_duration * 0.01 -- Drag speed for tilt

					-- Animate rotation (Z-axis)
					local current_euler_z = go.get("/rotation", "euler.z")
					local new_euler_z = current_euler_z + drag_speed_x
					go.animate("/rotation", "euler.z", go.PLAYBACK_ONCE_FORWARD, new_euler_z, go.EASING_OUTEXPO, 0.5)

					-- Animate tilt (X-axis)
					local current_euler_x = go.get("/tilt", "euler.x")
					local new_euler_x = current_euler_x - drag_speed_y
					-- Clamp tilt to avoid flipping
					new_euler_x = math.max(-90, math.min(90, new_euler_x))
					go.animate("/tilt", "euler.x", go.PLAYBACK_ONCE_FORWARD, new_euler_x, go.EASING_OUTEXPO, 0.5)
				end

			else

				-- Handle dragging to adjust rotation and tilt
				local current_time = socket.gettime()
				local position = vmath.vector3(action.screen_x, action.screen_y, 0)
				local drag_vector = camera_drag_pressed_position - position

				-- Update position history
				table.insert(camera_drag_last_positions, {position = position, time = current_time})
				-- Remove history entries older than the defined camera_drag_history_duration (0.25 seconds)
				while #camera_drag_last_positions > 0 and (current_time - camera_drag_last_positions[1].time) > camera_drag_history_duration do
					table.remove(camera_drag_last_positions, 1)
				end

				-- Update rotation (Z-axis)
				local new_euler_z = camera_drag_camera_euler_z + (drag_vector.x * 0.1)
				go.set("/rotation", "euler.z", new_euler_z)

				-- Update tilt (X-axis)
				local new_euler_x = camera_drag_camera_euler_x - (drag_vector.y * 0.1)
				-- Clamp tilt to avoid flipping
				new_euler_x = math.max(-90, math.min(90, new_euler_x))
				go.set("/tilt", "euler.x", new_euler_x)

			end

		end
	end

end

return M