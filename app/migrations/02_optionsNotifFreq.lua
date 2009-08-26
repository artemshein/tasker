local migrations = require"luv.contrib.migrations"

-- Added Options notifFreq field

return migrations.Migration:extend{
	init = function (self, db)
		self:db(db)
	end;
	up = function (self)
		local db = self:db()
		db:AddColumn("options", "notifFreq", "INT", {null=false})()
		db:query("UPDATE ?# SET ?# = ?d;", "options", "notifFreq", 60*60)
		return true
	end;
	down = function (self)
		self:db():RemoveColumn("options", "notifFreq")()
		return true
	end;
}
