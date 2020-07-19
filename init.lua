local ffi = require("ffi")

ffi.cdef[[
uint32_t __stdcall GetLastError();
void *malloc(size_t size);
void free(void *ptr);
]]

local fwincom = {}

fwincom.IUnknown = require("fwincom.base")
fwincom.class = fwincom.IUnknown
fwincom.util = require("fwincom.util")

return fwincom
