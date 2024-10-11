local M = {}

local function read_bytes(data, pos, num)
	return data:sub(pos, pos + num - 1), pos + num
end

local function read_u4le(data, pos)
	local b1, b2, b3, b4 = data:byte(pos, pos + 3)
	return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216), pos + 4
end

local function read_chunk(data, pos)
	local chunk_id, pos = read_bytes(data, pos, 4)
	local chunk_size, pos = read_u4le(data, pos)
	local children_size, pos = read_u4le(data, pos)
	return chunk_id, pos, chunk_size, children_size
end

function M.get_model_count(resource_path)
	local data = sys.load_resource(resource_path)
	assert(data, "Failed to load .vox file: " .. resource_path)

	local pos = 1
	local model_count = 1 -- Default to 1 if no PACK chunk is found

	local magic, pos = read_bytes(data, pos, 4)
	assert(magic == "VOX ", "Invalid .vox file: incorrect magic header")

	local version, pos = read_u4le(data, pos)

	local main_chunk_id, pos = read_bytes(data, pos, 4)
	assert(main_chunk_id == "MAIN", "Invalid .vox file: expected MAIN chunk")

	local main_chunk_size, pos = read_u4le(data, pos)
	local main_children_size, pos = read_u4le(data, pos)
	local end_pos = pos + main_children_size

	-- Iterate through the MAIN chunk's children to find the PACK chunk
	while pos < end_pos do
		local chunk_id, chunk_start_pos, chunk_size, children_size = read_chunk(data, pos)
		pos = chunk_start_pos + 12 -- Move to the chunk's content

		if chunk_id == "PACK" then
			model_count, pos = read_u4le(data, pos)
			break -- We found the model count, no need to process further chunks
		else
			-- Skip unknown or unsupported chunks
			pos = pos + chunk_size + children_size
		end
	end

	return model_count
end

return M
