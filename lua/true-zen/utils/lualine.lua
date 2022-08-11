local M = {}

local config = require("true-zen.config").options

local hidden = false

function M.hide()
	if hidden then
		return
	end

	require("lualine").hide()
	vim.opt.statusline = config.modes.minimalist.options.statusline
	hidden = true
end

function M.show()
	if not hidden then
		return
	end

	require("lualine").hide({ unhide = true })
	hidden = false
end

function M.is_available()
	local ok = pcall(require, "lualine")
	return ok
end

return M
