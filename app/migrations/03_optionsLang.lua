local migrations = require"luv.contrib.migrations"

-- Added Options lang field

return migrations.Migration:extend{
	init = function (self, db)
		self:db(db)
	end;
	up = function (self)
		local db = self:db()
		db:AddColumn("options", "lang", "CHAR(2)")()
		return true
	end;
	down = function (self)
		self:db():RemoveColumn("options", "lang")()
		return true
	end;
}
