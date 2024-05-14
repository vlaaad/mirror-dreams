local M = {}

---@class Camera
---@field id any
---@field view any
---@field projection any
---@field x number
---@field y number
---@field width number
---@field height number

---@class vector3
---@field x number
---@field y number
---@field z number

---@param camera Camera
---@return Camera
local function ensure(camera)
	local window_width, window_height = window.get_size()
	local x = camera.x
	local y = camera.y
	local width = camera.width
	local height = camera.height
	local zoom = math.min(window_width / width, window_height / height)
	local projected_width = window_width / zoom
	local projected_height = window_height / zoom
	local xoffset = -(projected_width - width) / 2
	local yoffset = -(projected_height - height) / 2
	camera.projection = vmath.matrix4_orthographic(x + xoffset, x + xoffset + projected_width, y + yoffset, y + yoffset + projected_height, -1, 1)
	return camera
end

---@param x number
---@param y number
---@param width number
---@param height number
---@return Camera
function M.create(x,y,width,height)
	---@type Camera
	local camera = {
		id = go.get_id(),
		view = vmath.matrix4(),
		projection = vmath.matrix4_orthographic(x, x + width, y, y + height, -1, 1),
		x = x, y = y, width = width, height = height
	}
	return ensure(camera)
end

---@param camera Camera
function M.update(camera)
	msg.post("@render:", "set_view_projection", ensure(camera))
end

---Convert screen coordinate to a world point on a particular plane
---@param camera Camera
---@param screen_x number
---@param screen_y number
---@param plane_normal vector3 normal vector of a plane
---@param plane_point vector3 point on a plane
---@return vector3?
function M.screen_to_world_plane(camera, screen_x, screen_y, plane_normal, plane_point)
	ensure(camera)
	local view = camera.view
	local projection = camera.projection
	local window_width, window_height = window.get_size()

	local m = vmath.inv(projection * view)

	-- Remap coordinates to range -1 to 1
	local x1 = (screen_x - window_width * 0.5) / window_width * 2
	local y1 = (screen_y - window_height * 0.5) / window_height * 2

	local nv = vmath.vector4(x1, y1, -1, 1)
	local fv = vmath.vector4(x1, y1, 1, 1)

	-- Near and far points as a ray
	local np = m * nv
	local fp = m * fv
	np = np * (1 / np.w)
	fp = fp * (1 / fp.w)

	fp = vmath.vector3(fp.x, fp.y, fp.z)
	np = vmath.vector3(np.x, np.y, np.z)

	local denom = vmath.dot(plane_normal, fp - np)
	if denom == 0 then
		-- ray is perpendicular to plane normal, so there are either 0 or infinite intersections
		return nil
	else
		local numer = vmath.dot(plane_normal, plane_point - np)
		return vmath.lerp(numer / denom, np, fp)
	end
end

---Convert screen coordinate to world point 2d
---@param camera Camera
---@param screen_x number
---@param screen_y number
---@return vector3
function M.screen_to_world_2d(camera, screen_x, screen_y)
	return assert(M.screen_to_world_plane(camera, screen_x, screen_y, vmath.vector3(0, 0, 1), vmath.vector3()))
end

return M
