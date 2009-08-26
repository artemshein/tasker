local models = require"luv.db.models"
local fields = require"luv.fields"
local references = require"luv.fields.references"
local widgets = require"luv.fields.widgets"
local auth = require"luv.contrib.auth"
local tostring = tostring
local string = require"luv.string"
local table = require"luv.table"

module(...)

local property = models.Model.property

local Task = models.Model:extend{
	__tag = .....".Task";
	__tostring = function (self) return tostring(self.title) end;
	_ajaxUrl = "/ajax/task/field-set.json";
	_newStatuses = {"";"new";"новое";"новая";"новый"};
	newStatuses = property"table";
	_doneStatuses = {"done";"finished";"completed";"сделано";"сделан";"сделана";"готово";"готова";"готов";"завершено";"закончено";"закончена";"закончен";"выполнено";"выполнена"};
	doneStatuses = property"table";
	Meta = {labels={"task";"tasks"}};
	title = fields.Text{required=true;label="title";classes={"big"}};
	description = fields.Text{maxLength=false;label="description"}:addClasses{"huge";"resizable"};
	dateCreated = fields.Datetime{autoNow=true};
	createdBy = references.ManyToOne{references=auth.models.User;required=true;choices=auth.models.User:all()}:ajaxWidget(widgets.Select());
	assignedTo = references.ManyToOne{references=auth.models.User;label="executor";choices=auth.models.User:all()}:ajaxWidget(widgets.Select());
	dateToBeDone = fields.Date{label="term (date)"};
	timeToBeDone = fields.Time{label="term (time)"};
	important = fields.Boolean{label="priority task";defaultValue=false};
	status = fields.Text{label="current state";defaultValue=("new"):tr()}:addClass"tiny";
	isNew = function (self)
		if not self.status or table.ifind(self:newStatuses(), self.status:lower()) then
			return true
		end
		return false
	end;
	isDone = function (self)
		if self.status and table.ifind(self:doneStatuses(), self.status:lower()) then
			return true
		end
		return false
	end;
}

local Log = models.Model:extend{
	__tag = .....".Log";
	Meta = {labels={"log";"logs"}};
	user = references.ManyToOne{references=auth.models.User;required=true};
	action = fields.Text{required=true};
	text = fields.Text{required=true};
	dateTime = fields.Datetime{autoNow=true};
	logTaskCreate = function (self, task, user)
		self:create{user=user;action="create";text='<a href=%(href)s>%(task)s</a>' % {href=("%q"):format("/task/"..task.pk);task=tostring(task)}}
	end;
	logTaskEdit = function (self, task, user, field, value)
		self:create{user=user;action="edit";text='<a href=%(href)s>%(task)s</a>' % {href=("%q"):format("/task/"..task.pk);task=tostring(task)}}
	end;
	logTaskDelete = function (self, task, user)
		self:create{user=user;action="delete";text=tostring(task)}
	end;
}

local Options = models.Model:extend{
	__tag = .....".Options";
	Meta = {labels={"options";"options"}};
	user = references.OneToOne{references=auth.models.User;required=true};
	tasksPerPage = fields.Int{label="tasks per page";defaultValue=10;required=true;choices={{10;10};{20;20};{30;30};{40;40};{50;50}}};
	notifsFreq = fields.Int{label="frequency of notifications";defaultValue=24*60*60;required=true;choices={{60*60;("once an hour"):tr()};{24*60*60;("once a day"):tr()};{7*24*60*60;("once a week"):tr()}}};
}

local Notification = models.Model:extend{
	__tag = .....".Notification";
	Meta = {labels={"notification";"notifications"}};
	to = references.ManyToOne{references=auth.models.User;required=true};
	dateCreated = fields.Datetime{autoNow=true};
	dateSended = fields.Datetime();
	text = fields.Text{maxLength=false;required=true};
}

return {Task=Task;Log=Log;Options=Options;admin={Task;Log};Notification=Notification}
