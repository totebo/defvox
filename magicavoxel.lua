local M = {}
local colors = nil

local function read_bytes(data, pos, num)
	return data:sub(pos, pos + num - 1), pos + num
end

local function read_u1(data, pos)
	return data:byte(pos), pos + 1
end

local function read_u4le(data, pos)
	local b1, b2, b3, b4 = data:byte(pos, pos + 3)
	return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216), pos + 4
end

local function read_size_chunk(data, pos)
	local size_x, size_y, size_z
	size_x, pos = read_u4le(data, pos)
	size_y, pos = read_u4le(data, pos)
	size_z, pos = read_u4le(data, pos)
	return vmath.vector3(size_x, size_y, size_z), pos
end

local function read_rgba_chunk(data, pos)
	local colors = {}
	for i = 1, 256 do
		local r, g, b, a
		r, pos = read_u1(data, pos)
		g, pos = read_u1(data, pos)
		b, pos = read_u1(data, pos)
		a, pos = read_u1(data, pos)
		colors[i] = vmath.vector4(r / 255, g / 255, b / 255, a / 255)
	end
	return colors, pos
end

local function read_voxel(data, pos, size)
	local x, y, z, color_index
	x, pos = read_u1(data, pos)
	y, pos = read_u1(data, pos)
	z, pos = read_u1(data, pos)
	color_index, pos = read_u1(data, pos)

	local local_position = vmath.vector3(x, y, z)
	local world_position = vmath.vector3(x - size.x / 2, y - size.y / 2, z - size.z / 2)

	return {
		local_position = local_position,
		world_position = world_position,
		color_index = color_index
	}, pos
end

local function read_xyzi_chunk(data, pos, size)
	local num_voxels, pos = read_u4le(data, pos)
	local voxels = {}
	for i = 1, num_voxels do
		local voxel
		voxel, pos = read_voxel(data, pos, size)
		table.insert(voxels, voxel)
	end
	return voxels, pos
end

local function read_chunk(data, pos, size, colors)
	local chunk_id, pos = read_bytes(data, pos, 4)
	local chunk_size, pos = read_u4le(data, pos)
	local children_size, pos = read_u4le(data, pos)

	if chunk_id == "SIZE" then
		size, pos = read_size_chunk(data, pos)
	elseif chunk_id == "RGBA" then
		colors, pos = read_rgba_chunk(data, pos)
	elseif chunk_id == "XYZI" then
		local voxels
		voxels, pos = read_xyzi_chunk(data, pos, size)
		return voxels, pos, size, colors
	else
		pos = pos + chunk_size -- Skip unknown chunk data
	end

	pos = pos + children_size
	return nil, pos, size, colors
end

function M.load(resource_path)
	local data = sys.load_resource(resource_path)
	assert(data, "Failed to load .vox file: " .. resource_path)

	local pos = 1
	local models, size = {}, nil

	local magic, pos = read_bytes(data, pos, 4)
	assert(magic == "VOX ", "Invalid .vox file: incorrect magic header")

	local version, pos = read_u4le(data, pos)

	local main_chunk_id, pos = read_bytes(data, pos, 4)
	assert(main_chunk_id == "MAIN", "Invalid .vox file: expected MAIN chunk")

	pos = pos + 8 -- Skip main_chunk_size and main_children_size

	local end_pos = pos + read_u4le(data, pos - 4)
	while pos < end_pos do
		local voxels, new_pos, updated_size, updated_colors = read_chunk(data, pos, size, colors)
		if voxels then
			table.insert(models, {
				size = updated_size,
				voxels = voxels
			})
		end
		size = updated_size or size
		colors = updated_colors or colors
		pos = new_pos
	end

	return {
		version = version,
		models = models
	}
end

function M.get_color(color_index)
	return colors and colors[color_index] or vmath.vector4(1, 1, 1, 1)
end

return M
