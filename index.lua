for _, path in ipairs{"/usr/lib/lua/5.1/";"/usr/share/lua/5.1/";"/usr/local/lib/lua/5.1/";"/usr/local/share/lua/5.1/"} do
	package.cpath = (package.cpath or "?.so")..";"..path.."?.so"
	package.path = (package.path or "?.lua")..";"..path.."?.lua;"..path.."?/init.lua"
end

luv = require "luv"
local exceptions = require "luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try

tr = function (str) return i18n and i18n:tr(str) or str end

local auth, utils, html, fs

try(function ()
	auth, utils, html, ws = require "luv.contrib.auth", require "luv.utils", require "luv.utils.html", require "luv.webservers"
	fs = require "luv.fs"
end):catch(function (e)
	io.write ("Content-type: text/html\n\n<pre>"..tostring(e))
	os.exit()
end)

version = utils.Version(0, 4, 1, "alpha")

try(function ()

	local cache = {backend = require "luv.cache.backend"}
	local TagEmuWrapper, Memcached = cache.backend.TagEmuWrapper, cache.backend.Memcached
	local baseDir = fs.Dir(arg[0]:slice(1, arg[0]:findLast"/" or arg[0]:findLast"\\"))

	dofile"config.lua"
	
	-- Create Luv Core object with
	luv = luv.init{
		tmpDir = tmpDir;
		sessionsDir = sessionsDir;
		templatesDirs = {
			baseDir / "templates";
			"/usr/lib/lua/5.1/luv/contrib/admin/templates";
		};
		dsn = dsn;
		debugger = require "luv.dev.debuggers".Fire();
	}
	luv:db():logger(function (sql, result) luv:debug(sql..", returns "..("table" == type(result) and "table" or tostring(result)), "Database") end)
	--luv:cacher():logger(function (sql, result) luv:debug(sql..", returns "..("table" == type(result) and (#result.." rows") or tostring(result)), "Cacher") end)
	-- luv:setCacher(TagEmuWrapper(Memcached()):setLogger(function (msg) luv:debug(msg, "Cacher") end))
	-- luv:getCacher():clear()
	auth.models.User:secretSalt(secretSalt)
	if not luv:dispatch "app/urls.lua" then
		ws.Http404()
	end

end):catch(ws.Http403, function () -- HTTP 403 Forbidden

	luv:responseCode(403):sendHeaders()
	io.write "403 Forbidden"

end):catch(ws.Http404, function () -- HTTP 404 Not Found

	luv:responseCode(404):sendHeaders()
	io.write "404 Not Found"

end):catch(function (e) -- Catch all exceptions

	if luv and luv.isA then luv:responseCode(500) end
	io.write("<br />Exception: ", html.escape(tostring(e)))

end)
