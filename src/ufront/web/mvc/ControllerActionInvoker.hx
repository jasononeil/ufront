package ufront.web.mvc;

import ufront.web.mvc.ActionResult;
import thx.type.UType;
import thx.error.Error;
import thx.type.URtti;
import ufront.web.mvc.ControllerContext;
import haxe.rtti.CType;         
import thx.collections.Set;  

typedef ParameterDescriptor = {
	var name : String;
	var type : Class<Dynamic>;
	var info : CType;
}

class ControllerActionInvoker implements IActionInvoker
{                               
	public function new()
	{
		// TODO: Remove singleton
		binders = ModelBinders.binders;
	} 
	
	public var binders : ModelBinderDictionary;
	
	public var error(default, null) : Error;   
	
	function getParameterValue(controllerContext : ControllerContext, parameter : ParameterDescriptor) : Dynamic
	{
		var binder = getModelBinder(parameter);
				
		var bindingContext = new ModelBindingContext(
			parameter.name, 
			parameter.type, 
			parameter.info,
			controllerContext.controller.valueProvider
		);
		
		return binder.bindModel(controllerContext, bindingContext);
	}
	
	function getParameters(controllerContext : ControllerContext, argsinfo : List<{t: CType, opt: Bool, name: String}>)
	{
		// TODO: ActionDescriptor, ControllerDescriptor
		// TODO: Filters
		
		var arguments = new Array<Dynamic>();
		
		for(info in argsinfo)
		{
			// TODO: Avoid resolving for speed?
			var type = Type.resolveClass(URtti.typeName(info.t, info.opt));
			var value = getParameterValue(controllerContext, { name: info.name, type: type, info: info.t } );
			
			if(null == value)
			{
				if(URtti.argumentAcceptNull(info))
				{
					arguments.push(null);
				}
				else
				{
					throw new Error("argument {0} cannot be null", info.name);
				}
			}
			else
			{
				var argvalue = ValueProviderResult.convertSimpleType(value, info.t);
				if(null == argvalue)
				{
					throw new Error("the string '{0}' can't be converted into a value of type {1}", [value, URtti.typeName(info.t, false)]);
				}
				arguments.push(argvalue);
			}
		}
		
		return arguments;
	}
	
	public function invokeAction(controllerContext : ControllerContext, actionName : String) : Bool
	{        
		error = null; 
		
		var controller = controllerContext.controller;
		var fields = URtti.getClassFields(Type.getClass(controller));
		var method = fields.get(actionName); 
		var arguments : Array<Dynamic>;
		
		try
		{
			if(null == method)
				throw new Error("action {0} does not exist on this controller", actionName);

			if(!method.isPublic)
				throw new Error("action {0} must be a public method", actionName);
				
			var argsinfo = URtti.methodArguments(method);
			if(null == argsinfo)
				throw new Error("action {0} is not a method", actionName);
			
			arguments = getParameters(controllerContext, argsinfo);
		}
		catch (e : Error)
		{
			error = e;
			return false;
		}
		
#if php
    	if(_mapper.exists(actionName))
			actionName = "h" + actionName;
#end    
		var returnValue = Reflect.callMethod(controller, Reflect.field(controller, actionName), arguments);  
		if(null != returnValue && Std.is(returnValue, ActionResult))
		{
			var result : ActionResult = cast returnValue;    
			result.executeResult(controllerContext);
		}
		else if(returnValue != null && controllerContext != null && controllerContext.response != null)
		{
			// Write the returnValue to response.
			controllerContext.response.write(Std.string(returnValue));
		}
				              
		return true;
	}
	
	function getModelBinder(parameter : ParameterDescriptor)
	{
		// TODO: Look on the parameter itself, then look in the global table.
		return binders.getBinder(parameter.type);
	}
	
#if php
	static var _mapper : Set<String>; 
    static function __init__()
	{
		_mapper = new Set();
		_mapper.add("and");
		_mapper.add("or");
		_mapper.add("xor");
		_mapper.add("exception");
		_mapper.add("array");
		_mapper.add("as");
		_mapper.add("const");
		_mapper.add("declare");
		_mapper.add("die");
		_mapper.add("echo");
		_mapper.add("elseif");
		_mapper.add("empty");
		_mapper.add("enddeclare");
		_mapper.add("endfor");
		_mapper.add("endforeach");
		_mapper.add("endif");
		_mapper.add("endswitch");
		_mapper.add("endwhile");
		_mapper.add("eval");
		_mapper.add("exit");
		_mapper.add("foreach");
		_mapper.add("global");
		_mapper.add("include");
		_mapper.add("include_once");
		_mapper.add("isset");
		_mapper.add("list");
		_mapper.add("print");
		_mapper.add("require");
		_mapper.add("require_once");
		_mapper.add("unset");
		_mapper.add("use");
		_mapper.add("final");
		_mapper.add("php_user_filter");
		_mapper.add("protected");
		_mapper.add("abstract");
		_mapper.add("__set");
		_mapper.add("__get");
		_mapper.add("__call");
		_mapper.add("clone"); 
	}
#end
}