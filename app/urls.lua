local require, tonumber, tostring, table = require, tonumber, tostring, table
local setfenv, getfenv, os, math = setfenv, getfenv, os, math
local forms = require"luv.forms"
local auth = require"luv.contrib.auth"
local fields = require"luv.fields"
local models = require"luv.db.models"
local Q = models.Q
local app = {models=require"app.models";forms=require"app.forms"}
local http = require"luv.http"
local json = require"luv.utils.json"
local utils = require"luv.utils"
local fs = require"luv.fs"
local Decorator = require"luv.function".Decorator

local function authUser (urlConf)
	local request = urlConf:request()
	local user = auth.models.User:authUser(request:session())
	if not user or not user.active then request:wsApi():responseHeader("Location", urlConf:baseUri().."/sign_in"):sendHeaders() end
	return user
end

local requireAuth = Decorator(function (func, urlConf, ...)
	setfenv(func, getfenv(1))
	return func(urlConf, authUser(urlConf), ...)
end)

local migrationsLogger = function (text) io.write(text, "<br />") end

return {
	--[[{"^/migrations/sd5sag3gj6"; {
		{"^/reinstall"; function ()
			local migrations = require"luv.contrib.migrations"
			models.dropModels(migrations.models)
			models.createModels(migrations.models)
			templater:displayString"{{ safe(debugger) }}OK"
		end};
		{"^/allUp$"; function ()
			local migrations = require"luv.contrib.migrations"
			local manager = migrations.MigrationManager(luv:db(), "app/migrations")
			manager:logger(migrationsLogger)
			manager:allUp()
			templater:displayString"{{ safe(debugger) }}OK"
		end};
		{"^/allDown$"; function ()
			local migrations = require"luv.contrib.migrations"
			local manager = migrations.MigrationManager(luv:db(), "app/migrations")
			manager:logger(migrationsLogger)
			manager:allDown()
			templater:displayString"{{ safe(debugger) }}OK"
		end};
	}};]]
	--[=[{"^/test/?$"; function ()
		io.write"<pre>"
		local cov = require"luv.dev.coverage".Coverage()
		require"luv.tests".all:run()
		fs.File"out/coverage.html":openWriteAndClose([[
			<html><head>
				<title>Luv unittest coverage</title>
				<style>
					.covered{background-color:#DFD}
					.notCovered{background-color:#FDD}
					.empty{background-color:#DDD}
				</style>
			</head>
			<body>
			]]..cov:fullInfoAsHtml()..[[</body></html>]])
	end};]=]
	{"^/reinstall/?$"; function ()
		local migrations = require"luv.contrib.migrations"
		models.dropModels(models.Model.modelsList)
		models.createModels(models.Model.modelsList)
		local manager = migrations.MigrationManager(db, "app/migrations")
		if manager:currentMigration() ~= manager:lastMigration() then
			manager:markAllUp()
		end
		-- Global administrator data
		-- Hash administrator's password
		administrator.passwordHash = auth.models.User:encodePassword(administrator.password)
		local admin = auth.models.User:create(administrator)
		app.models.Options:create{user=admin}
		templater:displayString "{{ safe(debugger) }}OK"
	end};
	--{"^/admin"; require"luv.contrib.admin".AdminSite(luv, require"luv.contrib.auth".modelsAdmins(), app.models.admin):urls()};
	{"^/sign_in/?$"; function (urlConf)
		local request = urlConf:request()
		local loginForm = auth.forms.Login(request:postData())
		local user = auth.models.User:authUser(request:session(), loginForm)
		if user and user.active then
			request:wsApi():responseHeader("Location", "/"):sendHeaders()
		elseif user then
			loginForm:addError(("Your account has been disabled."):tr())
		end
		templater
			:assign{title="authorisation";loginForm=loginForm}
			:display"sign_in.html"
	end};
	{"^/sign_out/?$"; requireAuth % function (urlConf, user)
		user:logout(luv:session())
		urlConf:request():wsApi():responseHeader("Location", "/"):sendHeaders()
	end};
	{"^/ajax"; {
		{"^/task"; {
			{"^/list/?$"; requireAuth % function (urlConf, user)
				local request = urlConf:request()
				-- Filtered tasks list
				local findTasksForm = app.forms.FindTasks(request:postData())
				if not findTasksForm:submitted() or not findTasksForm:valid() then
					http.Http403()
				end
				local p = models.Paginator(app.models.Task, user.options and user.options.tasksPerPage or 10):order"-dateCreated"
				local page = tonumber(request:post"page") or 1
				local tasksFilter = request:session().tasksFilter or {}
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
				templater
					:assign{user=user;p=p;page=page;tasks=p:page(page)}
					:display"_tasks.html"
			end};
			{"^/field%-set%.json$"; requireAuth % function (urlConf, user)
				local res = app.models.Task:ajaxFieldHandler(urlConf:request():postData(), function (f, task)
					local res = task.createdBy == user or task.assignedTo == user
					-- Notify old executor when executor is changed
					if "assignedTo" == f.field and task.assignedTo and f.value ~= task.assignedTo.pk and user ~= task.assignedTo then
						app.models.Notification:create{
							to=task.assignedTo;
							text=("%(user)s changed the task %(task)s field %(field)s value to %(value)s."):tr() % {
								user=tostring(user);
								task=("%q"):format(tostring(task));
								field=("%q"):format(f.field);
								value=("%q"):format(f.value);
							};
						}
					end
					return res
				end, function (f, task)
					app.models.Log:logTaskEdit(task, user)
					-- Notify executor when owner changes the task
					if task.assignedTo and task.assignedTo ~= user then
						app.models.Notification:create{
							to=task.assignedTo;
							text=("%(user)s changed the task %(task)s field %(field)s value to %(value)s."):tr() % {
								user=tostring(user);
								task=("%q"):format(tostring(task));
								field=("%q"):format(f.field);
								value=("%q"):format(f.value);
							};
						}
					end
					-- Notify owner when executor finishes the task
					if "status" == f.field and task:isDone() and user ~= task.createdBy then
						app.models.Notification:create{
							to=task.createdBy;
							text=("%(user)s marked the task %(task)s as completed."):tr() % {user=tostring(user);task=("%q"):format(tostring(task))};
						}
					end
				end)
				if not res then
					http.Http403()
				end
			end};
			{"^/delete%.json$"; requireAuth % function (urlConf, user)
				app.forms.DeleteTask(urlConf:request():postData()):processAjaxForm(function (self)
					local task = app.models.Task:find(self.id)
					if task and task.createdBy == user then
						if task.assignedTo and task.assignedTo ~= user then
							self:addMsg"add notification!"
							app.models.Notification:create{
								to=task.assignedTo;
								text=("Task %(task)s has been deleted."):tr() % {task=("%q"):format(tostring(task))};
							}
						end
						task:delete()
						app.models.Log:logTaskDelete(task, user)
					else
						return false
					end
				end)
			end};
			{"^/(%d+)/save.json"; requireAuth % function (urlConf, user, taskId)
				local task = app.models.Task:find(taskId)
				if not task then
					http.Http404()
				end
				local f = app.forms.EditTask(urlConf:request():postData())
				f:processAjaxForm(function (self)
					self:initModel(task)
					task:update()
					app.models.Log:logTaskEdit(task, user)
				end)
			end};
			{"^/filter%-list%.json$"; requireAuth % function (urlConf, user)
				local request = urlConf:request()
				app.forms.TasksFilter(request:postData()):processAjaxForm(function (self)
					self:initModel(request:session())
					request:session():save()
				end)
			end};
			{"^/create%.json$"; requireAuth % function (urlConf, user)
				app.forms.CreateTask(urlConf:request():postData()):processAjaxForm(function (self)
					local task = app.models.Task()
					self:initModel(task)
					task.createdBy = user
					task:insert()
					app.models.Log:logTaskCreate(task, user)
				end)
			end};
		}};
		{"^/log"; {
			{"^/list/?$"; requireAuth % function (urlConf, user)
				local request = urlConf:request()
				local findLogsForm = app.forms.FindLogs(request:postData())
				if not findLogsForm:submitted() or not findLogsForm:valid() then
					http.Http403()
				end
				local p = models.Paginator(app.models.Log, 50):order"-dateTime"
				local page = tonumber(request:post"page") or 1
				local logsFilter = request:session().logsFilter or {}
				if logsFilter.action and "" ~= logsFilter.action then
					p:filter{action=logsFilter.action}
				end
				if logsFilter.mine then
					p:filter{user=user}
				end
				templater
					:assign{p=p;page=page;logs=p:page(page)}
					:display"_logs.html"
			end};
			{"^/filter%-list%.json$"; requireAuth % function (urlConf, user)
				local request = urlConf:request()
				app.forms.LogsFilter(request:postData()):processAjaxForm(function (self)
					self:initModel(request:session())
					request:session():save()
				end)
			end};
		}};
		{"^/notification/list/?$"; requireAuth % function (urlConf, user)
			local p = models.Paginator(app.models.Notification, 50):order"-dateCreated"
			local page = tonumber(urlConf:request():post"page") or 1
			templater
				:assign{p=p;page=page;notifications=p:page(page)}
				:display"_notifications.html"
		end};
		{"^/save%-options%.json$"; requireAuth % function (urlConf, user)
			app.forms.Options(urlConf:request():postData()):processAjaxForm(function (self)
				if not user:comparePassword(self.password) then
					self:addError(("Wrong password."):tr())
					return false
				end
				if "" ~= self.newPassword then
					if self.newPassword ~= self.newPassword2 then
						self:addError(("Passwords don't match."):tr())
						return false
					else
						user.passwordHash = auth.models.User:encodePassword(self.newPassword)
					end
				end
				user.name = self.fullName
				user.email = self.email
				if not user:save() then
					self:addErrors(user:errors())
					return false
				end
				local options = user.options or app.models.Options()
				self:initModel(options)
				if not options:save() then
					self:addErrors(options:errors())
					return false
				end
			end)
		end};
	}};
	{"^/task/(%d+)/?$"; requireAuth % function (urlConf, user, taskId)
		local task = app.models.Task:find(taskId)
		if not task then http.Http404() end
		local f = app.forms.EditTask()
		f:htmlAction("/ajax/task/"..taskId.."/save.json")
		f:initForm(task)
		templater
			:assign{title=tostring(task);user=user;task=task;editTaskForm=f}
			:display"task.html"
	end};
	{"^/sign_up/?$"; function (urlConf)
		local f = app.forms.SignUp(urlConf:request():postData())
		if f:submitted() then
			if f:valid() then
				local user = auth.models.User()
				f:initModel(user)
				if not user:insert() then
					f:addErrors(user:errors())
				else
					app.models.Options:create{user=user}
					f:addMsg(('Sign up complete. Now you can <a href="/">sign in</a>.'):tr())
					f:values{}
				end
			end
		end
		templater
			:assign{title="sign up";registrationForm=f}
			:display"registration.html"
	end};
	{"^/help/?$"; function ()
		templater
			:assign{title="Помощь"}
			:display"help.html"
	end};
	{"^/?$"; requireAuth % function (urlConf, user)
		local request = urlConf:request()
		local createTaskForm = app.forms.CreateTask()
		local tasksFilterForm = app.forms.TasksFilter()
		local logsFilterForm = app.forms.LogsFilter()
		local optionsForm = app.forms.Options()
		tasksFilterForm:initForm(request:session())
		logsFilterForm:initForm(request:session())
		optionsForm:initForm(user.options)
		templater
			:assign{
				title="main";user=user;createTaskForm=createTaskForm;
				tasksFilterForm=tasksFilterForm;
				logsFilterForm=logsFilterForm;optionsForm=optionsForm;
				reportForm=app.forms.Report();
			}
			:display"main.html"
	end};
	{"^/report/?$"; requireAuth % function (urlConf, user)
		local f = app.forms.Report(urlConf:request():postData())
		if not f:submitted() or not f:valid() then
			http.Http403()
		end
		local tasks = app.models.Task:all():order"dateCreated"
		if 1 == f.activeOnly then
			tasks = tasks:exclude{status__in=app.models.Task:doneStatuses()}
		end
		if 1 == f.self then
			tasks = tasks:filter(Q{assignedTo=user}-Q{createdBy=user})
		end
		if f.till then
			tasks = tasks:filter{dateCreated__lt=f.till+24*60*60}
		end
		tasks = tasks:value()
		local beginDate, endDate, daysTotal
		if not table.empty(tasks) then
			beginDate = os.date("*t", f.from and math.max(tasks[1].dateCreated, f.from) or tasks[1].dateCreated)
			beginDate.hour = 0 beginDate.min = 0 beginDate.sec = 0
			beginDate = os.time(beginDate)
			endDate = os.date("*t", f.till and math.min(f.till, math.max(tasks[#tasks].dateCreated, os.time())) or math.max(tasks[#tasks].dateCreated, os.time()))
			endDate.hour = 0 endDate.min = 0 endDate.sec = 0
			endDate = os.time(endDate)
			daysTotal = math.ceil((endDate-beginDate)/(24*60*60))+1
		end
		templater
			:assign{
				math=math;
				user=user;users=auth.models.User:all():value();tasks=tasks;
				beginDate=beginDate;endDate=endDate;daysTotal=daysTotal;
			}
			:display"report.html"
	end};
	{"^/cron/daily/u29dbsl30ocnsl$"; function (urlConf)
		local i18nByEmail = {}
		-- Find uncompleted tasks with term in the past
		local time = os.time()
		for _, task in app.models.Task:all():filter(Q{dateToBeDone__lt=time}-Q{dateToBeDone=time;timeToBeDone__lte=time}):exclude{status__in=app.models.Task._doneStatuses}:filter{assignedTo__isnull=false}() do
			local email = task.assignedTo.email
			i18nByEmail[email] = i18nByEmail[email] or require"luv.i18n".I18n("app/i18n", task.assignedTo.options.lang or "en", false)
			app.models.Notification:create{to=task.assignedTo;dateCreated=time;text=i18nByEmail[email]:tr('Uncompleted task "%s" with term in the past.'):format(tostring(task))}
		end
		ok()
	end};
	{"^/cron/hourly/sadfj23iasb23l2$"; function (urlConf)
		local notifsByEmail = {}
		local i18nByEmail = {}
		-- Find not sended
		for _, notif in app.models.Notification:all():filter{dateSended__isnull=true}() do
			local email = notif.to.email
			notifsByEmail[email] = notifsByEmail[email] or {}
			i18nByEmail[email] = i18nByEmail[email] or require"luv.i18n".I18n("app/i18n", notif.to.options.lang or "en", false)
			table.insert(notifsByEmail[email], i18nByEmail[email]:tr(notif.text))
		end
		-- Send founded
		for email, notifs in pairs(notifsByEmail) do
			local body = ""
			if #notifs > 1 then
				for i, notif in ipairs(notifs) do
					body = body..tostring(i)..". "..notif.."\n"
				end
			else
				body = notifs[1]
			end
			utils.sendEmail(mailFrom, email, i18nByEmail[email]:tr('Notifications from "Tasker"'), body, mailServer)
		end
		-- Mark as sended
		app.models.Notification:all():filter{dateSended__isnull=true}:update{dateSended=os.date("%Y-%m-%d %H:%M:%S")}
		ok()
	end};
}
