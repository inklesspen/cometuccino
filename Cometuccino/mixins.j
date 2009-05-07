@implementation CPURLConnection (GetRequest)

- (CPURLRequest) request
{
	return _request;
}

- (CPString) responseHeaderNamed: (CPString) headerName
{
	return _XMLHTTPRequest.getResponseHeader(headerName);
}

- (CPString) responseText
{
	return _XMLHTTPRequest.responseText;
}

@end