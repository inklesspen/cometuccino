@import "mixins.j"

var ReverseHttpAccessPoint = "/reversehttp";

function encode_utf8(s) {
    return unescape(encodeURIComponent(s));
}

function decode_utf8(s) {
    return decodeURIComponent(escape(s));
}

function parseLinkHeaders(s) {
    var result = {};
    if (s != null) {
	var headerValues = s.split(", ");
	for (var i = 0; i < headerValues.length; i++) {
	    var linkHeader = headerValues[i];
	    var pieces = linkHeader.split(";");
	    var url;
	    var rel;
	    for (var j = 0; j < pieces.length; j++) {
		var piece = pieces[j];
		var m = piece.match(/<\s*(\S+)\s*>/);
		if (m != null) {
		    url = m[1];
		} else {
		    m = piece.match(/(\w+)="(\w*)"/);
		    if (m != null) {
			if (m[1].toLowerCase() == "rel") {
			    rel = m[2];
			}
		    }
		}
	    }
	    if (rel && url) {
		result[rel] = url;
	    }
	}
    }
    return result;
}

@implementation XHRHandler : CPObject
{
}

- (void)connectionDidFinishLoading:(CPURLConnection) connection
{
}

- (void)connection:(CPURLConnection) connection didReceiveData:(CPString)data
{
}

- (void)connection:(CPURLConnection) connection didFailWithError:(CPString)error
{
}

@end


@implementation HttpServer : XHRHandler
{
	CPString _label;
	id _delegate;
	id _options;
	int _failureDelay;
	BOOL _running;
	CPString _nextReq;
	CPString _location;
	CPURLConnection _pollConnection;
}

- (id)initWithLabel:(CPString) label delegate:(id) delegate options:(id) options
{
	if(self = [super init])
	{
		_label = label;
		_delegate = delegate;
		_failureDelay = 2000;
		_options = options;
		if (_options.token == undefined) { _options.token = "-"; }
		if (_options.debug == undefined) { _options.debug = function () {}; }
		if (_options.log == undefined) { _options.log = function () { this.debug.apply(this, arguments); }; }
		if (_options.onLocationChanged == undefined) { _options.onLocationChanged = function () {}; }
		
		_running = YES;
		_nextReq = nil;
		_location = nil;
		_pollConnection = nil;
		
		var timer = [CPTimer scheduledTimerWithTimeInterval:0.25 target: self selector: @selector(serve) userInfo: nil repeats: NO];
		
	}
	return self;
}

- (id)initWithLabel:(CPString) label delegate:(id) delegate
{
	return [self initWithLabel: label delegate: delegate options: {}];
}

- (void)stop
{
	_running = NO;
	if (_pollConnection) {
		[_pollConnection cancel];
		_pollConnection = nil;
	}
}

- (void)serve
{
	var declareMode = (_nextReq == nil);

	if (_running == NO) {
		return;
	}

	if (_nextReq == nil) {
		var request = [CPURLRequest requestWithURL: ReverseHttpAccessPoint];
		request.kind = "setup";
		[request setHTTPMethod: "POST"];
		[request setHTTPBody: "name=" + encodeURIComponent(_label) + "&token=" + encodeURIComponent(_options.token)];
		
	} else {
		var request = [CPURLRequest requestWithURL: _nextReq];
		[request setValue: "message/http" forHTTPHeaderField: "Accept"];
		request.kind = "longpolling";
		
	}
	
	_pollConnection = [CPURLConnection connectionWithRequest:request delegate:self];
	
}


- (void)connection:(CPURLConnection) connection didReceiveData:(CPString)data
{
	_pollConnection = nil;
	if (_running == NO) {
		return;
	}
	if (_failureDelay != 2000) {
		_failureDelay = 2000;
	}
	
	if ([connection request].kind == "setup") {
		var hdr = [connection responseHeaderNamed: "Link"];
		var linkHeaders = parseLinkHeaders(hdr);
	    _nextReq = linkHeaders["first"];
	    var locationText = linkHeaders["related"];
	    if (locationText) {
			_location = locationText;
			_options.onLocationChanged(locationText, self);
	    }
	    _options.debug("Label " + _label + " maps to " + _location);
	    _options.debug("First request is at " + _nextReq);
	} else {
		var requestSourceText = data;
	    if (requestSourceText) {
	    	try {
				var clientHostAndPort = [connection responseHeaderNamed: "Requesting-Client"];
				var httpReq = [[HttpRequest alloc] initWithReplyUrl: _nextReq sourceText: requestSourceText];
				_nextReq = parseLinkHeaders([connection responseHeaderNamed: "Link"])["next"];
			    _options.log(httpReq._headers["host"] + " " + httpReq._method + " " + httpReq._rawPath);
			    try {
					[_delegate HTTPrequest: httpReq];
			    } catch (userException) {
					_options.log("HTTPD CALLBACK ERROR: " + Object.toJSON(userException));
					[httpReq respondWithStatus: 500 text: "Internal Server Error" headers: {} body: "httpd.js callback internal server error"];
			    }
			} catch (catchallException) {
			    _options.log("HTTPD ERROR: " + Object.toJSON(catchallException));
			}
		}
	}
	
	var timer = [CPTimer scheduledTimerWithTimeInterval:0 target: self selector: @selector(serve) userInfo: nil repeats: NO];
	
}

- (void)connection:(CPURLConnection) connection didFailWithError:(CPString)error
{
	_pollConnection = nil;
	if (_running == NO) {
		return;
	}
	if (error == "204" || error == "201") {
		[self connection:connection didReceiveData: nil];
	} else {
		console.log("Error " + error + " when doing that thing we do.");
	}
}


@end


@implementation HttpRequest : XHRHandler
{
	CPString _replyURL;
	CPString _method;
	CPString _rawPath;
	CPString _httpVersion;
	id _headers;
	CPString _body;
	BOOL _responseSent;
}

- (id)initWithReplyUrl:(CPString) replyURL sourceText:(CPString) sourceText
{
	if(self = [super init])
	{
		_replyURL = replyURL;
		_sourceText = sourceText;
	    var tmp = sourceText.match(/([^ ]+) ([^ ]+) HTTP\/([0-9]+\.[0-9]+)\r\n/);
		_method = tmp[1].toLowerCase();
	    _rawPath = tmp[2];
	    _httpVersion = tmp[3];
	    _headers = {}

		var processText = sourceText.substring(tmp[0].length);
		do {
			var tmp = processText.match(/([^:]+):[ \t]*([^\r\n]*)\r\n/);
			if (tmp != null) {
				_headers[tmp[1].toLowerCase()] = tmp[2];
				processText = processText.substring(tmp[0].length);
			}
		} while (tmp != null);
		_body = processText.substring(2);
		
	
		_responseSent = NO;
	}
	return self;
}

- (void)respondWithStatus: (int)status text: (CPString)text headers: (id)headers body: (CPString)body
{
	if (_responseSent == YES) {
		return;
	}
	var r = [[HttpResponse alloc] initWithStatus: status text: text headers: headers body: body];
	var request = [CPURLRequest requestWithURL:_replyURL];
/*	request.kind = "http_response";*/
	[request setHTTPMethod: "POST"];
	[request setHTTPBody: [r stringify]];
	var connection = [CPURLConnection connectionWithRequest:request delegate:self];
	_responseSent = YES;
}

@end


@implementation HttpResponse : CPObject
{
	int _status;
	CPString _text;
	id _headers;
	CPString _body;
	CPString _version;
}

- (id)initWithStatus: (int)status text: (CPString)text headers: (id)headers body: (CPString)body httpVersion:(CPString) version
{
	if(self = [super init])
	{
		_status = status;
		_text = text;
		_headers = headers;
		_body = body;
		_version = version;
	}
	return self;
}

- (id)initWithStatus: (int)status text: (CPString)text headers: (id)headers body: (CPString)body
{
	return [self initWithStatus: status text: text headers: headers body: body httpVersion: "1.0"];
}

- (CPString)stringify
{
	var lineList = ["HTTP/" + _version + " " + _status + " " + _text];
	
	var h = {};
    for (var key in _headers) {
		h[key] = _headers[key];
    }
    h["Content-length"] = encode_utf8(_body).length;
	h['Content-type'] = "message/http";
    for (var key in h) {
		lineList.push(key + ": " + h[key]);
    }
    lineList.push("");
    lineList.push(_body);
    return lineList.join("\r\n");
}

@end
