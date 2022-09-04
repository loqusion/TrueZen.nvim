local M = {
	running = false
}

local data = require("true-zen.utils.data")
local config = require("true-zen.config").options
local global = require("true-zen.global")
local blank = require("true-zen.utils.blank")

function M.on()
	if M.running then
		return
	end

	global.off()
	data.do_callback("minimalist", "open", "pre")
	vim.api.nvim_create_augroup("TrueZenMinimalist", {
		clear = true,
	})

	blank.on()

	if config.integrations.tmux then
		require("true-zen.integrations.tmux").on()
	end

	M.running = true
	data.do_callback("minimalist", "open", "post")
end

function M.off()
	if not M.running then
		return
	end

	data.do_callback("minimalist", "close", "pre")
	vim.api.nvim_create_augroup("TrueZenMinimalist", {
		clear = true,
	})

	blank.off()

	if config.integrations.tmux == true then
		require("true-zen.integrations.tmux").off()
	end

	M.running = false
	data.do_callback("minimalist", "close", "post")
end

function M.toggle()
	if M.running then
		M.off()
	else
		M.on()
	end
end

return M
