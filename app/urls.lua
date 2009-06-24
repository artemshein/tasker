local forms = require "luv.forms"
local auth = require "luv.contrib.auth"
local fields = require "luv.fields"
local models = require "luv.db.models"
local app = {models=require "app.models";forms=require "app.forms"}

luv:assign{
	tr=tr;capitalize=string.capitalize;isEmpty=table.isEmpty;pairs=pairs;ipairs=ipairs;version=version;
	date=os.date;
}

local function getAuthUser (urlConf)
	local user = auth.models.User:getAuthUser(luv:getSession())
	if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
	return user
end

local LoginForm = forms.Form:extend{
	__tag = "LoginForm";
	Meta = {fields={"login";"password"}};
	login = auth.models.User:getField "login":clone();
	password = fields.Password();
	authorise = fields.Submit{defaultValue="Log in"};
}

return {
	{"^/reinstall/?$"; function ()
		models.dropModels(models.Model.modelsList)
		models.createModels(models.Model.modelsList)
		auth.models.User:create{login="temiy";name="Шеин Артём Александрович";passwordHash=auth.models.User:encodePassword "123456"}
		luv:displayString "{{ safe(debugger) }}OK"
	end};
	{"^/login/?$"; function (urlConf)
		local loginForm = auth.forms.Login(luv:getPostData())
		local user = auth.models.User:getAuthUser(luv:getSession(), loginForm)
		if user and user.isActive then
			luv:setResponseHeader("Location", "/"):sendHeaders()
		end
		luv:assign{loginForm=loginForm}
		luv:display "login.html"
	end};
	{"^/ajax/tasks.html$"; function (urlConf)
		local user = getAuthUser(urlConf)
		local findTasksForm = app.forms.FindTasks(luv:getPostData())
		if not findTasksForm:isSubmitted() or not findTasksForm:isValid() then
			Http403()
		end
		local p = models.Paginator(app.models.Task, 10):order "-dateCreated"
		local page = tonumber(luv:getGet "page") or 1
		luv:assign{p=p;page=page;tasks=p:getPage(page)}
		luv:display "_tasks.html"
	end};
	{false; function (urlConf)
		local user = getAuthUser(urlConf)
		local createTaskForm = app.forms.CreateTask(luv:getPostData())
		if createTaskForm:isSubmitted() then
			if createTaskForm:isValid() then
				local task = app.models.Task()
				createTaskForm:initModel(task)
				task.createdBy = user
				task:insert()
				createTaskForm:setValues{}
			end
		end
		luv:assign{user=user;createTaskForm=createTaskForm}
		luv:display "main.html"
	end};
}
