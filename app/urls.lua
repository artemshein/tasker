local forms = require "luv.forms"
local auth = require "luv.contrib.auth"
local fields = require "luv.fields"
local models = require "luv.db.models"
local Q = models.Q
local app = {models=require "app.models";forms=require "app.forms"}
local ws = require "luv.webservers"
local json = require "luv.utils.json"

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
	{"^/logout/?$"; function (urlConf)
		local user = getAuthUser(urlConf)
		user:logout(luv:getSession())
		luv:setResponseHeader("Location", "/"):sendHeaders()
	end};
	{"^/ajax/logs.html$"; function (urlConf)
		local user = getAuthUser(urlConf)
		local findLogsForm = app.forms.FindLogs(luv:getPostData())
		if not findLogsForm:isSubmitted() or not findLogsForm:isValid() then
			Http403()
		end
		local p = models.Paginator(app.models.Log, 50):order "-dateTime"
		local page = tonumber(luv:getPost "page") or 1
		luv:assign{p=p;page=page;logs=p:getPage(page)}
		luv:display "_logs.html"
	end};
	{"^/ajax/tasks.html$"; function (urlConf)
		local user = getAuthUser(urlConf)
		local findTasksForm = app.forms.FindTasks(luv:getPostData())
		if not findTasksForm:isSubmitted() or not findTasksForm:isValid() then
			Http403()
		end
		local p = models.Paginator(app.models.Task, 10):order "-dateCreated"
		local page = tonumber(luv:getPost "page") or 1
		local tasksFilter = luv:getSession().tasksFilter or {}
		if tasksFilter.title and "" ~= tasksFilter.title then
			p:filter{title__contains=tasksFilter.title}
		end
		if tasksFilter.self then
			p:filter(Q{assignedTo=user}-Q{createdBy=user})
		end
		if tasksFilter.status then
			if "new" == tasksFilter.status then
				p:filter{status__in=app.models.Task.newStatuses}
			elseif "inProgress" == tasksFilter.status then
				p:exclude{status__in=app.models.Task.newStatuses}
				p:exclude{status__in=app.models.Task.doneStatuses}
			elseif "notCompleted" == tasksFilter.status then
				p:exclude{status__in=app.models.Task.doneStatuses}
			elseif "completed" == tasksFilter.status then
				p:filter{status__in=app.models.Task.doneStatuses}
			end
		end
		luv:assign{p=p;page=page;tasks=p:getPage(page)}
		luv:display "_tasks.html"
	end};
	{"/ajax/task/set"; function ()
		local user = getAuthUser(urlConf)
		local res = app.models.Task:ajaxHandler(luv:getPostData())
		if not res then
			ws.Http404()
		end
		local post = luv:getPostData()
		app.models.Log:logTaskEdit(app.models.Task:find(post.id), user)
		io.write(res)
	end};
	{"^/task/(%d+)/?$"; function (urlConf, taskId)
		local user = getAuthUser(urlConf)
		local task = app.models.Task:find(taskId)
		if not task then
			Http404()
		end
		local f = app.forms.EditTask(luv:getPostData())
		if f:isSubmitted() then
			if f:isValid() then
				f:initModel(task)
				task:update()
				app.models.Log:logTaskEdit(task, user)
				io.write(json.serialize{result="ok"})
			else
				io.write(json.serialize{result="error";errors=f:getErrors()})
			end
			return
		else
			f:initForm(task)
		end
		luv:assign{user=user;task=task;editTaskForm=f}
		luv:display "task.html"
	end};
	{"^/registration/?$"; function (urlConf)
		local f = app.forms.Registration(luv:getPostData())
		if f:isSubmitted() then
			if f:isValid() then
				local user = auth.models.User()
				f:initModel(user)
				if not user:insert() then
					f:addErrors(user:getErrors())
				else
					f:addMsg 'Регистрация прошла успешно. Теперь Вы можете <a href="/">авторизоваться</a>.'
					f:setValues{}
				end
			end
		end
		luv:assign{registrationForm=f}
		luv:display "registration.html"
	end};
	{"^/?$"; function (urlConf)
		local user = getAuthUser(urlConf)
		local createTaskForm = app.forms.CreateTask(luv:getPostData())
		if createTaskForm:isSubmitted() then
			if createTaskForm:isValid() then
				local task = app.models.Task()
				createTaskForm:initModel(task)
				task.createdBy = user
				task:insert()
				app.models.Log:logTaskCreate(task, user)
				io.write(json.serialize{result="ok"})
			else
				io.write(json.serialize{result="error";errors=createTaskForm:getErrors()})
			end
			return
		end
		local filterForm = app.forms.Filter(luv:getPostData())
		if filterForm:isSubmitted() then
			if filterForm:isValid() then
				filterForm:initModel(luv:getSession())
				luv:getSession():save()
			end
			return
		else
			filterForm:initForm(luv:getSession())
		end
		luv:assign{user=user;createTaskForm=createTaskForm;filterForm=filterForm}
		luv:display "main.html"
	end};
}
