/**
 * ...
 * @author Franco Ponticelli
 */

package php.ufront.web;

import haxe.io.Bytes;
import thx.error.Error;
import thx.sys.Lib;  
import ufront.web.IHttpHandler;    
import ufront.web.IHttpUploadHandler;
import ufront.web.EmptyUploadHandler;
using thx.text.UString;
using StringTools;

class HttpRequest extends ufront.web.HttpRequest
{
	public static function encodeName(s : String)
	{
		return s.urlEncode().replace('.', '%2E');
	}
	
	public function new()
	{
		_uploadHandler = new EmptyUploadHandler();
	}
	
	override function getQueryString()
	{
		if (null == queryString)
			queryString = untyped __var__('_SERVER', 'QUERY_STRING');
		return queryString;
	}
	
	override function getPostString()
	{
		if (httpMethod == "GET")
			return "";
		if (null == postString)
		{
			var h = untyped __call__("fopen", "php://input", "r");
			var bsize = 8192;
			var max = 32;
			postString = null;
			var counter = 0;
			while (!untyped __call__("feof", h) && counter < max) {
				postString += untyped __call__("fread", h, bsize);
				counter++;
			}
			untyped __call__("fclose", h);
			if (null == postString)
				postString = "";
		}
		return postString;
	}
	
	var _uploadHandler : IHttpUploadHandler;
	var _parsed : Bool;
	function _parseMultipart()
	{
		if (_parsed)
			return;
		_parsed = true;
		var post = getPost();
		var handler = _uploadHandler;
		untyped if (__call__("isset", __php__("$_POST")))
		{
			var na : php.NativeArray = __call__("array");
			__php__("foreach($_POST as $k => $v) { $na[urldecode($k)] = $v; }");
			var h = php.Lib.hashOfAssociativeArray(na);
			for (k in h.keys())
				post.set(k, h.get(k));
		}
		if(!untyped __call__("isset", __php__("$_FILES"))) return;
		var parts : Array<String> = untyped __call__("new _hx_array",__call__("array_keys", __php__("$_FILES")));
		untyped for(part in parts) {
			var info : Dynamic = __php__("$_FILES[$part]");
			var file : String = info['name'];
			var tmp : String = info['tmp_name'];
			
			//var name = __call__("urldecode", part);
			var name = StringTools.urldecode(part);
			post.set(name, file);
			
			if (tmp == '')
				continue;
			
			var err : Int = info['error'];

			if(err > 0) {
				switch(err) {
					case 1: throw new Error("The uploaded file exceeds the max size of {0}", untyped __call__('ini_get', 'upload_max_filesize'));
					case 2: throw new Error("The uploaded file exceeds the max file size directive specified in the HTML form (max is {0})", untyped __call__('ini_get', 'post_max_size'));
					case 3: throw new Error("The uploaded file was only partially uploaded");
					case 4: continue; // No file was uploaded
					case 6: throw new Error("Missing a temporary folder");
					case 7: throw new Error("Failed to write file to disk");
					case 8: throw new Error("File upload stopped by extension");
				}
			}
			handler.uploadStart(name, file);
			var h = __call__("fopen", tmp, "r");
			var bsize = 8192;
			while (!__call__("feof", h)) {
				var buf : String = __call__("fread", h, bsize);
				var size : Int = __call__("strlen", buf);
				handler.uploadProgress(name, Bytes.ofString(buf), 0, size);
			}
			untyped __call__("fclose", h);
			handler.uploadEnd(name);
			untyped __call__("unlink", tmp);
		}
	}

	override public function setUploadHandler(handler : IHttpUploadHandler)
	{
		if (_parsed)
			throw new Error("multipart has been already parsed");
		_uploadHandler = handler;
		_parseMultipart();
	}
	
	override function getQuery()
	{
		if (null == query)
			query = getHashFromString(queryString);
		return query;
	}
	
	override function getPost()
	{
		if (httpMethod == "GET")
			return new Hash();
		if (null == post)
		{
			post = getHashFromString(postString);
			if (!post.iterator().hasNext())
				_parseMultipart();
		}
		return post;
	}
	
	override function getCookies()
	{
		if (null == cookies)
			cookies = Lib.hashOfAssociativeArray(untyped __php__("$_COOKIE"));
		return cookies;
	}
	
	override function getHostName()
	{
		if (null == hostName)
			hostName = untyped __php__("$_SERVER['SERVER_NAME']");
		return hostName;
	}
	
	override function getClientIP()
	{
		if (null == clientIP)
			clientIP = untyped __php__("$_SERVER['REMOTE_ADDR']");
		return clientIP;
	}
	
	override function getUri()
	{
		if (null == uri)
		{
			var s : String = untyped __php__("$_SERVER['REQUEST_URI']");
			uri = s.split("?")[0];
		}
		return uri;
	}
	
	override function getClientHeaders()
	{
		if (null == clientHeaders)
		{
			clientHeaders = new Hash();
			var h = Lib.hashOfAssociativeArray(untyped __php__("$_SERVER"));
			for(k in h.keys()) {
				if(k.substr(0,5) == "HTTP_") {
					clientHeaders.set(k.substr(5).toLowerCase().replace("_", "-").ucwords(), h.get(k));
				}
			}
		}
		return clientHeaders;
	}
	
	override function getHttpMethod()
	{
		if (null == httpMethod)
		{
			untyped if(__php__("isset($_SERVER['REQUEST_METHOD'])"))
				httpMethod =  __php__("$_SERVER['REQUEST_METHOD']");
			if (null == httpMethod) httpMethod = "";
		}
		return httpMethod;
	}
	
	override function getScriptDirectory()
	{
		if (null == scriptDirectory)
		{
			scriptDirectory =  untyped __php__('dirname($_SERVER["SCRIPT_FILENAME"])') + "/";    
		}
		return scriptDirectory;
	}
	
	override function getAuthorization()
	{
		if (null == authorization)
		{
			authorization = { user : null, pass : null };
			untyped if(__php__("isset($_SERVER['PHP_AUTH_USER'])"))
			{
				authorization.user = __php__("$_SERVER['PHP_AUTH_USER']");
				authorization.pass = __php__("$_SERVER['PHP_AUTH_PW']");
			}
		}
		return authorization;
	}
	
	static var paramPattern = ~/^([^=]+)=(.*?)$/;
	static function getHashFromString(s : String)
	{
		var hash = new Hash();
		for (part in s.split("&"))
		{
			if (!paramPattern.match(part))
				continue;
			hash.set(
				StringTools.urlDecode(paramPattern.matched(1)),
				StringTools.urlDecode(paramPattern.matched(2)));
		}
		return hash;
	}
	
	static function getHashFrom(a : php.NativeArray)
	{
		if(untyped __call__("get_magic_quotes_gpc"))
			untyped __php__("reset($a); while(list($k, $v) = each($a)) $a[$k] = stripslashes((string)$v)");
		return Lib.hashOfAssociativeArray(a);
	}
}