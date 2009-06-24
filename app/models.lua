local models = require "luv.db.models"
local fields = require "luv.fields"
local references = require "luv.fields.references"
local widgets = require "luv.fields.widgets"
local auth = require "luv.contrib.auth"
local tostring = tostring
local string = require "luv.string"
local table = require "luv.table"

module(...)

local Task = models.Model:extend{
	__tag = .....".Task";
	Meta = {labels={"task";"tasks"}};
	title = fields.Text{required=true;label="Название"};
	description = fields.Text{maxLength=false;label="Описание"};
	dateCreated = fields.Datetime{autoNow=true};
	createdBy = references.ManyToOne{references=auth.models.User;required=true;choices=auth.models.User:all()}:setAjaxWidget(widgets.Select());
	assignedTo = references.ManyToOne{references=auth.models.User;label="Исполнитель";choices=auth.models.User:all()}:setAjaxWidget(widgets.Select());
	dateToBeDone = fields.Date{label="Срок (дата)";regional="ru"};
	timeToBeDone = fields.Time{label="Срок (время)";defaultValue="00:00:00"};
	important = fields.Boolean{label="Приоритетная задача";defaultValue=false};
	status = fields.Text{label="Текущее состояние";defaultValue="новая"};
	isNew = function (self)
		local newStatuses = {"";"новое";"новая";"новый"}
		if not self.status or table.ifind(newStatuses, string.utf8lower(self.status)) then
			return true
		end
		return false
	end;
	isDone = function (self)
		local doneStatuses = {"сделано";"готово";"завершено";"закончено"}
		if self.status and table.ifind(doneStatuses, string.utf8lower(self.status)) then
			return true
		end
		return false
	end;
	__tostring = function (self) return tostring(self.title) end;
}

return {Task=Task}
