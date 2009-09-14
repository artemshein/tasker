local migrations = require"luv.contrib.migrations"

-- Added Notification model table

return migrations.Migration:extend{
	init = function (self, db)
		self:db(db)
	end;
	up = function (self)
		self:db():CreateTable"notification"
		:field("id", "INT", {primaryKey=true;serial=true})
		:field("to", "INT", {null=false})
		:field("dateCreated", "DATETIME", {null=true})
		:field("dateSended", "DATETIME", {null=true})
		:field("text", "TEXT", {null=false})
		:constraint("to", "user", "id", "CASCADE", "CASCADE")()
		return true
	end;
	down = function (self)
		self:db():DropTable"notification"()
		return true
	end;
}
