local M = {}

local modules = {}

function modules.ataraxis()
	return require("true-zen.ataraxis")
end
function modules.focus()
	return require("true-zen.focus")
end
function modules.minimalist()
	return require("true-zen.minimalist")
end
function modules.narrow()
	return require("true-zen.narrow")
end

function M.off()
	for _, require_module in pairs(modules) do
		require_module().off()
	end
end

return M
