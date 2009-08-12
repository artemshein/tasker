local tr = tr
local models = require "luv.db.models"
local fields = require "luv.fields"
local references = require "luv.fields.references"
local widgets = require "luv.fields.widgets"
local auth = require "luv.contrib.auth"
local tostring = tostring
local string = require "luv.string"
local table = require "luv.table"
local capitalize = string.capitalize

module(...)

local Task = models.Model:extend{
	__tag = .....".Task";
	Meta = {labels={"task";"tasks"}};
	_ajaxUrl = "/ajax/task/field-set.json";
	newStatuses = {"";"new";"новое";"новая";"новый"};
	doneStatuses = {"done";"finished";"completed";"сделано";"сделан";"сделана";"готово";"готова";"готов";"завершено";"закончено";"закончена";"закончен";"выполнено";"выполнена"};
	title = fields.Text{required=true;label=capitalize(tr "title");classes={"big"}};
	description = fields.Text{maxLength=false;label=capitalize(tr "description")}:addClasses{"huge";"resizable"};
	dateCreated = fields.Datetime{autoNow=true};
	createdBy = references.ManyToOne{references=auth.models.User;required=true;choices=auth.models.User:all()}:ajaxWidget(widgets.Select());
	assignedTo = references.ManyToOne{references=auth.models.User;label=capitalize(tr "executor");choices=auth.models.User:all()}:ajaxWidget(widgets.Select());
	dateToBeDone = fields.Date{label=capitalize(tr "term (date)")};
	timeToBeDone = fields.Time{label=capitalize(tr "term (time)")};
	important = fields.Boolean{label=tr "priority task";defaultValue=false};
	status = fields.Text{label=capitalize(tr "current state");defaultValue=tr "new"}:addClass "tiny";
	isNew = function (self)
		if not self.status or table.ifind(self.newStatuses, self.status:lower()) then
			return true
		end
		return false
	end;
	isDone = function (self)
		if self.status and table.ifind(self.doneStatuses, self.status:lower()) then
			return true
		end
		return false
	end;
	__tostring = function (self) return tostring(self.title) end;
}

local Log = models.Model:extend{
	__tag = .....".Log";
	Meta = {labels={"log";"logs"}};
	user = references.ManyToOne{references=auth.models.User;required=true};
	action = fields.Text{required=true};
	text = fields.Text{required=true};
	dateTime = fields.Datetime{autoNow=true};
	logTaskCreate = function (self, task, user)
		self:create{user=user;action="create";text="<a href="..("%q"):format("/task/"..task.pk)..">"..tostring(task).."</a>"}
	end;
	logTaskEdit = function (self, task, user, field, value)
		self:create{user=user;action="edit";text="<a href="..("%q"):format("/task/"..task.pk)..">"..tostring(task).."</a>"}
	end;
	logTaskDelete = function (self, task, user)
		self:create{user=user;action="delete";text=tostring(task)}
	end;
}

local Options = models.Model:extend{
	__tag = .....".Options";
	Meta = {labels={"options";"options"}};
	user = references.OneToOne{references=auth.models.User;required=true};
	tasksPerPage = fields.Int{label=capitalize(tr "tasks per page");defaultValue=10;required=true;choices={{10;10};{20;20};{30;30};{40;40};{50;50}}};
}

return {Task=Task;Log=Log;Options=Options}
