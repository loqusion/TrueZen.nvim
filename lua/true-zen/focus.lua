local M = {
	running = false,
}

local data = require("true-zen.utils.data")
local echo = require("true-zen.utils.echo")
local global = require("true-zen.global")

function M.on()
	if M.running then
		return
	end

	global.off()

	data.do_callback("focus", "open", "pre")

	if vim.fn.winnr("$") == 1 then
		echo("there is only one window open", "error")
		return
	end
	vim.cmd("tab split")

	M.running = true
	data.do_callback("focus", "open", "post")
end

function M.off()
	if not M.running then
		return
	end

	data.do_callback("focus", "close", "pre")

	vim.cmd("tabclose")

	M.running = false
	data.do_callback("focus", "close", "post")
end

function M.toggle()
	if M.running then
		M.off()
	else
		M.on()
	end
end

return M
