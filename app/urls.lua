local tr = tr
local forms = require"luv.forms"
local auth = require"luv.contrib.auth"
local fields = require"luv.fields"
local models = require"luv.db.models"
local Q = models.Q
local app = {models=require"app.models";forms=require"app.forms"}
local ws = require"luv.webservers"
local json = require"luv.utils.json"

luv:assign{
	empty=table.empty;pairs=pairs;ipairs=ipairs;version=version;
	date=os.date;luv=luv;
}

local function authUser (urlConf)
	local user = auth.models.User:authUser(luv:session())
	if not user or not user.isActive then luv:responseHeader("Location", urlConf:baseUri().."/login"):sendHeaders() end
	return user
end

local function requireAuth (func)
	return function (urlConf, ...)
		return func(urlConf, authUser(urlConf), ...)
	end 
end

return {
	{"^/test/?$"; function ()
		io.write"<pre>"
		require"luv.tests".all:run()
	end};
	--[[{"^/reinstall/?$"; function ()
		models.dropModels(models.Model.modelsList)
		models.createModels(models.Model.modelsList)
		local temiy = auth.models.User:create{login="temiy";name="Шеин Артём Александрович";passwordHash=auth.models.User:encodePassword "123456"}
		app.models.Options:create{user=temiy}
		luv:displayString "{{ safe(debugger) }}OK"
	end};]]
	{"^/admin"; require"luv.contrib.admin".AdminSite(luv, require"luv.contrib.auth".modelsAdmins(), app.models.admin):urls()};
	{"^/login/?$"; function (urlConf)
		local loginForm = auth.forms.Login(luv:postData())
		local user = auth.models.User:authUser(luv:session(), loginForm)
		if user and user.isActive then
			luv:responseHeader("Location", "/"):sendHeaders()
		end
		luv:assign{title="authorisation";loginForm=loginForm}
		luv:display"login.html"
	end};
	{"^/logout/?$"; requireAuth(function (urlConf, user)
		user:logout(luv:session())
		luv:responseHeader("Location", "/"):sendHeaders()
	end)};
	{"^/ajax/log/list/?$"; requireAuth(function (urlConf, user)
		local findLogsForm = app.forms.FindLogs(luv:postData())
		if not findLogsForm:submitted() or not findLogsForm:valid() then
			ws.Http403()
		end
		local p = models.Paginator(app.models.Log, 50):order"-dateTime"
		local page = tonumber(luv:post"page") or 1
		local logsFilter = luv:session().logsFilter or {}
		if logsFilter.action and "" ~= logsFilter.action then
			p:filter{action=logsFilter.action}
		end
		if logsFilter.mine then
			p:filter{user=user}
		end
		luv:assign{p=p;page=page;logs=p:page(page)}
		luv:display"_logs.html"
	end)};
	{"^/ajax/task/list/?$"; requireAuth(function (urlConf, user)
		-- Filtered tasks list
		local findTasksForm = app.forms.FindTasks(luv:postData())
		if not findTasksForm:submitted() or not findTasksForm:valid() then
			ws.Http403()
		end
		local p = models.Paginator(app.models.Task, user.options and user.options.tasksPerPage or 10):order"-dateCreated"
		local page = tonumber(luv:post"page") or 1
		local tasksFilter = luv:session().tasksFilter or {}
		if tasksFilter.title and "" ~= tasksFilter.title then
			p:filter{title__contains=tasksFilter.title}
		end
		if tasksFilter.self then
			p:filter(Q{assignedTo=user}-Q{createdBy=user})
		end
		if tasksFilter.status then
			if "new" == tasksFilter.status then
				p:filter{status__in=app.models.Task:newStatuses()}
			elseif "inProgress" == tasksFilter.status then
				p:exclude{status__in=app.models.Task:newStatuses()}
				p:exclude{status__in=app.models.Task:doneStatuses()}
			elseif "notCompleted" == tasksFilter.status then
				p:exclude{status__in=app.models.Task:doneStatuses()}
			elseif "completed" == tasksFilter.status then
				p:filter{status__in=app.models.Task:doneStatuses()}
			end
		end
		luv:assign{user=user;p=p;page=page;tasks=p:page(page)}
		luv:display"_tasks.html"
	end)};
	{"/ajax/task/field%-set%.json"; requireAuth(function (urlConf, user)
		local res = app.models.Task:ajaxHandler(luv:postData())
		if not res then
			ws.Http404()
		end
		local post = luv:postData()
		app.models.Log:logTaskEdit(app.models.Task:find(post.id), user)
		io.write(res)
	end)};
	{"/ajax/task/delete%.json"; requireAuth(function (urlConf, user)
		local f = app.forms.DeleteTask(luv:postData())
		if f:submitted() then
			if f:valid() then
				local task = app.models.Task:find(f.id)
				if task and task.createdBy == user then
					task:delete()
					app.models.Log:logTaskDelete(task, user)
					io.write(json.serialize{result="ok"})
				end
			else
				io.write(json.serialize{result="error";errors=f:errors()})
			end
		end
	end)};
	{"^/ajax/task/(%d+)/save.json"; requireAuth(function (urlConf, user, taskId)
		local task = app.models.Task:find(taskId)
		if not task then
			ws.Http404()
		end
		local f = app.forms.EditTask(luv:postData())
		f:processAjaxForm(function (self)
			self:initModel(task)
			task:update()
			app.models.Log:logTaskEdit(task, user)
		end)
	end)};
	{"^/task/(%d+)/?$"; requireAuth(function (urlConf, user, taskId)
		local task = app.models.Task:find(taskId)
		if not task then ws.Http404() end
		local f = app.forms.EditTask()
		f:action("/ajax/task/"..taskId.."/save.json")
		f:initForm(task)
		luv:assign{title=tostring(task);user=user;task=task;editTaskForm=f}
		luv:display"task.html"
	end)};
	{"^/sign_up/?$"; function (urlConf)
		local f = app.forms.SignUp(luv:postData())
		if f:submitted() then
			if f:valid() then
				local user = auth.models.User()
				f:initModel(user)
				if not user:insert() then
					f:addErrors(user:errors())
				else
					app.models.Options:create{user=user}
					f:addMsg(('Sign up complete. Now you can <a href="/">log in</a>.'):tr())
					f:values{}
				end
			end
		end
		luv:assign{title="sign up";registrationForm=f}
		luv:display"registration.html"
	end};
	{"^/ajax/task/filter%-list%.json$"; requireAuth(function (urlConf, user)
		-- Filtering
		local f = app.forms.TasksFilter(luv:postData())
		if f:submitted() then
			if f:valid() then
				f:initModel(luv:session())
				luv:session():save()
				io.write(json.serialize{result="ok"})
			else
				io.write(json.serialize{result="error";errors=f:errors()})
			end
		else
			ws.Http404()
		end
	end)};
	{"^/ajax/log/filter%-list%.json$"; requireAuth(function (urlConf, user)
		-- Filtering
		local f = app.forms.LogsFilter(luv:postData())
		if f:submitted() then
			if f:valid() then
				f:initModel(luv:session())
				luv:session():save()
				io.write(json.serialize{result="ok"})
			else
				io.write(json.serialize{result="error";errors=f:errors()})
			end
		else
			ws.Http404()
		end
	end)};
	{"^/help/?$"; function ()
		luv:assign{title="Помощь"}
		luv:display"help.html"
	end};
	{"^/ajax/task/create%.json$"; requireAuth(function (urlConf, user)
		local f = app.forms.CreateTask(luv:postData())
		f:processAjaxForm(function (f)
			local task = app.models.Task()
			f:initModel(task)
			task.createdBy = user
			task:insert()
			app.models.Log:logTaskCreate(task, user)
		end)
	end)};
	{"^/ajax/save%-options%.json"; requireAuth(function (urlConf, user)
		local f = app.forms.Options(luv:postData())
		f:processAjaxForm(function (f)
			if not user:comparePassword(f.password) then
				f:addError(tr"Wrong password.")
				return false
			end
			if "" ~= f.newPassword then
				if f.newPassword ~= f.newPassword2 then
					f:addError(tr"Passwords don't match.")
					return false
				else
					user.passwordHash = auth.models.User:encodePassword(f.newPassword)
				end
			end
			user.name = f.fullName
			if not user:save() then
				f:addErrors(user:errors())
				return false
			end
			local options = user.options or app.models.Options()
			f:initModel(options)
			if not options:save() then
				f:addErrors(options:errors())
				return false
			end
		end)
	end)};
	{"^/?$"; requireAuth(function (urlConf, user)
		local createTaskForm = app.forms.CreateTask()
		local tasksFilterForm = app.forms.TasksFilter()
		local logsFilterForm = app.forms.LogsFilter()
		local optionsForm = app.forms.Options()
		tasksFilterForm:initForm(luv:session())
		logsFilterForm:initForm(luv:session())
		optionsForm:initForm(user.options)
		luv:assign{
			title="main";user=user;createTaskForm=createTaskForm;
			tasksFilterForm=tasksFilterForm;
			logsFilterForm=logsFilterForm;optionsForm=optionsForm;
			reportForm=app.forms.Report();
		}
		luv:display"main.html"
	end)};
	{"^/report/?$"; requireAuth(function (urlConf, user)
		local f = app.forms.Report(luv:postData())
		if not f:submitted() or not f:valid() then
			ws.Http403()
		end
		local tasks = app.models.Task:all():order"dateCreated"
		if 1 == f.activeOnly then
			tasks = tasks:exclude{status__in=app.models.Task:doneStatuses()}
		end
		if 1 == f.self then
			tasks = tasks:filter(Q{assignedTo=user}-Q{createdBy=user})
		end
		tasks = tasks:value()
		local beginDate = os.date("*t", math.max(tasks[1].dateCreated, f.from))
		beginDate.hour = 0 beginDate.min = 0 beginDate.sec = 0
		beginDate = os.time(beginDate)
		local endDate = os.date("*t", math.max(tasks[#tasks].dateCreated, f.till and math.min(f.till, os.time()) or os.time()))
		endDate.hour = 0 endDate.min = 0 endDate.sec = 0
		endDate = os.time(endDate)
		local daysTotal = math.ceil((endDate-beginDate)/(24*60*60))+1
		luv:assign{
			math=math;
			user=user;users=auth.models.User:all():value();tasks=tasks;
			beginDate=beginDate;endDate=endDate;daysTotal=daysTotal;
		}
		luv:display"report.html"
	end)};
}
