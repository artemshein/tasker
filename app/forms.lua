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
	Meta = {model=app.models.Task;id="createTask";action="/ajax/task/create.json";ajax='{success: onTaskCreate, dataType: "json"}';fields={"title";"assignedTo";"dateToBeDone";"timeToBeDone";"important";"description"}};
	create = fields.Submit{defaultValue=capitalize(tr "create")};
	init = function (self, ...)
		forms.ModelForm.init(self, ...)
		local dateId = self:field "dateToBeDone":id()
		local timeId = self:field "timeToBeDone":id()
		self:field "dateToBeDone":onChange("$(this).val() == ''? $('#"..timeId.."').attr('disabled', 'disabled') : $('#"..timeId.."').removeAttr('disabled');")
		self:field "timeToBeDone":onLoad("$('#"..timeId.."').attr('disabled', $('#"..dateId.."').fieldRawVal() == ''? 'disabled' : null);")
	end;
}

local EditTask = forms.ModelForm:extend{
	__tag = .....".EditTask";
	Meta = {model=app.models.Task;id="editTask";ajax='{success: onTaskSave, dataType: "json"}';fields={"title";"assignedTo";"dateToBeDone";"timeToBeDone";"important";"description"}};
	save = fields.Submit{defaultValue=capitalize(tr "save")};
}

local DeleteTask = forms.Form:extend{
	__tag = .....".DeleteTask";
	id = app.models.Task:field "id":clone();
	delete = fields.Submit{defaultValue=capitalize(tr "delete")};
}

local FindTasks = forms.Form:extend{
	__tag = .....".FindTasks";
	find = fields.Submit{defaultValue=capitalize(tr "find")};
}

local FindLogs = forms.Form:extend{
	__tag = .....".FindLogs";
	find = fields.Submit{defaultValue=capitalize(tr "find")};
}

local Registration = forms.Form:extend{
	__tag = .....".Registration";
	Meta = {fields={"login";"password";"repeatPassword";"name";"email"}};
	login = auth.models.User:field "login":clone();
	password = fields.Password{required=true;label=capitalize(tr "password")};
	repeatPassword = fields.Password{required=true;label=capitalize(tr "repeat password")};
	name = auth.models.User:field "name":clone():required(true):label(capitalize(tr "full name"));
	email = auth.models.User:field "email":clone():required(true);
	register = fields.Submit{defaultValue=capitalize(tr "register")};
	isValid = function (self)
		local res = forms.Form.valid(self)
		if self.password ~= self.repeatPassword then
			res = false
			self:addError(tr "Passwords don't match.")
		end
		return res
	end;
	initModel = function (self, model)
		model:setValues(self:values())
		model.passwordHash = model:encodePassword(self.password)
		return self
	end;
}

local TasksFilter = forms.Form:extend{
	__tag = .....".TasksFilter";
	Meta = {id="tasksFilter";action="/ajax/task/filter-list.json";ajax='{success: onTasksFilter, dataType: "json"}';fields={"title";"status";"self"};widget=require "luv.forms.widgets".FlowForm()};
	title = fields.Text{label=capitalize(tr "in title")};
	status = fields.Text{label=capitalize(tr "status");choices={{"new";tr "new"};{"inProgress";tr "in progress"};{"notCompleted";tr "not completed"};{"completed";tr "completed"}};widget=require "luv.fields.widgets".Select()};
	self = fields.Boolean{label=tr "only that for me";defaultValue=false};
	filter = fields.Submit{defaultValue=capitalize(tr "filter")};
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
	Meta = {id="logsFilter";action="/ajax/log/filter-list.json";ajax='{success: onLogsFilter, dataType: "json"}';fields={"act";"mine"};widget=require "luv.forms.widgets".FlowForm()};
	act = fields.Text{label=capitalize(tr "action");choices={{"create";tr "creating"};{"edit";tr "editing"};{"delete";tr "deleting"}}};
	mine = fields.Boolean{label=tr "my actions only";defaultValue=false};
	filter = fields.Submit{defaultValue=capitalize(tr "filter")};
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
	Meta = {model=app.models.Options;id="options";action="/ajax/save-options.json";ajax='{success: onOptionsSave, dataType: "json"}';fields={"fullName";"tasksPerPage";"newPassword";"newPassword2";"password"}};
	fullName = auth.models.User:clone():field "name":required(true):label(capitalize(tr "full name"));
	newPassword = fields.Password{label=capitalize(tr "new password");hint=tr "Fill in only if you want to change password."};
	newPassword2 = fields.Password{label=capitalize(tr "repeat new password");hint=tr "Fill in only if you want to change password."};
	password = fields.Password{required=true;label=capitalize(tr "current password")};
	apply = fields.Submit{defaultValue=capitalize(tr "apply")};
	initForm = function (self, options)
		forms.ModelForm.initForm(self, options)
		self.fullName = options.user.name
	end;
}

return {
	CreateTask=CreateTask;EditTask=EditTask;DeleteTask=DeleteTask;
	FindTasks=FindTasks;FindLogs=FindLogs;Registration=Registration;
	TasksFilter=TasksFilter;LogsFilter=LogsFilter;Options=Options;
}
