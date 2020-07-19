-- Utilities, helper functions

local ffi = require("ffi")
local ntdll = ffi.load("ntdll")
local util = {}

ffi.cdef[[
uint32_t __stdcall FormatMessageW(
	uint32_t dwFlags,
	const void *lpSource,
	uint32_t dwMessageId,
	uint32_t dwLanguageId,
	wchar_t *lpBuffer,
	uint32_t nSize,
	va_list *Arguments
);
int32_t __stdcall MultiByteToWideChar(
	uint32_t CodePage,
	uint32_t dwFlags,
	const char *lpMultiByteStr,
	int32_t cbMultiByte,
	wchar_t *lpWideCharStr,
	int32_t cchWideChar
);
int32_t __stdcall WideCharToMultiByte(
	uint32_t CodePage,
	uint32_t dwFlags,
	const wchar_t *lpWideCharStr,
	int32_t cchWideChar,
	char *lpMultiByteStr,
	int32_t cbMultiByte,
	const char *lpDefaultChar,
	int32_t *lpUsedDefaultChar
);
]]

function util.allocMemory(size, type, new)
	type = type or "uint8_t"

	if new then
		return ffi.new(type.."[?]", size)
	else
		local mem = ffi.C.malloc(size * ffi.sizeof(type))
		if mem == nil then
			error("not enough memory")
		else
			return ffi.gc(ffi.cast(type.."*", mem), ffi.C.free)
		end
	end
end

-- Error message retrieval
do
	local ntdllModule = ffi.cast("void**", ntdll)[0]
	local formatMessageTempBuffer = util.allocMemory(32512, "wchar_t")

	ffi.fill(formatMessageTempBuffer, 32512 * ffi.sizeof("wchar_t"))

	function util.getErrorMessage(err)
		err = err or ffi.C.GetLastError()
		err = err % 4294967296

		local len

		if err >= 0x80000000 then
			len = ffi.C.FormatMessageW(0x1AFF, ntdllModule, err, 0, formatMessageTempBuffer, 32511, nil)
		else
			len = ffi.C.FormatMessageW(0x12FF, nil, err, 0, formatMessageTempBuffer, 32511, nil)
		end

		if len == 0 then
			error("error while trying to retrieve error message: "..ffi.C.GetLastError())
		end

		local str = util.toChar(formatMessageTempBuffer, len, 65001, true)
		if str == nil then
			error("error while converting error message: "..ffi.C.GetLastError())
		end

		return str
	end
end

-- UTF-16 <> UTF-8 conversions
do
	local tempBuffer = nil
	local tempBufferLen = 0

	function util.toWideChar(str, cp)
		cp = cp or 65001

		local size = ffi.C.MultiByteToWideChar(cp, 8, str, #str, nil, 0)
		if size == 0 then
			error(util.getErrorMessage())
		end

		local mem = util.allocMemory(size, "wchar_t")

		if ffi.C.MultiByteToWideChar(cp, 8, str, #str, mem, size) == 0 then
			error(util.getErrorMessage())
		end

		return mem, size
	end

	function util.toChar(str, len, cp, noerror)
		cp = cp or 65001
		len = len or -1

		if len == -1 then
			len = 0
			while str[len] ~= 0 do
				len = len + 1
			end
		end

		local size = ffi.C.WideCharToMultiByte(cp, 0x80, str, len, nil, 0, nil, nil)
		if size == 0 then
			if noerror then
				return nil
			else
				error(util.getErrorMessage())
			end
		end

		if size > tempBufferLen then
			tempBuffer = util.allocMemory(size, "char")
			tempBufferLen = size
		end

		if ffi.C.WideCharToMultiByte(cp, 0x80, str, len, tempBuffer, size, nil, nil) == 0 then
			if noerror then
				return nil
			else
				error(util.getErrorMessage())
			end
		end

		return ffi.string(tempBuffer, len == -1 and (tempBufferLen - 1) or len)
	end
end

function util.successResult(code)
	code = code % 4294967296
	return code < 0x80000000
end

return util
