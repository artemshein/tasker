local require, io, tr = require, io, tr
local string = require "luv.string"
local forms = require "luv.forms"
local fields = require "luv.fields"
local app = {models=require "app.models"}
local auth = require "luv.contrib.auth"
local capitalize = string.capitalize

module(...)

local CreateTask = forms.ModelForm:extend{
	__tag = .....".CreateTask";
	Meta = {
		model=app.models.Task;
		id="createTask";
		action="/ajax/task/create.json";
		ajax='{success: onTaskCreate, dataType: "json"}';
		fields={"title";"assignedTo";"dateToBeDone";"timeToBeDone";"important";"description"}
	};
	create = fields.Submit(("create"):tr():capitalize());
	init = function (self, ...)
		forms.ModelForm.init(self, ...)
		local dateId = self:field"dateToBeDone":id()
		local timeId = self:field"timeToBeDone":id()
		self:field "dateToBeDone":onChange("$(this).val() == ''? $('#"..timeId.."').attr('disabled', 'disabled') : $('#"..timeId.."').removeAttr('disabled');")
		self:field "timeToBeDone":onLoad("$('#"..timeId.."').attr('disabled', $('#"..dateId.."').fieldRawVal() == ''? 'disabled' : null);")
	end;
}

local EditTask = forms.ModelForm:extend{
	__tag = .....".EditTask";
	Meta = {
		model=app.models.Task;
		id="editTask";
		ajax='{success: onTaskSave, dataType: "json"}';
		fields={"title";"assignedTo";"dateToBeDone";"timeToBeDone";"important";"description"}
	};
	save = fields.Submit(("save"):tr():capitalize());
}

local DeleteTask = forms.Form:extend{
	__tag = .....".DeleteTask";
	id = app.models.Task:field"id":clone();
	delete = fields.Submit(("delete"):tr():capitalize());
}

local FindTasks = forms.Form:extend{
	__tag = .....".FindTasks";
	find = fields.Submit(("find"):tr():capitalize());
}

local FindLogs = forms.Form:extend{
	__tag = .....".FindLogs";
	find = fields.Submit(("find"):tr():capitalize());
}

local SignUp = forms.Form:extend{
	__tag = .....".SignUp";
	Meta = {fields={"login";"password";"repeatPassword";"name";"email"}};
	login = auth.models.User:field"login":clone();
	password = fields.Password{required=true;label="password"};
	repeatPassword = fields.Password{required=true;label="repeat password"};
	name = auth.models.User:field"name":clone():required(true):label"full name";
	email = auth.models.User:field"email":clone():required(true);
	register = fields.Submit(("register"):tr():capitalize());
	isValid = function (self)
		local res = forms.Form.valid(self)
		if self.password ~= self.repeatPassword then
			res = false
			self:addError(("Passwords don't match."):tr())
		end
		return res
	end;
	initModel = function (self, model)
		model:values(self:values())
		model.passwordHash = model:encodePassword(self.password)
		return self
	end;
}

local TasksFilter = forms.Form:extend{
	__tag = .....".TasksFilter";
	Meta = {
		id="tasksFilter";
		action="/ajax/task/filter-list.json";
		ajax='{success: onTasksFilter, dataType: "json"}';
		fields={"title";"status";"self"};
		widget=require"luv.forms.widgets".FlowForm();
	};
	title = fields.Text{label=("in title"):tr():capitalize()};
	status = fields.Text{
		label=("status"):tr():capitalize();
		choices={
			{"new";("new"):tr()};
			{"inProgress";("in progress"):tr()};
			{"notCompleted";("not completed"):tr()};
			{"completed";("completed"):tr()}
		};
		widget=require"luv.fields.widgets".Select();
	};
	self = fields.Boolean{label="only that for me";defaultValue=false};
	filter = fields.Submit(("filter"):tr():capitalize());
	initModel = function (self, session)
		session.tasksFilter = {title=self.title;status=self.status;self=self.self}
	end;
	initForm = function (self, session)
		local tasksFilter = session.tasksFilter or {}
		self.title = tasksFilter.title
		self.status = tasksFilter.status
		self.self = tasksFilter.self
	end;
}

local LogsFilter = forms.Form:extend{
	__tag = .....".LogsFilter";
	Meta = {
		id="logsFilter";
		action="/ajax/log/filter-list.json";
		ajax='{success: onLogsFilter, dataType: "json"}';
		fields={"act";"mine"};
		widget=require"luv.forms.widgets".FlowForm();
	};
	act = fields.Text{
		label = ("action"):tr():capitalize();
		choices = {
			{"create";("creating"):tr()};
			{"edit";("editing"):tr()};
			{"delete";("deleting"):tr()};
		};
	};
	mine = fields.Boolean{label="my actions only";defaultValue=false};
	filter = fields.Submit(("filter"):tr():capitalize());
	initModel = function (self, session)
		session.logsFilter = {action=self.act;mine=self.mine}
	end;
	initForm = function (self, session)
		local logsFilter = session.logsFilter or {}
		self.act = logsFilter.action
		self.mine = logsFilter.mine
	end;
}

local Options = forms.ModelForm:extend{
	__tag = .....".Options";
	Meta = {
		model=app.models.Options;
		id="options";
		action="/ajax/save-options.json";
		ajax='{success: onOptionsSave, dataType: "json"}';
		fields={"fullName";"email";"tasksPerPage";"notifsFreq";"newPassword";"newPassword2";"password"};
	};
	fullName = auth.models.User:field"name":clone():required(true):label"full name";
	email = auth.models.User:field"email":clone():required(true);
	newPassword = fields.Password{label="new password";hint="Fill in only if you want to change password."};
	newPassword2 = fields.Password{label="repeat new password";hint="Fill in only if you want to change password."};
	password = fields.Password{required=true;label="current password"};
	apply = fields.Submit(("apply"):tr():capitalize());
	initForm = function (self, options)
		forms.ModelForm.initForm(self, options)
		self.fullName = options.user.name
		self.email = options.user.email
	end;
}

local Report = forms.Form:extend{
	__tag = .....".Report";
	Meta = {
		fields={"from";"till";"self";"activeOnly"};
		action="/report";
	};
	from = fields.Date{label="from date"};
	till = fields.Date{label="till date"};
	self = fields.Boolean{label="only that for me";defaultValue=false};
	activeOnly = fields.Boolean{label="only active tasks";defaultValue=false};
	report = fields.Submit(("report"):tr():capitalize())
}

return {
	CreateTask=CreateTask;EditTask=EditTask;DeleteTask=DeleteTask;
	FindTasks=FindTasks;FindLogs=FindLogs;SignUp=SignUp;
	TasksFilter=TasksFilter;LogsFilter=LogsFilter;Options=Options;
	Report=Report;
}
