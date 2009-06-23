local models = require "luv.db.models"
local fields = require "luv.fields"
local references = require "luv.fields.references"
local auth = require "luv.contrib.auth"
local tostring = tostring
local string = require "luv.string"

module(...)

local Task = models.Model:extend{
	__tag = .....".Task";
	Meta = {labels={"task";"tasks"}};
	title = fields.Text{required=true;label="Название"};
	description = fields.Text{maxLength=false;label="Описание"};
	dateCreated = fields.Datetime{autoNow=true};
	createdBy = references.ManyToOne{references=auth.models.User;required=true};
	assignedTo = references.ManyToOne{references=auth.models.User;label="Исполнитель"};
	dateToBeDone = fields.Date{label="Срок (дата)";regional="ru"};
	timeToBeDone = fields.Time{label="Срок (время)";defaultValue="00:00:00"};
	important = fields.Boolean{label="Приоритетная задача";defaultValue=false};
	status = fields.Text{label="Текущее состояние";defaultValue="новая"};
	isDone = function (self) return self.status and string.utf8lower(self.status) == "сделано" end;
	__tostring = function (self) return tostring(self.title) end;
}

return {Task=Task}
