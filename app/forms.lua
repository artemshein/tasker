local forms = require "luv.forms"
local fields = require "luv.fields"
local app = {models=require "app.models"}

module(...)

local CreateTask = forms.ModelForm:extend{
	__tag = .....".CreateTask";
	Meta = {model=app.models.Task;fields={"title";"assignedTo";"dateToBeDone";"timeToBeDone";"important";"description"}};
	create = fields.Submit{defaultValue="Создать"};
	init = function (self, ...)
		forms.ModelForm.init(self, ...)
		local id = self:getField "timeToBeDone":getId()
		self:getField "dateToBeDone":setOnChange("$(this).val() == ''? $('#"..id.."').attr('disabled', 'disabled') : $('#"..id.."').removeAttr('disabled');")
	end;
}

local FindTasks = forms.Form:extend{
	__tag = .....".FindTasks";
	find = fields.Submit{defaultValue="find"};
}

return {CreateTask=CreateTask;FindTasks=FindTasks}
