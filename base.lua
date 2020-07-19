-- IUnknown

local ffi = require("ffi")

local UUID = require("fwincom.uuid")
local util = require("fwincom.util")

local definitionTemplate = [[
typedef struct %s %s;

typedef struct %s
{
	int32_t (__stdcall *queryInterface)(IUnknown*, const UUID&, void**);
	uint32_t (__stdcall *retain)(IUnknown*);
	uint32_t (__stdcall *release)(IUnknown*);
	%s
} %s;

struct %s
{
	%s *__vtable;
};
]]

if pcall(ffi.typeof, "VTABLE_IUnknown") then
	error("type \"VTABLE_IUnknown\" has been defined")
end

ffi.cdef[[
typedef struct IUnknown IUnknown;

typedef struct VTABLE_IUnknown
{
	int32_t (__stdcall *queryInterface)(IUnknown*, const UUID&, void**);
	uint32_t (__stdcall *retain)(IUnknown*);
	uint32_t (__stdcall *release)(IUnknown*);
} VTABLE_IUnknown;

struct IUnknown
{
	VTABLE_IUnknown *__vtable;
};
]]

local function defineDef(ctype, def)
	local funcidx = 0
	for i = 1, #def do
		if type(def[i]) == "function" then
			funcidx = i
			break
		end
	end

	assert(funcidx > 0, "no function definition found")

	local args

	if funcidx == 2 then
		args = ctype
	else
		args = string.format("%s, %s", ctype, table.concat(def, ", ", 2, funcidx - 1))
	end

	return string.format("uint32_t (__stdcall *%s)(%s);", def[1], args), def[funcidx]
end

local IUnknown = {}
IUnknown.__name = "IUnknown"
IUnknown.__type = "IUnknown*"
IUnknown.__uuid = UUID("00000000-0000-0000-C000-000000000046")
IUnknown.__index = IUnknown
IUnknown.__interfaces = {}

local tempVoidPointer = ffi.new("void*[1]")

local function castVTable(type, obj)
	return ffi.cast(type, obj.__vtable)
end

-- Marker function to pass parameter as-is
function IUnknown:auto()
end

function IUnknown:getInterface(class)
	local hresult = castVTable("VTABLE_IUnknown*", self).queryInterface(self, class.__uuid, tempVoidPointer)

	if util.successResult(hresult) then
		return ffi.cast(class.__type, tempVoidPointer[0])[0]
	else
		error(util.getErrorMessage(hresult))
	end
end

function IUnknown:retain()
	return castVTable("VTABLE_IUnknown*", self).retain(self)
end

function IUnknown:release()
	return castVTable("VTABLE_IUnknown*", self).release(self)
end

function IUnknown:extend(cname, uuid, def)
	local interfaces = {}
	local vtable = "VTABLE_"..cname
	local vtablePtr = vtable.."*"
	local vtableDef = {}
	local classdef = {
		__name = cname,
		__type = cname.."*",
		__uuid = UUID(uuid),
		__interfaces = interfaces,
	}
	classdef.__index = classdef

	-- Iterate all parent interfaces
	for _, v in ipairs(self.__interfaces) do
		local name = v[1]

		interfaces[#interfaces + 1] = v
		vtableDef[#vtableDef + 1] = defineDef(self.__type, v)
		classdef[name] = self.__index[name]
	end

	-- Iterate definition interfaces
	for _, v in ipairs(def) do
		local name = v[1]
		local field, func = defineDef(classdef.__type, v)
		interfaces[#interfaces + 1] = v
		vtableDef[#vtableDef + 1] = field

		if func == IUnknown.auto then
			func = function(obj, ...)
				return castVTable(vtablePtr, obj)[name](obj, ...)
			end
		end

		classdef[name] = function(obj, ...)
			local result = {func(obj, castVTable(vtablePtr, obj), ...)}

			if util.successResult(result[1]) then
				return select(2, unpack(result))
			else
				error(util.getErrorMessage(result[1]))
			end
		end
	end

	-- This 4 methods shouldn't be overridden!
	classdef.getInterface = IUnknown.getInterface
	classdef.retain = IUnknown.retain
	classdef.release = IUnknown.release
	classdef.extend = IUnknown.extend

	-- Build cdef
	local cdef = string.format(
		definitionTemplate,
		cname,
		cname,
		vtable,
		table.concat(vtableDef, "\n\t"),
		vtable,
		cname,
		vtable
	)

	ffi.cdef(cdef)
	ffi.metatype(cname, classdef)
	return classdef
end

ffi.metatype("IUnknown", IUnknown)

return IUnknown
