-- UUID/GUID/IID/CLSID/whatever

local ffi = require("ffi")

if pcall(ffi.typeof, "UUID") then
	error("type \"UUID\" has been defined")
end

ffi.cdef[[
typedef struct UUID
{
	uint32_t data1;
	uint16_t data2, data3;
	uint8_t data4[8];
} UUID;
]]

local UUID_SIZE = ffi.sizeof("UUID")
local PATTERN = "^{?(%x%x%x%x%x%x%x%x)%-(%x%x%x%x)%-(%x%x%x%x)%-(%x%x)(%x%x)%-(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)(%x%x)}?"

local uuid = {}
local uuid_t = ffi.typeof("UUID")

local nullUUID = ffi.new("const UUID", {0, 0, 0, {0, 0, 0, 0, 0, 0, 0, 0}})

uuid.null = nullUUID

function uuid.new(data)
	local t = type(data)

	if t == "nil" then
		return nullUUID
	elseif t == "table" then
		return ffi.new("const UUID", data)
	elseif t == "string" then
		local a, b, c, d, e, f, g, h, i, j, k = data:match(PATTERN)

		if not(a) then
			error("invalid data passed to new UUID")
		end

		return uuid.new({
			tonumber(a, 16),
			tonumber(b, 16),
			tonumber(c, 16),
			{
				tonumber(d, 16),
				tonumber(e, 16),
				tonumber(f, 16),
				tonumber(g, 16),
				tonumber(h, 16),
				tonumber(i, 16),
				tonumber(j, 16),
				tonumber(k, 16),
			}
		})
	end
end

function uuid:__tostring()
	return string.format(
		"{%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x}",
		self.data1, self.data2, self.data3,
		self.data4[0],
		self.data4[1],
		self.data4[2],
		self.data4[3],
		self.data4[4],
		self.data4[5],
		self.data4[6],
		self.data4[7]
	)
end

function uuid:__eq(other)
	if ffi.istype("UUID", self) == false then
		other, self = self, other
	end

	if ffi.istype("UUID", other) then
		return ffi.string(self, UUID_SIZE) == ffi.string(other, UUID_SIZE)
	end

	return false
end

uuid.__index = uuid
ffi.metatype(uuid_t, uuid)
setmetatable(uuid, {__call = function(_, d) return uuid.new(d) end})

return uuid
