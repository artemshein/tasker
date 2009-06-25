local forms = require "luv.forms"
local fields = require "luv.fields"
local app = {models=require "app.models"}
local auth = require "luv.contrib.auth"

module(...)

local CreateTask = forms.ModelForm:extend{
	__tag = .....".CreateTask";
	Meta = {model=app.models.Task;fields={"title";"assignedTo";"dateToBeDone";"timeToBeDone";"important";"description"}};
	create = fields.Submit{defaultValue="Создать"};
	init = function (self, ...)
		forms.ModelForm.init(self, ...)
		local dateId = self:getField "dateToBeDone":getId()
		local timeId = self:getField "timeToBeDone":getId()
		self:getField "dateToBeDone":setOnChange("$(this).val() == ''? $('#"..timeId.."').attr('disabled', 'disabled') : $('#"..timeId.."').removeAttr('disabled');")
		self:getField "timeToBeDone":setOnLoad("$('#"..timeId.."').attr('disabled', $('#"..dateId.."').fieldRawVal() == ''? 'disabled' : null);")
	end;
}

local EditTask = forms.ModelForm:extend{
	__tag = .....".EditTask";
	Meta = {model=app.models.Task;fields={"title";"assignedTo";"dateToBeDone";"timeToBeDone";"important";"description"}};
	save = fields.Submit{defaultValue="Сохранить"};
}

local FindTasks = forms.Form:extend{
	__tag = .....".FindTasks";
	find = fields.Submit{defaultValue="Find"};
}

local Registration = forms.Form:extend{
	__tag = .....".Registration";
	Meta = {fields={"login";"password";"repeatPassword";"name";"email"}};
	login = auth.models.User:getField "login":clone():setLabel "Логин";
	password = fields.Password{required=true;label="Пароль"};
	repeatPassword = fields.Password{required=true;label="Повторите пароль"};
	name = auth.models.User:getField "name":clone():setRequired(true):setLabel "ФИО";
	email = auth.models.User:getField "email":clone():setRequired(true):setLabel "Эл. почта";
	register = fields.Submit{defaultValue="Зарегистрироваться"};
	isValid = function (self)
		local res = forms.Form.isValid(self)
		if self.password ~= self.repeatPassword then
			res = false
			self:addError "Passwords don't match."
		end
		return res
	end;
	initModel = function (self, model)
		model:setValues(self:getValues())
		model.passwordHash = model:encodePassword(self.password)
		return self
	end;
}

return {CreateTask=CreateTask;EditTask=EditTask;FindTasks=FindTasks;Registration=Registration}
