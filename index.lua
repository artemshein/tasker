PRODUCTION = false -- Not used

for _, path in ipairs{"/usr/lib/lua/5.1/";"/usr/share/lua/5.1/";"/usr/local/lib/lua/5.1/";"/usr/local/share/lua/5.1/"} do
	package.cpath = (package.cpath or "?.so")..";"..path.."?.so"
	package.path = (package.path or "?.lua")..";"..path.."?.lua;"..path.."?/init.lua"
end

luv = require "luv"
local exceptions = require "luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try

local i18n = require "luv.i18n".I18n("app/i18n", "ru_RU")
tr = function (str) return i18n:tr(str) or str end

local auth, utils, html, fs

try(function ()
	auth, utils, html, ws = require "luv.contrib.auth", require "luv.utils", require "luv.utils.html", require "luv.webservers"
	fs = require "luv.fs"
end):catch(function (e)
	io.write ("Content-type: text/html\n\n<pre>"..tostring(e))
end)

version = utils.Version(0, 3, 0, "alpha")

try(function ()

	local cache = {backend = require "luv.cache.backend"}
	local TagEmuWrapper, Memcached = cache.backend.TagEmuWrapper, cache.backend.Memcached
	-- Create Luv Core object with
	luv = luv.init{
		tmpDir = "/var/tmp";
		sessionDir = "/var/www/sessions";
		templatesDirs = {
			"/var/www/tasker/templates";
			"/usr/lib/lua/5.1/luv/contrib/admin/templates";
		};
		dsn = "mysql://tasker:sd429dbkewls@localhost/tasker";
		debugger = require "luv.dev.debuggers".Fire();
	}
	-- luv:setCacher(TagEmuWrapper(Memcached()):setLogger(function (msg) luv:debug(msg, "Cacher") end))
	-- luv:getCacher():clear()
	auth.models.User:setSecretSalt "asd*#35&5sd^f8572@2rg6#2,ei||32fbDHWQ&*$^"
	if not luv:dispatch "app/urls.lua" then
		ws.Http404()
	end

end):catch(ws.Http403, function () -- HTTP 403 Forbidden

	luv:setResponseCode(403):sendHeaders()
	io.write "403 Forbidden"

end):catch(ws.Http404, function () -- HTTP 404 Not Found

	luv:setResponseCode(404):sendHeaders()
	io.write "404 Not Found"

end):catch(function (e) -- Catch all exceptions

	if luv and luv.isKindOf then luv:setResponseCode(500) end
	io.write("<br />Exception: ", html.escape(tostring(e)))

end)
