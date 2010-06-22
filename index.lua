#!/usr/bin/lua
for _, path in ipairs{"/usr/lib/lua/5.1/";"/usr/share/lua/5.1/";"/usr/local/lib/lua/5.1/";"/usr/local/share/lua/5.1/"} do
	package.cpath = (package.cpath or "?.so")..";"..path.."?.so"
	package.path = (package.path or "?.lua")..";"..path.."?.lua;"..path.."?/init.lua"
end

dofile"config.lua"

require"luv.exceptions".try(function ()

	require"luv".Luv
		:init{
			tmpDir = tmpDir;
			dsn = dsn;
			templatesDirs = {
				require"luv.fs".Dir(arg[0]:slice(1, arg[0]:findLast"/" or arg[0]:findLast"\\")) / "templates";
			};
			urlPrefix = urlPrefix;
			mediaPrefix = mediaPrefix;
			sessionsDir = sessionsDir;
			debugMode = debugMode;
			mailServer = mailServer or "localhost";
			mailFrom = mailFrom;
			secretSalt = secretSalt;
			administrator = administrator;
			assign = {empty=table.empty;pairs=pairs;ipairs=ipairs;date=os.date;version = require"luv.utils".StatusVersion"1b"};
		}
		:dispatch"app/urls.lua"

end):catch(function (e)

	io.write("<br />Exception: ", require"luv.utils.html".escape(tostring(e)))

end)
